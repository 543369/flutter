# 邮箱验证、密码找回与 Apple 登录

## 使用入口

- 登录页 → 忘记密码：输入注册邮箱，发送验证码，粘贴邮件中的完整验证码并设置新密码，然后返回登录。
- 家庭 → 账号安全 → 验证邮箱：发送验证码并确认；账号安全显示验证状态。
- iOS 登录页 → 通过 Apple 登录：调用系统授权，后端校验身份并创建或恢复同一 Apple subject 的账号。

邮箱验证码为高熵随机字符串，15 分钟有效，服务端仅保存摘要，单次使用。每账号每用途最多每分钟发送一次；接口另有来源 IP 限流。重置密码撤销全部会话；普通修改密码也使未使用的找回验证码失效。未知邮箱的找回请求返回相同 204，不泄露账号是否存在。注册仍允许未验证用户进入应用，状态独立展示。

## 邮件配置

在后端进程环境配置 `.env.example` 中的 `SPRING_MAIL_*` 和 `PETCARE_MAIL_FROM`。本地启动脚本读取 `.local/backend.env`，请在该私有文件添加 `export KEY=value`；Docker 环境需要显式传入这些变量。配置 SMTP 提供商允许的发件地址及 TLS。不要提交密码，不要在聊天中发送密钥。

未配置邮件服务时返回 503，App 显示尚未配置；不会把验证码写入日志或用假发送替代邮件。自动化测试使用 mock 邮件发送器验证正文和数据库流程，尚未验证真实邮件送达。

## Apple 配置与范围

后端 `APPLE_CLIENT_ID` 必须与 iOS Runner 的 Bundle Identifier 一致；Apple Developer 中为该 App ID 启用 Sign in with Apple，重新生成带该权限的签名描述文件。Runner.entitlements 已添加对应权限。

服务端使用 Apple 公钥验证 RS256 JWT，校验 issuer、audience、时间和一次性 nonce。不会根据客户端传来的邮箱匹配账号，也不会按相同邮箱自动合并。Apple 用户使用独立 subject；当前不请求邮箱及姓名，默认称呼可以在家庭页修改。暂未提供 Apple 与密码账号合并，以及 Android 的 Apple 网页授权流程。

尚需配置后在签名真机上完成真实 Apple 授权验收。当前实现本地账号删除；App Store 发布前还需接入 Apple authorization code 交换、Apple 授权撤销及服务端撤销通知生命周期，不能把本次基础登录接入当作完整上架验收。

官方参考：https://developer.apple.com/documentation/signinwithapple/authenticating-users-with-sign-in-with-apple

## 接口与验证

- GET `/api/auth/email/status`：邮箱、验证状态和是否拥有密码（需登录）。
- POST `/api/auth/email/request`、`/email/confirm`：发送及确认邮箱验证码（需登录）。
- POST `/api/auth/recovery/request`：`{email}`；`/recovery/confirm`：`{code,password}`。
- POST `/api/auth/apple/challenge`：一次性 nonce；`/apple/login`：`{identityToken,nonce}`。

`EmailIdentityTests` 使用真实数据库事务和 mock 邮件测试验证/重置单次使用、未知邮箱及旧会话撤销；`AppleIdentityTests` 使用 mock JWT decoder 测试 audience、nonce、重放和稳定账号映射，并不代表真实 Apple 联调完成。Flutter 表单测试覆盖验证和密码清理。
