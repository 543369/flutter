# 模块划分与登录注册

## 已实现的账号流程

- 新用户默认进入登录页，可切换邮箱注册。注册填写邮箱、照护称呼、密码及确认密码，成功后进入家庭看板。
- 密码要求至少 10 个字符且 UTF-8 编码不超过 72 字节，服务器使用 BCrypt（cost 12）保存哈希；不保存明文密码。
- 邮箱作为登录标识，统一去除首尾空格并转小写；重复邮箱拒绝创建。
- 每次登录创建独立随机会话，服务器只存令牌摘要，有效期 30 天。多个设备登录同一账号共享同一个家庭身份，不增加成员数。
- 家庭页面支持退出登录。退出撤销当前设备的服务端会话并清空本地凭据，清理本机提醒；其他设备会话不受影响。
- 登录过期后客户端回到认证入口。网络暂时失败不会直接清除账号或服务端资料。
- 原设备身份可在“家庭 → 绑定账号”绑定一个未注册邮箱，保留家庭、宠物和照护历史；绑定后旧令牌撤销。未提供合并到已有邮箱账号的流程，不会静默覆盖已有资料。
- 删除账号会撤销全部会话，沿用最后成员离开时删除家庭资料的规则。

邮箱验证、邮件找回密码与 iOS Apple 基础登录已接入，配置与验收范围见 [邮箱与 Apple 登录](email-and-apple.md)。当前认证接口按来源 IP 一分钟最多 20 次，为单进程内存限流。

## Flutter

```text
mobile/lib/
  main.dart                         启动入口
  app/
    petcare_app.dart                 主题、语言与应用根组件
    home_shell.dart                  导航、共享状态、同步与会话切换
  core/network/
    care_api.dart                    HTTP、凭据保存、会话请求
  features/
    auth/auth_panel.dart             登录/注册表单、校验、错误展示
    pets/pet_module.dart             宠物页面与档案操作
    care/care_actions.dart           创建计划、完成与撤销操作
    care/care_view.dart              看板、历史、重复计划展示
    care/reminder_service.dart        本地通知授权与队列同步
    family/family_module.dart        称呼、邀请、加入、绑定和退出入口
```

业务模块以 Dart extension 组织现有视图和操作，共用 `CareHomeState` 的同步/导航状态；这是当前规模下的模块拆分，不是互不依赖的独立子应用。`api.dart`、`reminders.dart` 仅保留兼容导出，避免旧引用立即失效。新增功能应放在对应 features 目录，不能继续堆到 main.dart。

## Java

```text
com.petcare/
  PetCareApplication                启动与调度启用
  auth/                             登录注册控制器、账号服务、限流、令牌鉴权
  account/                          称呼更新、账号删除
  pets/                             宠物接口
  care/                             照护接口、重复规则、计划生成与调度
  family/                           邀请与家庭加入
  dashboard/                        看板聚合读取
  shared/                           家庭鉴权/锁辅助、健康检查
```

接口 URL 保持兼容。原先集中在根目录 `CareController` 的宠物、家庭、账号和看板接口已迁出，`care/CareController` 只保留照护事项和重复计划接口。认证业务在 `AuthService` 中处理事务和密码，控制器负责输入校验。

## 迁移与接口

`V3__registered_accounts.sql` 增加邮箱/密码哈希以及独立的 `account_sessions` 表，并将迁移时已有设备令牌迁入 30 天会话。没有改写 V1/V2，不清空原项目数据。

| 接口 | 行为 |
| --- | --- |
| POST `/api/auth/register` | `{email,password,name}`；201 返回 token。带有效旧设备令牌时升级原身份 |
| POST `/api/auth/login` | `{email,password}`；200 返回 token |
| POST `/api/auth/logout` | 需要 Bearer token；撤销本次会话，204 |
| GET `/api/dashboard` | 新增 registered，指明是否已绑定邮箱 |

旧 `/api/session` 为旧设备兼容和测试保留，新用户 UI 不再调用。旧令牌不应通过直接查询 accounts.token_hash 认证，统一经过 account_sessions 和有效期检查。

## 验证

- Flutter：认证表单错误密码、确认密码匹配、成功注册回调；原有照护/历史/提醒测试。
- Java：构建、上下文/UTC 会话测试、重复时间与 DST 测试。
- `scripts/auth_smoke_test.py`：注册、重复邮箱大小写归一、错误密码、多设备登录、退出撤销、旧身份绑定保留宠物、过期/撤销令牌拒绝、删除后的所有会话失效。
- 原有 `scripts/smoke_test.py` 和 `scripts/care_smoke_test.py` 继续回归。

## 账号安全（已实现）

入口：家庭 → 账号安全。支持修改密码、查看登录会话、退出指定其他会话和退出其他全部会话。修改密码需要验证当前密码，成功后保留本次登录并撤销其他会话。设备名称由客户端提供，同一设备可以有多个会话；历史会话没有时间信息时显示未知。

独立页面：`mobile/lib/features/auth/account_security_page.dart`。V4 迁移为会话增加非凭据 ID、设备名称、创建和活动时间，接口不返回令牌或其摘要。

- POST `/api/auth/password`：`{oldPassword,newPassword}`，成功 204。
- GET `/api/auth/sessions`：当前账号有效会话。
- DELETE `/api/auth/sessions/{id}`：撤销其他会话，禁止操作其他账号或当前会话。
- POST `/api/auth/sessions/revoke-others`：保留当前会话。

验证：`scripts/security_smoke_test.py` 覆盖密码更换、错误密码、账号隔离、撤销及当前会话保留；`mobile/test/account_security_test.dart` 覆盖确认密码校验、成功清空密码和失败后重试。
