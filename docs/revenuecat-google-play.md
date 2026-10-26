# RevenueCat + Google Play 配置

代码已接入，真实支付尚未开通。以下 ID 均须使用自己的控制台配置，示例不是已创建的商品。

## 1. 先创建商店应用和订阅

在 Google Play Console 完成开发者与收款资料配置，确定正式 Android applicationId、上传签名及 Play App Signing。当前 `mobile/android/app/build.gradle` 仍是 `com.example.petcare` 和 debug 签名，正式发布前必须替换。

创建自动续费的月／年订阅及基础方案，设置价格、地区并激活。初版只接普通自动续费订阅；不要配置一次性、终身、分期、预付或复杂优惠，尚未覆盖这些展示和权益逻辑。价格与币种从 Google Play 读取，不写死在客户端。

家庭会员目标价为 US$3.99／月、US$29.99／年（美元基准），按家庭共享权益。商品创建时按此配置美元价格，并核对其他销售地区的当地价格；完整定价见[家庭会员定价](payment-launch.md#家庭会员定价)。该目标尚未同步到商店。

## 2. 创建 RevenueCat 项目

1. 创建项目，添加 Google Play 应用，填入与 APK／AAB 相同的包名。
2. 按 [Google Play 服务凭据文档](https://www.revenuecat.com/docs/service-credentials/creating-play-service-credentials) 配置权限，将服务账号凭据交给 RevenueCat 控制台。不要提交到源码或发送到聊天。
3. 导入实际 Play 商品。创建 entitlement（默认配置 `family_plus`），关联这些商品；创建 offering（默认 `default`），添加对应月／年 package。
4. 记录 RevenueCat 的 App ID、entitlement ID、offering ID 和实际 product identifier。新版 Play 商品标识可能含 `:base-plan-id`；服务端白名单必须与 SDK 及 API 返回值完全一致，不要仅凭显示名称猜测。
5. 购买恢复策略选择 **Keep with original App User ID**，与本项目固定购买账号的规则保持一致。初始配置 SDK 时使用后端 UUID，不使用邮箱或匿名 RevenueCat 身份。参见 [恢复购买文档](https://www.revenuecat.com/docs/getting-started/restoring-purchases)。
6. 按 RevenueCat 的 Google 应用配置向导连接 Google 实时开发者通知，并验证服务凭据和通知状态。

## 3. 后端配置

将配置注入部署环境；Compose 已映射这些变量。真实密钥不要写进 `.env.example` 或版本控制。

| 变量 | 用途 |
| --- | --- |
| `REVENUECAT_ENABLED` | 默认 `false`；配置完成后才设为 `true` |
| `REVENUECAT_SANDBOX` | 生产 `false`，独立测试环境 `true` |
| `REVENUECAT_SECRET_API_KEY` | 支持 RevenueCat API v1 客户查询的服务端 secret key，仅后端保存 |
| `REVENUECAT_WEBHOOK_AUTHORIZATION` | 自行生成的长随机认证值，完整值至少 32 字符，和控制台 Authorization 设置一致 |
| `REVENUECAT_APP_ID` | RevenueCat 应用 ID，不是 Android 包名 |
| `REVENUECAT_ENTITLEMENT_ID` | 默认 `family_plus` |
| `REVENUECAT_OFFERING_ID` | 默认 `default` |
| `REVENUECAT_PRODUCTS` | 允许的实际商品标识，逗号分隔，无通配符 |
| `REVENUECAT_STORAGE_BYTES` | 默认 `1073741824`，即家庭总空间 1 GiB |
| `PETCARE_BENEFITS_PREVIEW` | 启用支付时必须 `false` |

Flyway 自动执行 V17。保留迁移历史，不要为通过验证而修改旧迁移或对生产库随意执行 repair。

在 RevenueCat 添加 Webhook：`https://你的API域名/api/billing/revenuecat/webhook`，设置上述完整 Authorization 值，选择对应应用、环境与所有相关订阅事件。后端校验 App ID，再查询 RevenueCat 最新状态，不直接采用通知中的到期时间。配置参考：[Webhooks](https://www.revenuecat.com/docs/integrations/webhooks)。

测试与生产使用独立数据库、配置和 RevenueCat 项目／应用，测试账号不要连接生产 API。不要通过反复切换生产库的 sandbox 开关做测试。

## 4. Flutter 构建

安装依赖后，以正式包名和发布签名生成 Play AAB。示例命令中的地址和 key 必须替换：

```sh
flutter build appbundle --release \
  --dart-define=DISTRIBUTION_CHANNEL=google_play \
  --dart-define=REVENUECAT_GOOGLE_API_KEY=goog_你的公共SDKKey \
  --dart-define=API_BASE_URL=https://你的API域名
```

`API_BASE_URL` 是域名根地址，客户端自行附加 `/api`。`goog_` 开头的是 Google 公共 SDK key，可以包含在应用中；secret API key 和服务账号 JSON 绝不能打包进客户端。SDK 接入参考：[Flutter 安装](https://www.revenuecat.com/docs/getting-started/installation/flutter)。

当前使用自定义购买页，不使用 RevenueCat Paywalls。保留 Android Activity 的 `singleTop` 启动模式。普通官网 APK 未传上述支付参数时不显示购买入口。

## 5. 当前权益规则及运行限制

- 注册账号首次打开购买页时绑定当前家庭；只允许管理员建立关系和新购买。之后切换家庭不转移权益，原购买者在有账号访问权限时仍可恢复；取消订阅可直接在 Google Play 操作。
- SDK 成功后必须经过 `/sync` 的服务端核验才确认权益。未确认时提示刷新／恢复，避免重复购买。
- 退款、到期以及生产／测试环境不符不会授权；有效宽限期保留权益。取消自动续费通常保留已付期限。
- 每分钟最多补查 50 个客户，优先查询超过 10 分钟未检查的记录；查证超过 1 小时的缓存停止提供付费权益。RevenueCat 长时间故障可能暂时影响付费访问，需要监控补查延迟、错误率并按用户规模扩容。
- 映射表保存购买身份与权益缓存，不是完整财务订单账本。交易记录、退款与对账在 Google Play／RevenueCat 管理。
- 删除账号或家庭不会删除购买映射，也不会取消 Google Play 订阅；重新注册不自动继承已删除账号的购买。正式发布前需落实告知、客服核验、数据保留和删除流程。
- 现有手工 `household_benefits` 授权仍然有效，关闭 preview 不会撤销这些独立授权。

## 6. 发布验收

本地单元／数据库测试不能替代商店联调。将正式签名构建上传 Play 测试轨道，添加许可测试账号，通过 Play 安装后验证：

- 月／年商品、价格、周期和自动续费说明一致。
- 购买成功、用户取消、延迟付款、断网后恢复；失败不发权益。
- 同账号重装恢复，切换账号不会串权益，游客不能购买。
- 重复／乱序通知、退款撤权、到期、宽限期、通知遗漏后定时补查。
- 切换家庭、角色变化和家庭删除符合固定归属规则。
- 测试订单不能发放生产权益，生产开关和密钥完整且 preview 关闭。
- 生产真机付款、到账、续费状态与退款链路通过后，再确认收费上线。
