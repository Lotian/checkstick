# 囍签 · 剧本杀扫码抽签

项目包含玩家 H5、管理后台和共用后端，用于纸艺民俗主题现场抽签活动：
每局人数不再固定，由管理员为每个组局自定义「最低人数 ~ 最高人数」（默认 5~8 人）。

## 目录

- `player-web`：玩家扫码页面
- `admin-web`：工作人员管理后台
- `server`：Java 21 / Spring Boot 后端源码
- `docs`：接口契约、建表 SQL 与设计说明
- `deploy`：服务器部署文件与操作手册（见 `deploy/README.md`）

## 本地开发

后端使用 JDK 21。数据库连接与管理员账号**没有默认值**，必须通过环境变量提供，否则启动会直接失败
（这是刻意设计的：避免误连到别的数据库、或用出厂弱口令对外服务）：

```powershell
$env:JAVA_HOME='F:\softwareWork\java21'
$env:MAVEN_USER_HOME='E:\Develop\maven_repos'
$env:DATABASE_URL='jdbc:postgresql://localhost:5432/xiqian'
$env:DATABASE_USERNAME='xiqian'
$env:DATABASE_PASSWORD='请替换'
$env:ADMIN_USERNAME='admin'
$env:ADMIN_PASSWORD='请替换'
cd server
.\mvnw.cmd spring-boot:run
```

表结构由 Flyway 在首次启动时自动迁移（`V1__init_schema.sql` 建表、`V2__seed_role_templates.sql` 灌入身份模板）。

两个前端分别安装依赖并启动：

```powershell
cd player-web
npm install
npm run dev
```

```powershell
cd admin-web
npm install
npm run dev
```

Vite 开发服务器会将 `/api` 代理到 `http://localhost:8080`。

后端可选环境变量：

| 变量 | 默认值 | 说明 |
|---|---|---|
| `SERVER_PORT` | `8080` | 监听端口 |
| `APP_COOKIE_SECURE` | `false` | HTTPS 部署时必须设为 `true` |
| `PUBLIC_BASE_URL` | 空 | 玩家端地址，决定后台二维码指向；留空表示与后台同源 |

## 管理账号

管理员账号由环境变量 `ADMIN_USERNAME`、`ADMIN_PASSWORD` 提供。项目不会在代码中保存正式密码。

## 部署

服务器部署（腾讯云 Linux + nginx + PostgreSQL）请按 `deploy/README.md` 操作，
其中包含控制台安全组、备案、系统镜像差异、SELinux、发布与回滚的完整步骤。

## 重要说明

- 固定二维码内容是玩家端地址，玩家通过 4 位数字组局码进入对应活动。
- 组局码为 4 位数字（0000~9999 共一万个码位），现场口头传达方便；同一个组局码固定不变。
- 二维码地址由后端 `PUBLIC_BASE_URL` 下发；玩家端与后台分域名部署时必须配置该项。
- `localStorage` 游客标识可被清除，换设备也会被视为新游客。
- 公网 HTTP 无法防止链路窃听，正式使用时应由实际部署环境决定是否增加 HTTPS。
- 任务文本按换行拆分步骤；村民不配置任务。
- 会话与 SSE 都保存在单个 JVM 内存中，只能单实例部署。
