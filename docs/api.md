# 开发 API

接口根路径 `/api`。除健康检查与创建会话外均需要 `Authorization: Bearer <token>`。会话令牌只在创建时返回，应保存在设备安全存储中。请求体为 JSON，时间采用带时区的 ISO-8601。

| 方法 | 路径 | 请求体 / 行为 |
| --- | --- | --- |
| GET | `/health` | 实际查询数据库，成功返回 `status=ok, database=mysql` |
| POST | `/session` | 无请求体；创建独立家庭和设备身份，201 返回 `token` |
| GET | `/dashboard` | 当前家庭的 `pets`、`tasks`、`members` |
| POST | `/pets` | `name`（1–60 字符）、`species`（cat/dog/other）；可选 `photoData`、`biography`（最多 1000 字符）、`birthDate`（YYYY-MM-DD，不晚于今天）；201 返回 id |
| PATCH | `/pets/{id}` | 更新上述档案字段；`createdAt` 由服务器维护，编辑不改变创建时间 |
| DELETE | `/pets/{id}` | 删除本家庭宠物和所有事项，204 |
| POST | `/tasks` | `petId`、`title`（1–120 字符）、`dueAt`；201 返回 id |
| PATCH | `/tasks/{id}` | `completed` 布尔值；显式设定状态，重复调用安全 |
| POST | `/invites` | 返回一次性 `code`，24 小时有效；废弃本家庭旧邀请码 |
| POST | `/join` | `code`；仅空的单成员家庭可以加入 |
| DELETE | `/account` | 删除本设备身份，204；最后成员离开时清空家庭 |

400 输入不合法；401 缺少/无效令牌；404 记录不存在或无权访问、邀请码不存在/已使用/过期；409 家庭合并条件不满足。客户端不依赖后端异常消息。

每次读写从认证身份查询家庭，客户端不能指定 householdId 来扩大权限。数据库外键确保删除宠物清理事项、删除最后家庭清理所有共享数据。邀请码高熵随机生成，服务端仅保存哈希摘要。

当前功能供开发验证。分页、配额、正式身份恢复、令牌有效期、限流和并发冲突重试需在生产发行前完善。

## 照护计划与历史扩展

`POST /tasks` 支持可选 `frequency: NONE|DAILY|WEEKLY`、`zoneId` 和 `careType: FEEDING|DEWORMING|VACCINE|WALK|GROOMING|CUSTOM`；未传类型时为 `CUSTOM`。类型和自定义标题分别保存，并传递到重复安排及照护记录；`DELETE /plans/{id}` 停止计划；`PATCH /profile` 更新 `name`。看板新增 `me`、`plans`、最近 100 条 `history`，详见[照护闭环说明](care-workflow.md)。

## 宠物档案

看板 `pets` 返回 `photoData`、`biography`、`birthDate`、`createdAt`。生日是无时区日期；创建时间为 UTC 时间戳。年龄由客户端按生日计算，不另存会过期的年龄字段。V7 之前的档案没有可靠创建时间，`createdAt` 保留 null；新建档案由数据库自动记录时间。

使用 `python3 scripts/profile_smoke_test.py` 验证档案保存、生日校验、编辑保留创建时间、家庭隔离及照护类型传递。测试使用独立身份并自动清理。

## 日常照护局部状态与分页

新增精简看板、按版本相册、安排改期/取消/跳过、单任务详情、游标历史和健康提醒关联接口；请求与响应见[日常照护分轮优化](care-iterations.md#接口)。


## 逾期分组与批量跳过

- `GET /api/care/overdue/groups?petId=...&before=...`：`before` 为设备当天零点的 UTC 时间；可带 `from`（含）、`to`（不含）、`asOf`、`cursor`。返回 `total / recurringTotal / singleTotal / asOf / items / hasMore / nextCursor`，每页 20 个计划 ID 分组，含次数、首末时间。
- `GET /api/care/overdue/items`：相同筛选参数，加 `groupId`（计划 ID 或 `single`），每页 30 条；沿用响应游标。后续请求携带首次返回的 `asOf`。
- `POST /api/care/overdue/preview`：`{petId,before,from?,to?,asOf,allRecurring,groupIds,excludedGroups,excludedIds,items:[{id,revision}]}`。`allRecurring` 永远排除无计划的单次事项；单次事项只能通过 `items` 明确选择。服务端冻结待处理 ID 与版本，返回批次统计，确认后再 apply。5000 条上限、每分钟每账号 10 次预览，预览 15 分钟有效。
- `POST /api/care/overdue/batches/{id}/apply`：每次最多处理 100 条，重复调用到 `finished=true`，网络失败后使用同一 ID 继续。返回 `id,state,finished,total,success,changed,failed,remaining`。状态已变化或已删除计入 changed；不会覆盖更新后的记录。
- `GET /api/care/overdue/batches/current?petId=...`：获取本人在当前家庭该宠物的最近已开始/完成批次，支持恢复处理及结果查看。
- `GET /api/dashboard?compact=true&overdueBefore=...`：提供每只宠物准确的 `overdueSummary[{petId,count,singleCount}]`，并优先返回当天及未来任务。批量接口需要 CARE 权限，读接口需要 READ 权限。


### 批次结果与恢复（V22）

- `GET /api/care/overdue/batches?petId=...&unfinished=true&cursor=...`：本人、当前家庭、指定宠物的未完成批次；`unfinished=false`（默认）包括已处理／已结束，每页 20 个，按创建时间与 ID 倒序。未确认预览不列入管理列表。
- `GET /api/care/overdue/batches/{id}/items?status=FAILED&cursor=...`：每页 50 条；状态可省略或为 `PENDING / SUCCESS / CHANGED / FAILED / STOPPED`。返回 `batch,items,hasMore,nextCursor`；每条包含 `id,title,dueAt,status,reason,attempts`。名称与时间为批次快照，旧记录可能为空。
- `POST /api/care/overdue/batches/{id}/retry`：`{items:[{id,attempts}]}`，最多 1000 个，只将已完成批次里匹配尝试次数的 FAILED 记录重新排队；成功、变化、未处理项不重试。随后调用原 apply 分块接口。已有待处理项返回 `OVERDUE_BATCH_RUNNING`，已结束批次返回 `OVERDUE_BATCH_ENDED`。重试继续使用原任务 revision，不接受新版本覆盖。
- `POST /api/care/overdue/batches/{id}/end`：结束运行中批次，剩余 PENDING → STOPPED，批次 → ENDED；重复调用幂等，已成功事项保留。apply 对 ENDED 不再执行写入。
- 汇总新增 `stopped,createdAt`，ENDED 的 `finished=true`。总数为 success+changed+failed+remaining+stopped。
- reason 包括 `INTEGRITY_ERROR`（保存完整性冲突）、`STATE_CHANGED`、`REVISION_CHANGED`、`DATE_CHANGED`、`UNAVAILABLE`（已删除或不再可访问）、`USER_ENDED`；不返回原始数据库异常。


### 健康记录文件夹查看

`GET /api/pets/{petId}/health?offset=0&kind=&folder=...` 支持文件夹筛选：不带 `folder` 为全部记录，`folder=` 为未整理，其他值按文件夹名称匹配；可与 kind 叠加，筛选后每页 20 条。文件夹名须 URL 编码。返回 `folders:[{name,count}]`，为该宠物全部健康记录的文件夹计数（不受当前筛选或分页影响）。整理只改变 folder，原 kind 保留，读取仍校验 HEALTH 权限和宠物家庭归属。


### 统一照护对象（V24）

现有 pets / petId API 保留，dashboard 同时返回 pets 与 subjects，记录增加 subjectType（PET/HUMAN）、relationship、consentActive、canManageSubject、canCareSubject。旧记录默认 PET，家庭宠物共享规则不变。家人档案、逐人授权、撤回及专门用药结果 API 详见 [统一档案与授权](subjects-and-consent.md)。同一家庭的管理员也不自动获得家人档案访问权限；读取过滤先于分页／统计，写入同时检查对象授权、原家庭模块权限和版本。MEDICATION 不能通过普通完成、撤销或批量跳过代替，已服用的 MED_TAKEN 计入完成统计，其他用药结果不计完成。


### 家人阶段与叠加场景（V25）

家人档案请求与 dashboard 返回增加 `lifeStage: ELDER|CHILD|OTHER`、`careScenarios: [DAILY,RECOVERY]`。创建时省略为 OTHER + DAILY；更新时省略保留原值。场景可叠加、至少一个、禁止重复，不符合返回 400。已有家人迁移为 OTHER + DAILY/RECOVERY，以保留原有模板范围，旧宠物不变。模板分类新增 HUMAN 专用的 NURTURE、SLEEP、GROWTH、PICKUP、HANDOVER、OBSERVATION；选择场景只影响前端模板推荐，不限制已有合法任务的查看和处理。
