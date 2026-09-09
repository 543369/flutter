# PetCare Flutter App

本目录包含 iOS / Android 客户端。完整环境说明见[项目 README](../README.md)，新增流程见[照护提醒与重复计划](../docs/care-workflow.md)。

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:18080
```

以上用于 iOS 模拟器；Android 模拟器将主机替换为 `10.0.2.2`，真机需配置可访问的开发服务地址。正式构建要求 HTTPS。

进入“照护”，新增事项时选择每天或每周；打开“到时提醒”授权通知。“已完成”支持撤销，“记录”展示操作者和时间，“重复计划”可停止后续事项。成员称呼在“家庭”中设置。

当前通知为本地通知，其他设备的完成状态需要同步后才能取消本机提醒。iOS 真机送达仍需在补齐 Xcode 平台组件后验收。
