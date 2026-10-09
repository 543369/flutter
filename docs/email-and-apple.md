# 邮箱验证、密码找回与 Apple 登录

## 使用入口

账号安全页始终显示邮箱验证入口及状态。密码账号须先验证邮箱，才可填写和提交修改密码表单；后端也会拒绝未验证账号的改密请求（403 / EMAIL_VERIFICATION_REQUIRED）。验证完成返回后自动刷新解锁。Resend 未配置时，发送验证邮件会提示服务暂不可用，不绕过验证。

完成 Resend 配置并验证真实送达后，在 Flutter 运行或打包命令中增加 `--dart-define=EMAIL_ACTIONS_ENABLED=true`，重新构建即可开放登录页的“忘记密码”入口。此开关仅控制客户端展示，不替代后端邮件配置，也不改变后端认证或验证规则。

- 登录页 → 忘记密码：输入注册邮箱，发送验证码，粘贴邮件中的完整验证码并设置新密码，然后返回登录。
- 家庭 → 账号安全 → 验证邮箱：发送验证码并确认；账号安全显示验证状态。
- iOS 登录页 → 通过 Apple 登录：调用系统授权，后端校验身份并创建或恢复同一 Apple subject 的账号。

邮箱验证码为高熵随机字符串，15 分钟有效，服务端仅保存摘要，单次使用。每账号每用途最多每分钟发送一次；接口另有来源 IP 限流。重置密码撤销全部会话；普通修改密码也使未使用的找回验证码失效。未知邮箱的找回请求返回相同 204，不泄露账号是否存在。邮箱注册必须先通过验证码验证，完成后账号直接标记为已验证；已有未验证账号仍可登录，但必须验证后才能修改密码。

## 邮件配置

默认使用 Resend HTTP API；邮箱验证和密码找回共用发送服务。本机已配置私有 API Key，并使用 Resend 测试发件地址；未发送真实邮件，尚未验证自有发信域名。

1. 在 Resend 添加自有发信域名或子域名，按控制台提供的 DNS 记录完成验证。建议账号邮件使用独立子域名，例如 `mail.example.com`。参见 [域名验证](https://resend.com/docs/dashboard/domains/introduction)。
2. 创建专用发送 API Key，按需限制发信域名，仅保存在后端私有环境中。参见 [API Key 配置](https://resend.com/docs/dashboard/api-keys/introduction)。
3. 在 `.local/backend.env` 中添加以下环境变量，再重启本地 API；以下均为占位值，不是有效凭据：

   ```sh
   export PETCARE_MAIL_PROVIDER=resend
   export RESEND_API_KEY='替换为实际APIKey'
   export PETCARE_MAIL_FROM='PetCare <noreply@mail.example.com>'
   ```

   `PETCARE_MAIL_FROM` 必须属于已验证的发信域名。不要把 API Key 写进 Flutter、网站、Git 或聊天。
4. Docker 部署时在项目根目录私有 `.env` 配置同名变量，执行 `docker compose up -d --build api`。Compose 已映射这三个变量。
5. 配置后用自己的测试账号验证收件箱与垃圾邮件、验证码确认、重发和密码找回。HTTP 成功仅表示 Resend 接受请求，不保证实际送达；可在 Resend 控制台查看投递状态。本次未实现投递状态 Webhook。
6. 确认真正送达后，再通过 `--dart-define=EMAIL_ACTIONS_ENABLED=true` 构建 App 开放登录页密码找回入口。注册页点击“发送验证码”，填写邮件中的完整验证码后才能注册；已有未验证账号可在“账号安全”中主动发起验证。

服务端调用固定的 `https://api.resend.com/emails`，使用 Bearer API Key，发送中英双语纯文本验证码邮件。连接超时 5 秒、请求超时 10 秒；未配置、服务商拒绝或超时均返回 503，不记录验证码、密钥或完整服务商响应。参考 [发送 API](https://resend.com/docs/api-reference/emails/send-email)。

发送失败时数据库事务回滚，不消耗账号的发送冷却时间；不会自动重试，用户可再次发起。极少数情况下，服务商已接受但网络响应丢失，会收到无法确认的旧验证码，此时重新发送并使用最新邮件。接口 IP 限流继续有效。发送成功后每账号每用途 60 秒内不重复发信。

如需保留旧 SMTP 提供商，将 `PETCARE_MAIL_PROVIDER=smtp`，配置 `.env.example` 中的 `SPRING_MAIL_*` 和 `PETCARE_MAIL_FROM`。587 默认 STARTTLS；465 SSL 需将 `SPRING_MAIL_PROPERTIES_MAIL_SMTP_SSL_ENABLE=true`，两项 STARTTLS 变量设为 false。Resend 模式不使用 SMTP 配置，失败时也不会自动切换服务商。

自动化测试使用模拟 HTTP／SMTP，不发送真实邮件。登录页密码找回入口默认保持隐藏；账号安全页验证邮箱入口始终显示；后端不会用假发送替代真实服务。

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

## 注册邮箱验证

注册页填写邮箱 → 发送验证码 → 填写完整验证码、密码和确认密码 → 注册并登录。邮箱格式错误时不会发送；重发冷却 60 秒，验证码 15 分钟有效。发送请求不创建账号、不保存密码，成功注册时在同一事务中消费验证码、创建／升级账号、标记邮箱已验证并签发登录凭据。游客绑定邮箱保留原家庭及资料。

- POST `/api/auth/register/request`：`{email}`，成功 204；该接口无需登录，有 IP 与邮箱限流。
- POST `/api/auth/register`：原有字段外必须提供 `code`；错误／过期／邮箱不匹配返回 400 / `REGISTRATION_CODE_INVALID`。旧客户端不提供验证码无法注册，需同步更新前后端。
- V18 新增注册验证表，验证码仅存摘要；过期记录定期清理。发送失败事务回滚，可重新尝试。
- 此要求不受 `EMAIL_ACTIONS_ENABLED` 控制。Resend 未配置时无法完成新邮箱注册，不提供开发绕过开关；Apple 登录流程不受影响。
- 原先直接调用注册接口的 HTTP smoke 脚本需先取得对应邮箱的验证码再提交；不要连接生产库造验证状态。无真实邮件的自动化覆盖见 `RegistrationVerificationTests`（mock 邮件）。

### 本机当前测试配置

私有 `.local/backend.env` 已配置 Resend API Key 和 `PetCare <onboarding@resend.dev>`。本地后端在 18080 加载配置，V18 迁移已执行。

没有自有域名时，此地址只能发送到 Resend 账号所关联的本人邮箱；请用该邮箱测试注册／验证。其他地址会被服务商拒绝。面向真实用户上线前，须验证自有域名并替换 `PETCARE_MAIL_FROM`。参见 [Resend 测试域名限制](https://resend.com/docs/knowledge-base/403-error-resend-dev-domain)。本次只检查服务健康及配置加载，没有发送邮件，也没有验证真实送达。
