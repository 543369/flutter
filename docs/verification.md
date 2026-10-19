# 验证记录

日期：2026-09-07。本项目新建于独立 `petcare/` 目录，未修改 `agent01`。

| 检查 | 结果 |
| --- | --- |
| Flutter 3.27.1 / Dart 3.6 依赖安装 | 通过，锁定依赖到 pubspec.lock |
| Flutter analyze | 通过，No issues found |
| Flutter tests | 6 项通过（新增注册确认校验与错误登录）：入门/语言、完成/撤销/历史界面、提醒筛选上限、原生通知通道调度/取消去重（模拟） |
| Maven package / Spring 上下文测试 | 通过，6 项测试（含 5 项重复时间/DST 测试），无失败或错误；本机 Java 23，编译目标 Java 21 |
| Flyway / MySQL 真实连接 | 通过，MySQL 9.7.1，V1 / V2 迁移通过 |
| HTTP 集成测试 | 28 项检查通过；覆盖中英文写入、参数校验、跨家庭访问拒绝、邀请共享、一次性邀请码、幂等完成、账号撤销、级联删除 |
| 测试清理 | accounts / households 剩余记录均为 0 |
| Docker Compose 配置校验 | `docker compose --env-file .env.example config --quiet` 通过 |
| Docker 镜像构建 / MySQL 8.4 运行 | 未执行：本机 Docker daemon 未启动 |
| iOS 模拟器构建 | 未通过：平台工具已下载、pod install 成功；Xcode 无匹配的 iOS Simulator 构建目标，报告缺少 iOS 26.5 平台组件 |
| 真机、签名 IPA、TestFlight、App Store 审核 | 未执行 |

数据库与 API 为本机开发实例，分别监听 `127.0.0.1:13316` / `127.0.0.1:18080`。数据库管理员密码随机生成；应用密码按用户后续要求修改，文件在被忽略的 `.local/` 内，权限 600。仓库忽略构建产物和凭据；未提交代码到远端。

不能从这些测试推出生产可用：真机通知、账号恢复、限流、生产 HTTPS、稳定 Flutter/iOS 兼容、隐私政策与 App Store 资料仍需按发布文档完成。

照护闭环 HTTP 回归通过：日/周重复生成、多人并发完成去重、撤销、停止计划后保留历史、取消事项拒绝操作、跨家庭隔离、退出成员匿名化。原有 28 项检查仍通过。后端已增加每小时计划补充；本机 iOS 仍缺平台组件，原生送达未验收。

2026-09-08：按 auth/account/pets/care/family/dashboard/shared 拆分后端，Flutter 按 app/core/features 拆分。V3 迁移与认证 HTTP 回归通过，旧设备升级保留资料、退出撤销和账号删除均验证。原 28 项与照护回归继续通过。

## 2026-09-17 日常照护分轮优化

- Flutter 完整测试：48 项通过。
- 后端隔离 MySQL 测试：22 项通过，含 V13 全量迁移、发生项去重、局部响应、健康提醒与游标分页。
- `scripts/care_rounds_smoke_test.py` 与 `scripts/care_smoke_test.py` 在独立 18091 测试端口通过，测试账号已自动清理。
- `tool/care_rounds_visual_qa_test.dart`：393×852 首页、详情、操作区、安排列表、历史列表渲染通过并人工查看。
- 原开发库的 V13 升级被 12 条既有孤立任务阻止；未删除业务记录。诊断、数据库状态及真机验收范围见[分轮说明](care-iterations.md#验证与迁移)。

## 2026-10-09 Google Play / RevenueCat 接入

- 后端 `RevenueCatTests`、`RevenueCatIntegrationTests`、`BenefitsTests`：13 项通过。覆盖环境／商品／退款／到期校验、宽限期、回调鉴权和重复事件、固定家庭归属、游客限制、角色变化后恢复、缓存过期及删除后购买身份保留。
- 独立 `petcare_revenuecat_test` 库的 V1–V17 全量迁移通过。旧 `petcare_care_rounds_test` 库存在 V13 校验和不一致，未执行 repair，未改动业务库。
- Flutter 默认渠道测试 `revenuecat_page_test.dart`、`benefits_test.dart`、`auth_panel_test.dart`：7 项通过。
- 模拟 Google Play 渠道购买测试：3 项通过，覆盖 SDK 成功但服务端未确认、恢复后确认、游客不初始化 SDK、付款前换家庭不进入商店。执行：

  ```sh
  flutter test test/revenuecat_purchase_test.dart \
    --dart-define=DISTRIBUTION_CHANNEL=google_play \
    --dart-define=REVENUECAT_GOOGLE_API_KEY=goog_test_only
  ```

- 支付页面与新增支付测试的定向 `flutter analyze` 通过。模拟测试使用假 SDK 返回值，不是商店真实交易。
- 尚未创建 RevenueCat／Play 项目和商品，真实支付、到账、退款及生产发布签名未验证；默认支付关闭。
- Google Play 渠道 Android 调试 APK 构建成功：`mobile/build/app/outputs/flutter-apk/app-debug.apk`。使用 `goog_build_check_only` 占位公共 key，仅验证原生 SDK 编译，不可用于真实支付。首次构建补齐 Gradle 8.14.3、NDK 28.2、Android 36 与 CMake 组件；仍有 Gradle／AGP 后续升级提示及 Java 8 编译选项警告，未跳过依赖版本检查。

## 2026-10-09 Resend 邮箱服务

- `IdentityMailSenderTests` 与 `EmailIdentityTests`：8 项通过。模拟 HTTP 校验 Resend 固定地址、认证头和 UTF-8 正文；覆盖缺配置、401/403/429/500、超时和不完整成功响应。独立测试库验证发送失败回滚、重试、重发冷却、验证／重置单次使用和会话撤销。
- Flutter `email_action_test.dart`、`account_security_test.dart`：4 项通过。
- 默认邮件提供商改为 Resend，可显式配置 `PETCARE_MAIL_PROVIDER=smtp` 使用旧 SMTP；邮件入口仍由默认关闭的构建开关控制。
- 尚未创建 API Key／验证发信域名，未发真实邮件；模拟测试不代表实际送达验收。

## 2026-10-09 macOS CocoaPods 启动修复

- 本机 `/opt/homebrew/bin/pod --version` 返回 1.16.2。
- 根目录和 `mobile/.vscode/settings.json` 为 Dart/Flutter 设置包含 Homebrew 的 macOS PATH，兼容两种 IDE 打开目录方式。
- `flutter build macos --debug` 成功，`pod install` 成功。
- 使用同一 PATH 执行 `flutter run -d macos --debug --no-resident` 成功退出，完成设备同步，并确认 `petcare.app/Contents/MacOS/petcare` 进程运行。自动切到前台提示 `open returned 1`，未确认窗口置前。
- 三个旧插件仍有 Swift Package Manager 支持警告，目前通过 CocoaPods 正常构建。

## 2026-10-09 修改密码前必须验证邮箱

- 账号安全页恢复常驻邮箱验证入口；未验证时禁用密码字段和提交，验证返回后刷新解锁。身份加载未完成时不展示可操作的改密表单。
- 后端 `/api/auth/password` 校验 `email_verified`，未验证返回 403 / `EMAIL_VERIFICATION_REQUIRED`；已验证仍校验当前密码，成功后保留当前会话并撤销其他会话。密码找回继续使用一次性邮件验证码确认身份。
- `EmailIdentityTests` + `IdentityMailSenderTests` 共 9 项通过；Flutter 账号安全与邮箱操作测试共 5 项通过。未发送真实邮件，Resend 配置仍需完成。

## 2026-10-09 注册前邮箱验证

- V18 注册验证码迁移在独立测试库执行成功；正式服务更新时需执行该迁移。
- `RegistrationVerificationTests`、`DefaultNameRegistrationTests`、`EmailIdentityTests` 共 11 项通过，覆盖邮箱绑定、过期、旧码、重放、重发限流、发送失败回滚、游客保留家庭、验证状态和昵称生成。
- 注册表单 4 项测试通过；账号安全和邮箱操作 5 项回归通过；注册页面、API 客户端与注册测试静态检查通过。
- 新注册接口必须提供验证码，旧版客户端及直接注册的 HTTP smoke 脚本需要适配。未配置 Resend 时不会开放免验证注册，也未发送真实邮件。

## 2026-10-19 离线照护与 FCM/APNs 接入

- 独立 `petcare_sync_test` 库完成 V1–V19 全量迁移；后端完整回归 67 项通过。新增覆盖幂等重放、依赖操作撤销、版本冲突、家庭隔离、单次跳过、旧接口版本递增、有效会话收件人与发送期间新增失效通知。
- Flutter 完整回归 70 项通过，3 项渠道相关测试按默认构建配置跳过；最终定向回归 14 项通过，覆盖队列重启恢复、丢失响应、冲突链、会话失效封存与同账号恢复、存储失败、首页与逾期批量操作及照片缓存。
- Flutter analyze 通过；Android 调试 APK 构建成功，包含 Firebase 原生插件。仍有现有 Gradle/AGP 升级提示和 Java 8 编译选项警告，未绕过依赖检查。
- 本地业务库升级前已保存私有 SQL 备份；V19 迁移成功，后端在 `127.0.0.1:18080` 重启，健康检查通过。
- 推送按用户选择保持默认关闭；尚无 Firebase/Apple 账号配置，未发送真实 FCM/APNs 消息，未完成双机后台提醒验收。iOS entitlement 与 Info.plist 格式检查通过，不代表签名真机构建验收。
- 支持范围、配置模板与真机验收步骤见[离线照护与推送](offline-and-push.md)。离线功能仅覆盖已有照护事项的完成／撤销、单次改期、照护人分配、跳过与取消；新建计划、健康／回忆／宠物表单编辑和附件上传仍需联网。

## 2026-10-19 更换邮箱、绑定 Apple 与管理员移除成员

- 独立测试库 V20 迁移通过；后端完整回归 75 项通过。新增覆盖邮箱更换的账号／会话绑定、旧密码校验、验证码单次使用、过期、冷却、密码变化失效、邮箱占用及邮件失败事务回滚；Apple 绑定的独立 nonce、当前密码、不同会话拒绝、占用冲突和绑定后同账号登录；成员移除的管理员权限、跨家庭／自身保护、共享历史保留、新空家庭与任务负责人清理。
- Flutter 完整回归 73 项通过，3 项渠道相关测试按默认构建配置跳过；Flutter analyze 通过。新增覆盖邮箱表单校验、无效验证码重试、Apple 原生授权通道（模拟）与成员移除确认／取消流程。
- 真实 MySQL/HTTP 联调发现身份查询表达式返回整数，已用 JDBC getBoolean 明确输出 verified、hasPassword、appleLinked 布尔值，并加入回归断言。
- 本地数据库备份后成功应用 V20，后端已重启。真实 HTTP 验证账号状态、管理员移除成员后的数据保留与新家庭隔离，以及游客无法更换邮箱；临时测试账号已清理，没有发送真实邮件。
- 邮件投递和 Apple 签名真机授权仍待外部配置及验收；模拟 SMTP、JWT decoder 和原生授权通道不代表真实服务已开通。相关产品说明及 README 已更新。

## 2026-10-19 逾期事项分组、分页与批量处理

- 后端完整测试 80 项通过；新增覆盖 333 条准确计数、记录/计划游标分页、同名不同计划隔离、日期范围、跨家庭拒绝、205 条分块处理、重试幂等、版本变化与删除统计、排除选择、预览过期。最终日期边界与首页优先排序修改后，OverdueTests / DashboardReadTests 再次通过。
- Flutter 完整测试 76 项通过，3 项跳过；新增分组默认折叠、选择尚未加载的记录、排除单条、单次提醒不随全选、断线使用同批次恢复等测试。静态检查通过。
- 手机 393×852 与桌面 900×650 渲染通过，检查折叠分组、单次事项和底部固定操作栏；`mobile/tool/overdue_visual_qa_test.dart` 可复现，截图使用隔离模拟数据。
- 本地业务数据库备份后成功应用 V21，后端已重启。真实 HTTP 使用临时家庭验证准确计数、单次事项明确选择、批量跳过、同批次重试幂等和处理后计数归零，临时账号与家庭已删除。
- 批量处理需联网，单批上限 5000，每次 apply 100 条；离线单项操作仍沿用原有队列。未执行生产部署及真机推送验收。
