# App Store 发布准备（2026-09-07）

当前是可联调的开发预览工程，尚未上传 TestFlight 或 App Store。Bundle ID `com.example.petcare` 为占位值，不是已注册标识。

## 发布前必须完成的产品工作

- 账号：已实现邮箱/密码注册登录、30 天会话、退出和旧设备绑定。仍需邮箱验证、密码找回、修改密码、远程设备管理与正式成员角色管理，之后再做生产身份验收。
- 照护提醒：已接入本地通知、每天/每周计划、后端周期补充和完成历史。仍须验证真机送达、锁屏/重启/权限拒绝与时间变化；跨设备即时取消需要后续 APNs 等远程推送。
- 按实际行为制作并托管中英文隐私政策、服务条款、支持页面；当前 App 内的数据说明不能替代正式隐私政策。
- 产品图标、启动页、真实机型截图、无障碍与大字号检查、离线体验、空白和失败状态、删除后的服务端与备份保留策略。
- 全链路 HTTPS、注册/邀请接口限流、日志脱敏、监控、备份恢复演练、会话过期和撤销、并发负载测试。当前开发 API 仅绑定回环地址。
- 订阅尚未实现。决定收费后，为适用的数字功能实现 StoreKit 内购、恢复购买、服务端交易验证与退款/订阅状态通知，再验证各销售地区规则。

## 国内和海外

共用 Flutter / Java 源码，分别通过 `API_BASE_URL` 指向服务。建议国内和海外使用独立数据库与运维环境，初期不做跨区域家庭同步；邀请只能在同一服务环境使用。需要产品层面告知用户所属区域，不能用界面语言推断数据区域。

面向中国大陆，在 App Store Connect 的 App Information 中核对适用的 ICP/APP 备案与类目资质字段；运营主体、服务部署位置、实际功能会影响所需手续，应在正式发行前完成核验。Apple 的[App information 官方说明](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/)列出了相关字段。

海外先选定具体国家/地区，而不是把“海外”视为同一套隐私和税务规则；本项目不包含这部分申报或法律文本。

## Apple 账户和构建

1. 准备 Apple Developer Program 会员、App Store Connect 权限及正式 Bundle ID。会员费通常为每年 99 美元或当地货币价格，见[官方注册页面](https://developer.apple.com/programs/enroll/)。
2. 本机检测：Flutter 3.27.1 / Dart 3.6、Xcode 26.6。提交前使用项目独立管理的当前稳定 Flutter，升级插件并验证 iOS 生命周期迁移；不应仅因为 Dart 测试通过就认为老 Flutter 已适配新 Xcode。见[Flutter iOS 支持](https://docs.flutter.dev/platform-integration/ios/ios-latest)及[UIScene 迁移](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate)。
3. 本次实际模拟器构建已执行，但 Xcode 报告缺少 iOS 26.5 平台组件（Unable to find a destination）。先在 Xcode → Settings → Components 安装匹配的平台和模拟器组件，再重试并做真机验证；没有生成已验证的 iOS 安装包。
4. Apple 当前上传要求为 Xcode 26 或以上及 iOS 26 等平台 SDK，见[SDK 要求](https://developer.apple.com/news/upcoming-requirements/?id=02032026a)。提交当天再次核对。
5. 在 Xcode 的 Runner target 配置 Team、Signing 和正式 Bundle ID；生产 API 必须是可访问的 HTTPS 地址。
6. 运行 `flutter build ipa --release --dart-define=API_BASE_URL=https://实际域名`，通过 Xcode Organizer/Transporter 上传。此命令必须在产品、签名和服务就绪之后执行；本次未上传。
7. TestFlight 邀请中外各 5–10 个真实养宠家庭，验证加入家庭、重复点完成、权限、删除、时区、断网恢复与升级。
8. 填写中英文商店资料、年龄分级、隐私标签、出口合规问卷、审核说明和可用审核环境，提交人工审核。

支持创建账号的 App 需要提供 App 内账号删除入口；本工程已有设备身份删除流程，但正式身份方案仍需对应实现和验证。见[Apple 账号删除说明](https://developer.apple.com/support/offering-account-deletion-in-your-app/)。审核和数字功能支付要求以[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)为准。

## 仍需用户提供

正式品牌与 Bundle ID、Apple 团队与账号权限、运营主体、首批海外国家/地区、域名与部署服务、隐私/支持联系方式、是否收费及实际价格。不要把证书私钥、数据库密码或 App Store Connect 密钥提交到代码仓库。
