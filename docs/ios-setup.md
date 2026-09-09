# 安装 iOS 平台组件

本机检查：Xcode 26.6（17F113），路径 `/Applications/Xcode.app/Contents/Developer`；iOS / Simulator 26.5 SDK 已存在，安装前只有 iOS 18.1 Simulator Runtime。首次启动组件检查已通过。

## 安装

Xcode → Settings → Components，选择 iOS 26.5 的模拟器运行时，点击安装。也可以使用本机已验证支持的命令：

```bash
xcodebuild -downloadPlatform iOS -buildVersion 26.5 -architectureVariant arm64
```

本机 Apple silicon 使用 arm64 变体，本次显示包大小约 8.52 GB，安装需要额外空间。安装前磁盘剩余约 262 GiB。

## 安装后检查

```bash
xcrun simctl list runtimes
xcodebuild -workspace mobile/ios/Runner.xcworkspace -scheme Runner -showdestinations
```

然后在 `mobile/` 执行：

```bash
flutter build ios --simulator --debug --dart-define=API_BASE_URL=http://127.0.0.1:18080
```

运行时安装成功不等于 Flutter 与 Xcode 完整兼容。本机 Flutter 3.27.1 较旧，若下一步出现编译/运行错误，应按具体错误处理，或使用项目独立 Flutter 版本升级。

## 真机通知验收

模拟器运行时只解决模拟器运行环境；真机锁屏通知还需要可用的 iPhone、签名配置、设备开发者模式及通知授权，且真机要能访问配置的 API。真机不能使用 `127.0.0.1` 访问 Mac 上的后端。

来源：[Apple：下载和安装其他 Xcode 组件](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components)。
