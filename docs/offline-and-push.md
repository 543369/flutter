# 离线照护与跨设备同步推送

2026-10-19。代码已接入；推送默认关闭，尚未配置 Firebase 项目、APNs 密钥或完成真实设备收发验收。不能把本地测试通过当作真实推送已开通。

## 已实现的离线范围

- 已同步过的家庭首页可在断网冷启动时读取本机加密缓存。
- 已有照护事项的完成／撤销、单次改期、照护人分配、跳过和取消先写入加密操作队列，再发送到服务端。离线操作更新本机待办和提醒，不伪造已同步的服务端完成历史。
- App 前台每 30 秒、回到前台、下拉刷新时尝试同步。联网后需 App 处于运行状态；未实现由系统保证执行的后台上传任务。
- 待同步横幅提供操作列表、冲突提示和放弃某个事项整条本机修改链的入口。发生冲突时不自动覆盖家人修改；核对最新状态后可重新操作。退出登录前要求处理队列。
- 同一事项多次离线操作依次发送，用父操作回执衔接版本。请求超时、响应丢失和重启后重试使用原操作编号；服务端回执防止重复记完成记录。回执随账号删除清理，不能在仍可能重试时直接清空回执表。
- 会话失效时未上传操作按账号封存；重新联网登录同一账号、读取服务端账号身份后恢复。不会向另一个账号或另一个家庭重放。
- 当前不支持离线创建宠物／新照护计划、修改整套重复计划、图片上传、健康档案／回忆录／个人资料编辑、家庭加入／角色修改或支付。这些操作仍要求联网，失败不会假报已保存。

服务端任务 `revision` 在所有应用内修改路径递增。`POST /api/care/sync` 校验家庭、CARE 权限、版本、依赖操作和幂等编号。版本冲突返回 `SYNC_CONFLICT`，权限失效、删除和家庭变化也会暂停操作。手工直接修改数据库不会自动维护这些应用层约束。

## 推送的工作方式

家庭写操作与 `push_outbox` 在同一数据库事务提交；周期计划补充也会生成失效通知。发送任务每 15 秒读取最多 20 个家庭，使用 FCM HTTP v1，iOS 经 Firebase 配置的 APNs 通道送达。

消息只包含 CARE_CHANGED、家庭 ID 和失效版本，不含宠物名称、健康内容或登录令牌。收到后，App 必须用自己的有效登录身份重新读取最新看板，然后重新安排本机通知。前台消息刷新当前页面；后台消息刷新本机提醒，不在后台修改前台持久化操作队列。

设备令牌与具体登录会话绑定；发送前校验会话有效期、家庭归属和临时访问期限。退出、撤销会话、删除账号后不再向该旧会话发送新消息。FCM UNREGISTERED 返回会删除失效令牌；网络失败保留发送队列重试。可能重复或乱序的推送只触发读取最新状态，不直接根据消息内容完成或撤销事项。

这是尽力送达的后台同步，不是绝对即时送达：iOS 静默推送可能被限流，强制关闭 App 后需重新打开；Android 强制停止、无 Google Play 服务或无法连接 Google 服务时不能依赖 FCM。国内 Android 无 GMS 设备尚未接华为／小米等厂商推送。App 打开后的同步仍保留。

## Firebase 与后端配置

1. 创建 Firebase 项目，启用 Cloud Messaging HTTP v1，添加与正式 Android 包名、iOS Bundle ID 一致的应用。不要继续以占位包名作为正式发布身份。
2. 在 Firebase 中创建仅用于发送消息的服务账号凭据，私有 JSON 存在后端可读取的位置，例如 `.local/push/service-account.json`，权限设为 600。不放进 Flutter、网站或 Git。
3. 后端私有环境配置：

   ```sh
   export PETCARE_PUSH_ENABLED=true
   export PETCARE_PUSH_CREDENTIALS_FILE='/绝对路径/petcare/.local/push/service-account.json'
   ```

   然后重启 API。启用但凭据缺失或无效会拒绝启动；默认关闭不影响本地照护。
4. Docker 把 `.local/push/` 只读挂载到 `/run/secrets/petcare-push/`。私有 `.env` 中使用容器路径 `PETCARE_PUSH_CREDENTIALS_FILE=/run/secrets/petcare-push/service-account.json`。
5. 不要在普通请求中使用服务账号密钥；App 向 `/push/devices` 注册 FCM 令牌只使用原有 Bearer 登录态。

## Flutter 构建配置

使用 `mobile/config/push.example.json` 复制为 `.local/push-android.json` 或 `.local/push-ios.json`，从对应 Firebase 应用配置填写公开的 appId、apiKey、projectId、messagingSenderId；两个平台的 appId 不相同。JSON 不含服务账号私钥或 APNs 密钥。

```sh
cd mobile
flutter run --dart-define-from-file=../.local/push-android.json \
  --dart-define=API_BASE_URL=https://实际API域名
```

`PUSH_ENABLED=false`（默认）完全不初始化 Firebase。开启后缺配置会在页面提示重试，不影响已有本地提醒。iOS 用户通过原有提醒开关授权通知后，App 会重试设备注册。

## iOS APNs 签名

1. Apple Developer 中为正式 App ID 启用 Push Notifications，生成匹配的签名描述文件；将 APNs Authentication Key、Key ID 和 Team ID 配置到 Firebase 的 Cloud Messaging Apple 配置中。私钥仅上传 Firebase 或安全保存。
2. 在 Xcode 中确认 Background Modes → Remote notifications。Info.plist 已声明 remote-notification。
3. 复制 `mobile/ios/Flutter/Push.xcconfig.example` 为同目录私有 `Push.xcconfig`，签名真机调试用 `APS_ENVIRONMENT=development`；正式分发匹配生产签名使用 production。该配置选择 `RunnerPush.entitlements`，普通本地构建仍使用原有无 APNs 的 entitlement 文件。
4. 使用 iOS 专属的 Firebase appId 和 Bundle ID 构建，在签名真机授权通知。模拟器构建或假消息不能替代 APNs 真机验收。

## 验收

- 两台同家庭真机，A 完成、撤销、改期、跳过／取消，B 前台页面更新；B 后台在消息实际送达时取消或重排本机提醒。
- A 断网完成后重启，确认待同步队列和本机状态保留；联网打开自动上传；模拟响应丢失验证服务端事件不重复。
- 两台设备同时修改同一事项，确认冲突暂停；权限到期、退出家庭、换账号和远程撤销设备不会跨身份同步。
- 推送关闭、FCM 不可用、用户拒绝权限或强制停止时，原本的前台同步与本地提醒仍可独立使用。

官方参考：[Flutter 接收消息](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages)、[Flutter 配置](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)、[FCM HTTP v1](https://firebase.google.com/docs/cloud-messaging/send/v1-api)、[Apple 后台更新限制](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app)。
