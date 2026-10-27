# 本地运行

项目首页为工作台；默认仅保留管理员账号和默认部门。登录表单不再预填账号密码。

后端使用 `Vue-springboot3`，前端使用 `Vue3-master`。

## 访问

- 前端：http://localhost
- 后端：http://localhost:8080
- 默认管理员：`admin` / `admin123`，登录时输入页面验证码。

## 启停

在项目根目录的 PowerShell 中执行：

```powershell
./start-dev.ps1
./stop-dev.ps1
```

修改 Java 代码后重新构建并启动：

```powershell
./stop-dev.ps1
./start-dev.ps1 -Build
```

前端开发服务支持热更新。后端运行的是 Maven 编译后的 JAR。

验证前端模块、接口代理、验证码缓存、登录、菜单、用户列表和退出登录：

```powershell
./verify-dev.ps1
./test/verify-attendance.ps1
./test/verify-rule.ps1
./test/verify-daily-calculator.ps1
./test/verify-auto-settle-unit.ps1
node.exe test/verify-dashboard-ui.mjs
node.exe test/verify-h5-daily.mjs
```

## 本机配置

- MySQL 8.0.37：`127.0.0.1:3306`，数据库 `ry-vue`，已导入系统、Quartz、考勤基础数据、扫码签到、规则及每日结果脚本，并已安装月报和人脸增量，共39张表，其中8张考勤业务表。
- 数据库连接信息放在 `.runtime/application-local.yml`，由启动脚本加载；`.runtime/` 已加入根目录 `.gitignore`。
- 本机 Redis 8.2.1 的 MSYS2 程序启动崩溃，启动脚本使用本机已有的 `D:/redis/Redis-x64-5.0.14.1/redis-server.exe`，监听 `127.0.0.1:6379`。
- 启动脚本创建的 Redis 仅用于本地开发，不保存缓存；停止脚本只停止本项目记录的进程，保留 MySQL 系统服务。
- 日志：`.runtime/logs/`；上传目录：`.runtime/uploads/`；Maven 和 npm 缓存也放在 `.runtime/`。
- 前端端口 `80`，通过 `/dev-api` 代理到后端端口 `8080`。

空库初始化依次使用 `Vue-springboot3/sql/ry_20260417.sql`、`quartz.sql`、`attendance-base.sql`、`attendance-checkin.sql`、`attendance-rule.sql`、`attendance-daily.sql`、`attendance-dashboard.sql`、`attendance-auto-settle.sql`、`attendance-monthly.sql` 和 `attendance-face.sql`。前两份脚本会删除并重建系统或调度表。已有库仅按依赖顺序补执行尚未安装的业务增量：自动日结创建暂停任务，月报只加菜单，人脸新增两表并扩展签到方式。不要重跑系统初始化。旧演示数据可使用 `cleanup-demo.sql` 按原始记录标识清理。

已实现“考勤管理 → 考勤看板 / 办公场所 / 员工档案 / 签到场次与二维码 / 签到记录 / 考勤规则配置 / 每日考勤结果”。先建立部门与账号、场所、员工档案和绑定，再创建场次并展示二维码。详见 [基础数据说明](办公场所与员工档案使用说明.md)、[扫码签到说明](扫码签到使用说明.md)、[规则配置说明](考勤规则配置使用说明.md)、[每日考勤说明](每日考勤使用说明.md)、[考勤看板说明](考勤看板使用说明.md) 和 [自动日结与员工每日考勤](自动日结与员工每日考勤使用说明.md)。自动日结已实现，模板默认暂停，需先配置明确场所ID，再通过现有任务页面启用。

H5 入口为 `/h5/checkin`，登录为 `/h5/login`，原始记录为 `/h5/records`，本人每日结果为 `/h5/daily`，本人月报为 `/h5/monthly`。员工复用 `attendance:checkin:submit`，不需要管理端每日列表权限。真实手机访问时，先停止服务再执行 `./start-dev.ps1 -Lan`，并在二维码窗口填写手机能访问的电脑局域网前端地址。默认 `localhost` 仅适合本机。启用人脸后手机摄像头还需受信任的HTTPS，`-Lan` 不会自动配置HTTPS。

扫码专项验证位于 `test/verify-checkin.ps1`，运行前通过 `ATTENDANCE_TEST_MYSQL_PASSWORD` 环境变量提供本地测试库密码，完整命令见扫码说明。两份考勤专项验证会建立临时测试数据并在结束时清理，限本地开发库使用。

每日计算的真实接口专项为 `test/verify-daily.ps1`，同样需要本地测试库密码环境变量；详情见每日考勤说明。固定时钟测试无需数据库，需先构建后端以编译测试类。

看板专项为 `test/verify-dashboard.ps1`，运行方式见看板说明；仅看板权限不会获得每日明细权限。跨日统计按人次，未生成结果不计缺勤。

自动日结与H5专项为 `test/verify-auto-settle.ps1`，验证真实Quartz触发、部分失败续跑和本人结果隔离，运行前需本地测试库密码环境变量。模板任务和用户真实任务不会被测试启用或更改。

月报管理入口为“考勤管理 → 员工月度汇总”，详见 [月报说明](员工月度出勤与工时汇总使用说明.md)。人脸入口为员工档案中的“人脸档案”，详见 [人脸核验说明](人脸核验签到使用说明.md)。启动脚本可选加载 `.runtime/arcsoft/face-local.yml`，本机已经配置并启用虹软实际核验；SDK、应用密钥和特征加密密钥均留在忽略目录中。

更换机器时需调整启动脚本中的 Redis 路径，并自行填写本地数据库连接信息；如需人脸核验，还须准备对应平台SDK、授权及特征加密密钥。
