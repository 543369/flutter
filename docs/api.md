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
