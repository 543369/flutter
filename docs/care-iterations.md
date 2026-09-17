# 日常照护分轮优化

本轮按第一轮、第二轮、持续优化依次实现。入口仍是“照护 → 全部安排 / 记录”和“宠物 → 健康档案”。

## 第一轮：每天打开就能用

- 首页待照护数统计选中宠物的逾期及本地今天未完成事项，不把未来重复事项计入今天。下一项可预告未来安排，明确显示明天或日期；逾期明确标注。其他宠物显示各自待照护数，可点击切换。
- 宠物和历史关联只使用 ID，同名宠物不会混入彼此记录。没有宠物时显示添加入口；英文日期不混用中文月份。前台定时和恢复前台都会重算本地日期。
- “今天的小日常”只展示本地当天的事件。“已完成”数量优先按最近完成时间统计，旧记录缺少完成时间时回退到安排日期。
- 完成、撤销和其他单次操作采用服务端确认后的局部更新。同一事项提交期间防止重复点击，失败保留旧状态；完成反馈提供直接撤销。后续安排切换采用高度过渡。
- 冷启动和前台通知点击均读取任务 ID，选择对应宠物并打开详情。删除或越权任务提示不可用，不自动完成。未登录或启动同步失败时保留待处理通知，恢复后继续路由。
- 启动连接失败但身份仍存在时提供同步重试。已有数据的后台同步失败会保留数据并显示上次同步时间。已打开的详情也通过单任务接口更新，避免取消后或历史任务不在看板中时详情突然消失。

## 第二轮：单次调整与健康联动

- 安排详情支持修改本次时间、取消本次；重复安排还可跳过本次。修改时间不改变周期计划，取消/跳过不影响后续重复安排。
- `occurrence_at` 保存原始发生时间。重复计划唯一键改为 `(plan_id, occurrence_at)`，防止改期后再次生成原来的发生项，亦允许两次安排调整到同一时刻。
- 改期、取消、跳过保留操作事件；重复取消/跳过不重复记事件。已完成、已取消、已跳过的事项不能直接改期，已完成须先撤销。取消和跳过后不再排本机通知。
- “全部安排”提供待照护、已完成、重复计划、已取消/跳过四类。重复计划详情增加停止入口，继续保留逾期事项和历史。
- 健康记录详情可设置下次照护提醒，时间由用户按医嘱选择。已有同记录未完成提醒时更新同一事项，完成后可以设置下一次。照护详情可返回关联健康记录；删除健康记录只解除关联，不删除已存在的照护历史。完成提醒不会自动生成医疗事实或健康记录。
- 首页头图区缩短；完成是主要按钮，改期、指定照护人和取消为次要操作。窄屏时间选择固定竖向，避免确认按钮超出屏幕。

## 持续优化：接口与数据层

- App 使用 `/dashboard?compact=true`。看板不传照片正文，每只宠物只带 `photoRevision`；每只宠物各取最近两条事件，避免高频宠物挤掉其他宠物。旧 `/dashboard` 仍可返回照片和最近 100 条事件。
- 看板保留未完成事项以确保逾期统计、未来预告与本机提醒准确；已完成事项只保留近期安排或最近两天有完成事件的事项。更早的已完成事项通过安排分页访问，不随每次看板同步累积。
- `/pets/{id}/photos` 按版本获取相册。客户端按会话缓存相册，图片修改或删除后更新，切换身份隔离缓存。照片解码采用 24 MiB LRU 上限并复用字节对象，让 Flutter 图片缓存可以命中。
- 照护记录使用 `(happened_at, id)` 游标、每页 30 条。翻页期间插入新记录不会导致已有页重复；下拉刷新重新从最新记录开始。
- 安排列表每页 30 条，按需获取；任务详情、历史和看板查询复用 `CareQueries`。
- 完成、撤销、改期、取消/跳过、指定照护人及健康提醒接口返回 `{task, events}`。这些操作无需随后请求整份看板。新建普通/重复计划、停止计划及其他家庭操作仍通过看板同步。
- 通知排程串行执行，避免多个局部更新相互覆盖通知队列。仍为本地通知，没有新增远程推送；跨设备状态靠前台同步更新。

## 接口

| 接口 | 行为 |
| --- | --- |
| `GET /api/dashboard?compact=true` | 无图片正文的近期看板 |
| `GET /api/pets/{petId}/photos` | `{photoRevision, photos}`，校验家庭归属 |
| `GET /api/tasks?petId=…&state=pending&offset=0` | `state` 支持 `pending/completed/inactive/all`；`{items, hasMore}` |
| `GET /api/tasks/{taskId}` | 单次详情及最近 30 条关联事件，包含已取消/跳过 |
| `PATCH /api/tasks/{taskId}` | `{completed: true/false}`；保留顶层 `completed` 兼容旧客户端 |
| `PATCH /api/tasks/{taskId}/schedule` | `{dueAt: ISO UTC}`，只改本次 |
| `PATCH /api/tasks/{taskId}/disposition` | `{action: CANCELLED/SKIPPED}` |
| `PATCH /api/tasks/{taskId}/assignment` | `{memberId: id/null}`，局部返回 |
| `GET /api/care/history?petId=…&cursor=…` | `{items, hasMore, nextCursor}`；游标需 URL 编码 |
| `POST /api/pets/{petId}/health/{recordId}/reminder` | `{dueAt: ISO UTC}`，创建或更新同记录未完成提醒 |

## 验证与迁移

新增 `V13__care_occurrence_state.sql`，保留 V1–V12，不重建业务数据。部署顺序为数据库迁移/后端，再更新客户端。

自动化覆盖本地午夜与多宠同名、图片缓存失效、通知冷/热启动、重复提交、完成失败重试、局部更新撤销、取消详情同步、历史翻页、健康提醒界面、重复发生标识、越权与幂等。真实 HTTP 验证脚本为 `scripts/care_rounds_smoke_test.py`，原重复照护回归仍为 `scripts/care_smoke_test.py`。

```sh
cd mobile
flutter analyze
flutter test
PETCARE_QA_FONT=assets/fonts/NotoSansSC-Regular.ttf flutter test tool/care_rounds_visual_qa_test.dart
```

后端使用独立测试数据库配置 `DB_URL`、`DB_USERNAME`、`DB_PASSWORD` 后运行 `backend/./mvnw test`。启动 API 后，通过 `API_BASE_URL` 指定其地址运行上述 Python 脚本。测试脚本只清理自己创建的账号。

2026-09-17 本机原开发库发现 12 条 `care_tasks.pet_id` 找不到宠物的既有孤立记录；MySQL 添加外键时重新校验，阻止 V13 第一条语句执行。该库未应用任何 V13 列变更，本次失败迁移标记已清除，业务记录未删除或修补。完整迁移、后端测试和 HTTP 冒烟均使用独立的 `petcare_care_rounds_test` 数据库。原库升级前需确认孤立记录的归属或备份后制定修复方案，不能直接跳过外键校验。

只读诊断：

```sql
SELECT COUNT(*) AS orphan_tasks
FROM care_tasks t LEFT JOIN pets p ON p.id=t.pet_id
WHERE p.id IS NULL;
```

视觉 QA 输出到 `/private/tmp/petcare-care-rounds-qa/`，覆盖 393×852 的首页、详情、操作区、安排列表与历史列表。通知 payload 和路由已自动验证，锁屏送达、系统权限、省电模式、跨设备同步取消仍需 iOS/Android 真机验收。
