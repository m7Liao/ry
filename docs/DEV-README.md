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
./verify-attendance.ps1
```

## 本机配置

- MySQL 8.0.37：`127.0.0.1:3306`，数据库 `ry-vue`，已导入系统、Quartz 及考勤基础数据脚本，共 33 张表。
- 数据库连接信息放在 `.runtime/application-local.yml`，由启动脚本加载；`.runtime/` 已加入根目录 `.gitignore`。
- 本机 Redis 8.2.1 的 MSYS2 程序启动崩溃，启动脚本使用本机已有的 `D:/redis/Redis-x64-5.0.14.1/redis-server.exe`，监听 `127.0.0.1:6379`。
- 启动脚本创建的 Redis 仅用于本地开发，不保存缓存；停止脚本只停止本项目记录的进程，保留 MySQL 系统服务。
- 日志：`.runtime/logs/`；上传目录：`.runtime/uploads/`；Maven 和 npm 缓存也放在 `.runtime/`。
- 前端端口 `80`，通过 `/dev-api` 代理到后端端口 `8080`。

空库初始化依次使用 `Vue-springboot3/sql/ry_20260417.sql`、`quartz.sql` 和 `attendance-base.sql`。前两份脚本会删除并重建系统表，已有库升级本次功能仅执行 `attendance-base.sql`。旧演示数据可使用 `cleanup-demo.sql` 按原始记录标识清理。

已实现“考勤管理 → 办公场所 / 员工档案”，操作顺序为建立部门与账号、登记场所、创建档案并绑定。详见 [办公场所与员工档案使用说明](办公场所与员工档案使用说明.md)。专项验证会建立临时测试数据并在结束时清理，限本地开发库使用。

更换机器时需调整启动脚本中的 Redis 路径，并自行填写本地数据库连接信息。
