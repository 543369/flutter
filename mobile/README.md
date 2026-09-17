# PetCare Flutter App

本目录包含 iOS / Android 客户端。完整环境说明见[项目 README](../README.md)，新增流程见[照护提醒与重复计划](../docs/care-workflow.md)。

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:18080
```

以上用于 iOS 模拟器；Android 模拟器将主机替换为 `10.0.2.2`，真机需配置可访问的开发服务地址。正式构建要求 HTTPS。

进入“照护”，新增事项时选择每天或每周；打开“到时提醒”授权通知。“已完成”支持撤销，“记录”展示操作者和时间，“重复计划”可停止后续事项。成员称呼在“家庭”中设置。

当前通知为本地通知，其他设备的完成状态需要同步后才能取消本机提醒。iOS 真机送达仍需在补齐 Xcode 平台组件后验收。

## 交互预览

使用 Flutter 3.44.0 / Dart 3.12.0。`tool/design_preview.dart` 使用内存中的演示数据，
展示实际 App 页面，不连接 API，也不保存到账号。首页完成操作可体验；编辑、邀请、导出未接入。
预览首次加载刻意等待 1.8 秒，便于查看 Logo 动效；正式入口没有此延迟。

在 `mobile/` 下构建，再从项目根目录启动静态服务：

```bash
flutter build web --no-wasm-dry-run -t tool/design_preview.dart --base-href /app/
cd ..
mkdir -p .local/preview/app
cp -R mobile/build/web/. .local/preview/app/
cp mobile/tool/preview.html .local/preview/index.html
python3 -m http.server 18765 --bind 127.0.0.1 --directory .local/preview
```

打开 `http://127.0.0.1:18765`，可切换手机/宽屏尺寸及重看加载。
Logo 沿用 Material 爪印；加载、页面和照护内容过渡遵循系统减少动态效果设置。
这不是原生启动屏或真机通知验收。

筛选、分段按钮、开关、菜单、提示条和日期/时间选择器的暖色样式集中在
`lib/app/petcare_app.dart`；保留 Flutter 原生交互与语义。
共享表单使用 `ProfileDialog`，正文可滚动，取消/保存保持可达。

### 间距规则

布局默认值集中在 `lib/core/theme/app_spacing.dart`：紧密文字 4、图标与文字 8、
同组组件 12、内容内边距 16、独立区块与页面侧边 24、宽松空态 32。
主页面使用 `pageInsets`，卡片内容使用 `cardInsets`，表单容器使用 `dialogInsets`。
可点击行的左右内边距通常为 16，上下为 12，不能只留上下间距而使图片贴边。
Card 默认自带 12 的底部间距；接独立区块时只再加 12，避免重复叠加。
头图构图偏移、控件触控尺寸、系统安全区以及悬浮按钮避让不属于间距刻度，按各自用途保留。
列表型卡片的留白应放在 `ListTile.contentPadding` 或 `InkWell` 内部；不要在卡片与可点击行之间添加上下 Padding，否则首尾悬停会留下空白条。纯展示内容卡片不受此规则限制。

### 照护工作流与接口配套

首页按设备本地自然日展示：已到时未完成、今天接下来和今天的照护记录；后续安排进入完整列表。
完成事项使用 PATCH 返回的任务与最近事件就地更新；同一事项提交期间不能重复提交，成功可撤销。
单次改期、跳过、取消与调整后续重复时间分别提供入口；跳过/取消不会记为完成，原记录保留。
健康记录新建成功后可选“设置下次提醒”，预填宠物和事项，日期必须由用户选择未来时间，不推算医疗周期。
通知 payload 定位对应任务并读取最新状态；旧通知没有 payload 时回到照护页。

App 需要配套本次服务端 API 与 V13 图片版本、V14 任务创建时间迁移；本地 Web 预览是内存演示，不代表业务服务已部署。
`GET /dashboard?compact=true` 最多返回 300 个任务、30 条历史；提醒候选独立返回最多 60 个未来事项。
完整任务与历史分别通过 `/tasks?petId=...&cursor=...` 和 `/care-history?petId=...&cursor=...` 游标分页。
照片通过 `/pets/{id}/photos` 独立获取，按 `photoVersion` 在 App 进程内缓存；冷启动仍需读取图片。
写操作包括 `PATCH /tasks/{id}/time`、`POST /tasks/{id}/dismiss`（SKIPPED/CANCELLED）、
`PATCH /plans/{id}/future`；所有写操作沿用家庭 CARE 权限与事务锁。

尚无 APNs/FCM 配置：后台跨设备完成后无法即时撤销本机已排程通知。当前仍依赖前台同步；
不能把本地通知点击定位或前台同步描述为后台推送已完成。真机通知与后台行为需要后续配置和设备验收。

完整安排按不可变创建时间倒序分页，改期和完成不改变分页位置；日期仍显示安排时间。完成响应包含最新提醒候选，自动补入第 61 项。
