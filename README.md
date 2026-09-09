# 爪伴 PetCare

Flutter + Java 21 / Spring Boot 4.1.1 + MySQL 的宠物照护与家庭协作新工程。

**当前是开发预览版，未发布 App Store。** Flutter 不直连数据库，而是通过带 Bearer 令牌的 Java API 访问 MySQL；数据库密码不进入 App。

## 目录

- `mobile/`：Flutter iOS / Android，中英文，宠物、照护、家庭三个入口。
- `backend/`：Java REST API、Spring Security、JDBC、Flyway 迁移、Maven Wrapper。
- `compose.yaml`：MySQL 8.4 + Java API 本地容器编排。
- `scripts/smoke_test.py`：真实 HTTP / MySQL 测试，包含跨家庭访问拒绝和邀请/删除。
- [模块划分与登录注册](docs/modules-and-auth.md)
- [照护闭环使用说明](docs/care-workflow.md)
- [API 接口说明](docs/api.md)
- [市场依据与产品路线](docs/market.md)
- [App Store 发布准备](docs/app-store.md)
- [验证记录](docs/verification.md)

## 本机已经初始化的独立数据库

当前机器的现有 MySQL 需要密码，所以本次另建了项目专用实例；没有修改已有 MySQL。新实例使用本机已有的 MySQL 9.7.1，端口 `13316`，仅监听 `127.0.0.1`。容器部署目标为 MySQL 8.4，需在 Docker 可用后补跑该版本测试。

`agent01` 数据库及 `agent` 用户属于原 agent 项目。PetCare 使用独立的 `13316` 实例、`petcare` 数据库和 `petcare` 用户，不复用原项目账号或表。数据库工具中建议将此连接命名为 `PetCare 本地 · 13316`。

从 IDE 直接运行时，默认 JDBC 地址也指向 `13316/petcare`；仍需在运行配置中设置 `.local/backend.env` 对应的环境变量，IDE 不会自动加载该文件。Docker 中的 `mysql:3306` 是独立容器内地址。

开发凭据在被忽略的 `.local/backend.env`，管理员配置在 `.local/mysql-admin.cnf`，权限均为 600。不要提交这些文件。

数据库已运行时，从项目根目录启动 API：

```bash
./scripts/run-local-api.sh
```

API 地址为 `http://127.0.0.1:18080`，健康检查 `/api/health` 会执行 MySQL 查询。

若此项目的数据库已停止，可用下列命令在单独终端重启（本机专用）：

```bash
/opt/homebrew/opt/mysql/bin/mysqld --no-defaults \
  --datadir="$PWD/.local/mysql" --socket="$PWD/.local/mysql.sock" \
  --port=13316 --bind-address=127.0.0.1 --mysqlx=OFF \
  --pid-file="$PWD/.local/mysql.pid" --log-error="$PWD/.local/mysql.log"
```

停止该实例：`/opt/homebrew/bin/mysqladmin --defaults-extra-file="$PWD/.local/mysql-admin.cnf" shutdown`。

## 可移植的 Docker 启动方式

```bash
cp .env.example .env
# 编辑 .env，填写两个不同的随机密码，然后：
docker compose up --build -d
```

Docker Desktop / daemon 必须启动。容器方案 API 为 `http://127.0.0.1:8080`，MySQL 不映射宿主机端口。Compose 健康检查验证数据库凭据后再启动 API。

使用自己的 MySQL 时，先创建一个空库和专用账号，通过环境变量 `DB_URL`、`DB_USERNAME`、`DB_PASSWORD` 指定连接，再在 `backend` 中运行 `./mvnw spring-boot:run`。生产环境使用验证证书的 TLS 连接，并分离迁移权限和运行权限。Flyway 首次启动自动建表。

## Flutter 启动

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:18080
```

本机 iOS 构建目前被 Xcode 缺少 iOS 26.5 平台组件阻塞，需先在 Xcode → Settings → Components 补齐，详见验证记录。以上命令用于 iOS 模拟器。Android 模拟器使用 `http://10.0.2.2:18080`。Docker 方案把端口改为 `8080`。

真机需要可访问的开发 HTTPS 地址，或单独配置本地调试网络；真机的 `127.0.0.1` 是手机本身。API 默认仅监听回环，真机连接不能直接照抄模拟器地址。正式构建强制 HTTPS。

首次使用点击“去注册”，填写邮箱、密码和照护称呼，注册后新增宠物与事项。其他家人使用自己的账号注册空家庭后，可通过邀请码加入；同一人换机直接登录原账号。邀请码 24 小时有效，仅可使用一次；重新生成会作废该家庭旧邀请码。

## 当前边界

- 已支持邮箱注册/密码登录、同账号换机登录、30 天会话和当前设备退出。旧设备身份可绑定未注册邮箱保留资料。邮箱验证、忘记密码、Apple 登录、修改密码与远程设备管理尚未实现。
- 一个身份属于一个家庭；同一家庭成员都能管理全部宠物与事项。加入其他家庭前要求当前家庭为空且仅有本人，不会自动转移或丢弃已有记录。
- 已实现每天/每周重复计划、本地通知、完成/撤销历史、成员称呼和前台自动同步。时间按计划时区生成、设备本地时间显示；尚未接入跨设备远程推送与离线操作队列。
- 删除宠物会级联删除事项；删除最后一个家庭成员时清理共享数据，其他情况下保留共享记录。
- 国内与海外可用相同源码连接不同服务；当前没有自动区域路由与跨区同步。
- 尚未实现订阅、正式隐私政策托管、生产部署和 Apple 签名。

## 验证

```bash
cd mobile
flutter analyze
flutter test
cd ../backend
# 本机使用专用测试库；其他环境请配置相应 DB 环境变量。
source ../.local/backend.env
./mvnw test
cd ..
python3 scripts/smoke_test.py
python3 scripts/care_smoke_test.py
python3 scripts/auth_smoke_test.py
```

HTTP 测试默认连接 `18080`，可通过 `API_BASE_URL` 覆盖。测试创建专用匿名身份并在结束时删除，只针对测试身份的资料操作。后端 Spring 上下文测试会运行 Flyway，请连接开发或测试库。

### 邮箱与 Apple 登录

已接入邮箱验证、密码找回与 iOS Apple 基础登录。真实启用需要 SMTP 和 Apple 开发者配置，详见 [配置及验收范围](docs/email-and-apple.md)。iOS 最低版本为 13。
