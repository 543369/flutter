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
