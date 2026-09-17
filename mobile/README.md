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
