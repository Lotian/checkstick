# 囍签 · 部署手册（腾讯云 Linux）

本目录是整套可部署文件。目标形态：**一台 Linux 服务器 + nginx + PostgreSQL + 后端 jar**，
玩家端与管理后台都是纯静态文件，由同一台 nginx 提供服务。

```
https://your-domain.com/           玩家 H5     (player-web/dist)
https://your-domain.com/admin/     管理后台    (admin-web/dist)
https://your-domain.com/api/  ->   Spring Boot 127.0.0.1:8080
                                   PostgreSQL  127.0.0.1:5432
```

## 文件清单

| 文件 | 用途 | 放到哪里 |
|---|---|---|
| `draw.env.example` | 环境变量模板 | → `/etc/xiqian/draw.env`（install 脚本会拷） |
| `xiqian-draw.service` | systemd 单元 | → `/etc/systemd/system/`（install 脚本会装） |
| `nginx-xiqian.conf` | 单域名 nginx 配置（推荐） | → `/etc/nginx/sites-available/xiqian.conf` |
| `nginx-xiqian-split.conf` | 玩家端/后台分域名配置 | 同上（二选一） |
| `build.ps1` | 开发机上打包 → `out/xiqian-<时间戳>.tar.gz` | 留在开发机 |
| `release.ps1` | 开发机上一键上传并发布 | 留在开发机 |
| `server-install.sh` | 服务器首次部署（建目录/装服务/建库） | 上传到服务器执行一次 |
| `server-release.sh` | 服务器发布/升级/回滚 | → `/opt/xiqian/bin/`（install 脚本会拷） |

---

## 零、本机快速通道：轻量应用服务器 + Ubuntu 24.04 + 无备案域名（IP + HTTP）

如果就是这套组合，按下面 8 步照抄即可，不用看后面的通用说明（细节与排错仍在后面章节）。

**控制台**：轻量应用服务器 → 实例 → 「防火墙」→ 确认已放通 `TCP:22` 与 `TCP:80`
（Lighthouse 新建实例通常已默认放通 80/443，核对一下即可）。**不需要**放通 443（没有 HTTPS）。

```bash
# ① 登录（控制台点「登录」，或本机 ssh root@公网IP）
#    轻量应用服务器默认以 root 登录，下面的命令不用加 sudo；若用普通用户请自行加 sudo

# ② 装依赖（Ubuntu 24.04 自带 JDK 21，无需额外源）
apt update && apt install -y openjdk-21-jdk-headless nginx postgresql postgresql-client curl
java -version | head -n1        # 必须是 21.x
timedatectl set-timezone Asia/Shanghai

# ③ 在开发机打包（产出一个文件），再上传到服务器 /root：
#    powershell -ExecutionPolicy Bypass -File deploy\bundle.ps1 -JavaHome 'E:\environment\jdk-21.0.1'
#    上传方式：WinSCP 拖拽 / scp / COS 临时链接，见第 7 步

# ④ 服务器上解开上传包 → 得到 deploy/ 与 release/ 两个目录
cd /root
tar -xzf xiqian-bundle-*.tar.gz
ls deploy release

# ⑤ 【关键，别漏】把 nginx 改成用 IP 访问
#    脚本检测到配置文件里仍是占位域名 your-domain.com 时会跳过 nginx 安装，
#    跳过的话外网看到的就是别的东西（例如机器上原有的 Caddy 默认页）。
sed -i 's/server_name your-domain.com;/server_name _;/' deploy/nginx-xiqian.conf
grep server_name deploy/nginx-xiqian.conf      # 确认已替换，输出里不应再有 your-domain.com

# ⑥ 第一次执行：生成环境变量模板后中止
bash deploy/server-install.sh

# ⑦ 填配置：只要改两个口令；APP_COOKIE_SECURE 保持 false，PUBLIC_BASE_URL 留空
#    若机器上已有 PostgreSQL 与 xiqian 库，DATABASE_* 三项填与该库一致的值即可
vi /etc/xiqian/draw.env

# ⑧ 正式安装 + 建库（会装 nginx 配置、启动 nginx，并确认 80 端口归属）
bash deploy/server-install.sh --init-db

# ⑨ 发布应用
bash deploy/server-release.sh release/xiqian-*.tar.gz
```

> **如果机器上已经有别的 web 服务器占用 80 端口**（例如提前装过 Caddy）：
> `server-install.sh` 会明确提示"nginx 启动失败/80 端口不是 nginx 在监听"。
> 先确认占用者是否只是出厂默认页（`cat /etc/caddy/Caddyfile`，若 root 指向 `/usr/share/caddy` 就是默认页），
> 确认无用后执行 `systemctl disable --now caddy`，再 `systemctl start nginx`。

**不要执行 `certbot`**：纯 IP 无法签发证书。HTTP 下的两点提醒：
- 管理员口令是明文传输 → 用强口令，活动期间才开放 80 端口，活动结束可关闭实例或收窄防火墙。
- 若之后想要 HTTPS，唯一合规路径是先给域名做 ICP 备案（或把实例换到**香港/新加坡**等境外地域，境外地域无需备案）。

---

## 一、腾讯云侧要做的两件事（控制台操作，必须在服务器动工前完成）

### 1. 放通端口（安全组 / 防火墙）

- **云服务器 CVM**：控制台 → 云服务器 → 实例 → 点进实例 → 「安全组」标签 → 编辑规则 → **入站规则**：
  | 来源 | 协议端口 | 策略 |
  |---|---|---|
  | 0.0.0.0/0 | TCP:80 | 允许 |
  | 0.0.0.0/0 | TCP:443 | 允许 |
  | 你的办公/家庭公网 IP/32 | TCP:22 | 允许（建议收紧，不要全开） |

- **轻量应用服务器 Lighthouse**：控制台 → 轻量应用服务器 → 实例 → 「防火墙」→ 添加规则 TCP 80、443。

> **不要**放通 8080 与 5432：后端只监听 127.0.0.1，数据库也只在本机。
> RHEL 系系统（TencentOS / OpenCloudOS / CentOS）本机还有 firewalld，需要额外执行：
> ```bash
> firewall-cmd --permanent --add-service=http --add-service=https && firewall-cmd --reload
> ```

### 2. 域名与备案（决定你能不能上 HTTPS）

| 你的情况 | 能不能 HTTPS | 要做什么 |
|---|---|---|
| 服务器在**中国大陆**地域 + 域名**已备案** | ✅ | 正常走第 3~6 步，用 `nginx-xiqian.conf` + `certbot` |
| 服务器在中国大陆 + 域名**未备案** | ❌ | 80/443 上的域名访问会被阻断。先去腾讯云控制台「备案」完成 ICP 备案，或改用第 8 节的 **IP + HTTP** 方案 |
| 服务器在**香港 / 新加坡 / 硅谷**等境外地域 | ✅ | 不需要备案，直接签证书 |

`certbot` 不能给纯 IP 签证书，所以没有域名就没有 HTTPS。

### 系统镜像差异（安装依赖的命令不一样）

```bash
# ---- Ubuntu 24.04 ----
apt update && apt install -y openjdk-21-jdk-headless nginx postgresql postgresql-client curl

# ---- Ubuntu 22.04（官方源没有 JDK 21，用 Adoptium 源）----
apt update && apt install -y wget apt-transport-https gnupg curl nginx postgresql postgresql-client
mkdir -p /etc/apt/keyrings
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | tee /etc/apt/keyrings/adoptium.asc
echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print $2}' /etc/os-release) main" > /etc/apt/sources.list.d/adoptium.list
apt update && apt install -y temurin-21-jdk

# ---- Debian 12 ----
apt update && apt install -y openjdk-21-jdk-headless nginx postgresql postgresql-client curl
```
```bash
# ---- TencentOS / OpenCloudOS / Rocky / AlmaLinux（RHEL 系，dnf）----
dnf install -y java-21-openjdk-headless nginx postgresql-server postgresql curl policycoreutils-python-utils
postgresql-setup --initdb
systemctl enable --now postgresql nginx
```

> **CentOS 7 已于 2024 年停止维护，不要用**：它的默认软件源里没有 JDK 21，且 SELinux 策略老旧。
> 新购机器建议直接选 **Ubuntu 24.04 LTS**，后面的命令与本文档完全一致。

### RHEL 系必须额外处理 SELinux（否则 nginx 一定 502 / 403）

```bash
# nginx 允许反向代理到 127.0.0.1:8080
setsebool -P httpd_can_network_connect 1
# 允许 nginx 读取 /opt/xiqian 下的静态文件
semanage fcontext -a -t httpd_sys_content_t "/opt/xiqian/current(/.*)?"
restorecon -R /opt/xiqian/current
```
Ubuntu / Debian 自带 AppArmor 对这套部署没有影响，可跳过。

### 时区

`drawnAt` 用的是 JVM 时区，服务器时区不对，后台显示的抽签时间就会差：

```bash
timedatectl set-timezone Asia/Shanghai
timedatectl status
```

---

## 二、首次部署

### 第 1 步：登录服务器

控制台实例页点「登录」（网页终端），或本机直接（Windows 自带 ssh）：

```powershell
ssh root@你的公网IP
```

### 第 2 步：上传部署文件

在开发机（项目根目录）执行：

```powershell
scp -r deploy root@你的公网IP:/root/chouka-deploy
```

### 第 3 步：生成并填写环境变量

```bash
sudo bash /root/chouka-deploy/server-install.sh    # 第一次执行会生成模板后中止
sudo vi /etc/xiqian/draw.env                       # 填数据库口令、管理员口令
```

必须填的项：

| 变量 | 说明 |
|---|---|
| `DATABASE_PASSWORD` | 数据库口令（脚本会用它在 `--init-db` 时建角色，别含单引号） |
| `ADMIN_PASSWORD` | 后台登录口令，请用强口令 |
| `APP_COOKIE_SECURE` | **走 HTTPS 填 `true`；走纯 HTTP 必须填 `false`** |
| `PUBLIC_BASE_URL` | 玩家端地址，见下表 |

`PUBLIC_BASE_URL` 决定后台"玩家扫码处"打印出来的二维码指向哪里：

| 部署形态 | 取值 |
|---|---|
| 单域名：玩家 `https://xxx/`、后台 `https://xxx/admin/` | 留空 |
| 分域名：玩家 `h5.xxx.com`、后台 `admin.xxx.com` | `https://h5.xxx.com/` |
| 没域名，用 IP：`http://1.2.3.4/` | 留空（同源） |
| 本地开发想扫到 5173 | `http://localhost:5173/` |

### 第 4 步：替换 nginx 配置里的域名

**必须在安装前替换**：脚本检测到占位域名 `your-domain.com` 会跳过 nginx 安装（否则同一台机上的其它站点会全落到囍签）。

```bash
cd /root/chouka-deploy
sudo sed -i 's/your-domain.com/你的真实域名/g' nginx-xiqian.conf
grep server_name nginx-xiqian.conf      # 确认已替换，且不含 your-domain.com
```

> 用 IP 访问、没有域名时，把 `server_name your-domain.com;` 改成 `server_name _;`（或你的公网 IP）。

### 第 5 步：建库并装好服务

```bash
sudo bash /root/chouka-deploy/server-install.sh --init-db
```
它会创建运行用户 `xiqian`、目录 `/opt/xiqian/*`、安装 systemd 单元与 nginx 配置、
在本机 PostgreSQL 上创建角色与数据库（表结构由后端启动时 **Flyway 自动迁移**，无需手工执行 SQL）。

> 重复执行是安全的：已存在的 nginx 配置**不会被覆盖**（certbot 追加的 443 配置不会丢），
> 需要强制覆盖时加 `--force-nginx`。

### 第 6 步：签发证书

```bash
sudo apt install -y certbot python3-certbot-nginx        # RHEL 系：dnf install -y certbot python3-certbot-nginx
sudo certbot --nginx -d 你的真实域名
```
certbot 会自动补上 443 的 server 块并把 80 跳转到 https。

> 之后再重跑 `server-install.sh` 不会覆盖它（见第 5 步的说明）。

**只有 IP、没有域名** → 跳过 certbot，并确认 `APP_COOKIE_SECURE=false`，见第 8 节。

### 第 7 步：打包并发布

在**开发机**（项目根目录）执行：

```powershell
# 打包：三个产物 -> deploy\out\xiqian-<时间戳>.tar.gz
powershell -ExecutionPolicy Bypass -File deploy\build.ps1 -JavaHome 'E:\environment\jdk-21.0.1'

# 上传 + 发布（远端自动替换、重启、健康检查，失败自动回滚）
powershell -ExecutionPolicy Bypass -File deploy\release.ps1 -Server root@你的公网IP
```

> `-JavaHome` 必须指向 **JDK 21**；本机 `JAVA_HOME` 若是 17，脚本会直接报错提醒（这是刻意拦截）。
> 若你的 Maven 本地仓库不在默认位置，加 `-MavenRepo '你的仓库路径'`。

手动方式等价于：

```bash
scp deploy\out\xiqian-*.tar.gz root@你的公网IP:/tmp/
ssh root@你的公网IP "sudo /opt/xiqian/bin/server-release.sh /tmp/xiqian-....tar.gz"
```

---

## 三、验收清单（上线前按顺序做一遍）

```bash
systemctl status xiqian-draw                     # active (running)
curl -s http://127.0.0.1:8080/actuator/health     # {"status":"UP",...}
journalctl -u xiqian-draw -n 50 --no-pager        # 确认 Flyway 迁移成功、无连接报错
sudo -u postgres psql -d xiqian -c '\dt'          # 应有 game_groups / game_rounds / draw_slots / role_templates
```

浏览器里：

1. `https://域名/` → 出现"四位数字组局码"输入框。
2. `https://域名/admin/` → 登录页 → 用 `ADMIN_PASSWORD` 登录成功。
3. **新建组局 → 弹出"组局码 1024"（4 位数字）**（这一步验证的就是写接口 + CSRF，是通过与否的关键）。
4. 点「开新轮」→ 手机扫后台二维码进入 → 输入组局码 → 抽签；**后台进度实时跳动**（验证 SSE 穿透 nginx）。
5. 抽签页刷新一次，仍显示同一身份（幂等）。
6. 导出 CSV，用 Excel 打开中文不乱码。
7. 满员后新手机再抽 → 提示"本轮已满员"。
8. **真机各测一台 iOS Safari 与一台安卓微信内置浏览器。**

---

## 四、日常更新与回滚

```powershell
powershell -ExecutionPolicy Bypass -File deploy\build.ps1 -JavaHome 'E:\environment\jdk-21.0.1'
powershell -ExecutionPolicy Bypass -File deploy\release.ps1 -Server root@你的公网IP
```

服务器上的版本布局（`server-release.sh` 自动维护）：

```
/opt/xiqian/releases/20260901-120000/{draw-server.jar,player/,admin/}
/opt/xiqian/current -> releases/20260901-120000      # 原子切换
```

- 健康检查失败会**自动回滚**到上一个版本并重启。
- 默认保留最近 5 个版本，手动回滚：
  ```bash
  sudo ln -sfn /opt/xiqian/releases/<旧时间戳> /opt/xiqian/current.new
  sudo mv -T /opt/xiqian/current.new /opt/xiqian/current
  sudo systemctl restart xiqian-draw
  ```
- 重启后端会**踢掉后台登录**（会话在 JVM 内存里），别在开轮中间重启；玩家端不受影响。
- 只部署单实例：会话与 SSE 都在单进程内存里，**不要做负载均衡或多副本**。

---

## 五、排错对照表

| 现象 | 原因 | 处理 |
|---|---|---|
| 后台登录后立刻又变未登录 | `APP_COOKIE_SECURE=true` 但用 HTTP 访问 | 改成 `false` 后 `systemctl restart xiqian-draw` |
| 后台写操作提示"安全校验未通过" | 前端是修复 CSRF 之前的旧构建产物 | 重新 `build.ps1` + `release.ps1` |
| 后台进度不实时刷新 | nginx 未对该 location 关闭缓冲 | 确认用的是本目录的 nginx 配置（`proxy_buffering off`），`nginx -t && systemctl reload nginx` |
| 二维码指向后台域名 | 未设 `PUBLIC_BASE_URL` | 设置后重启后端，并在后台刷新页面重新取配置 |
| 502 Bad Gateway | 后端没起来 / 端口不对 | `systemctl status xiqian-draw`、`journalctl -u xiqian-draw -n 100`；RHEL 系检查 SELinux `setsebool -P httpd_can_network_connect 1` |
| 服务启动即退出 | 缺环境变量、数据库连不上、JDK 版本不对 | 看 `journalctl`：缺变量会明确提示"必须配置 ADMIN_USERNAME 与 ADMIN_PASSWORD" |
| 玩家端打开 404 / 白屏 | 静态文件没铺开或 `try_files` 缺失 | `ls -l /opt/xiqian/current/player/index.html`，检查 nginx 配置的 root |
| 抽签提示"本组还没有开始新的轮次" | 后台尚未开轮 | 在后台点"开新轮" |
| 导出 CSV 中文乱码 | 用记事本直接打开 | 用 Excel，或确认文件带 UTF-8 BOM（后端已处理） |
| 健康检查超时 + 日志出现 `Schema validation: missing column [...]` | 数据库结构与新版本不一致：**迁移没被执行**。老库是手工 SQL 建的，没有 `flyway_schema_history`；且 Spring Boot 4 把 Flyway 自动配置拆到了独立模块，只引 `flyway-core` 时 `spring.flyway.*` 完全无效 | ① 手工执行 `docs/manual-v3-migration.sql`（幂等，可重复跑）；② 发布新版本。代码侧已补 `spring-boot-starter-flyway` 并设 `baseline-on-migrate`，后续构建会自动迁移 |

---

## 六、数据备份（现场活动务必做）

```bash
# 手动备份
sudo -u postgres pg_dump -Fc xiqian > /root/backup-xiqian-$(date +%F-%H%M).dump

# 每天 3 点自动备份，保留 30 天
sudo crontab -e
0 3 * * * sudo -u postgres pg_dump -Fc xiqian > /root/xiqian-$(date +\%F).dump && find /root -name 'xiqian-*.dump' -mtime +30 -delete
```

组局没有物理删除接口，历史轮次就是兑奖凭据，建议活动前先备份一次。

---

## 七、分域名部署（可选）

只想把玩家端和后台分到两个域名时：

1. nginx 用 `nginx-xiqian-split.conf`，两个域名都各自反代 `/api`（前端用的是相对路径，**不需要后端开 CORS**）。
2. `/etc/xiqian/draw.env` 里设置 `PUBLIC_BASE_URL=https://h5.你的域名/`，否则二维码会指错。
3. 后台地址是 `https://admin.你的域名/admin/`（前端构建产物写死了 `/admin/` 前缀）。
4. 两个域名都要各自签证书：`certbot --nginx -d h5.你的域名 -d admin.你的域名`。

---

## 八、只有 IP、走 HTTP 的部署（无域名/未备案时）

1. `/etc/xiqian/draw.env`：
   ```
   APP_COOKIE_SECURE=false
   PUBLIC_BASE_URL=
   ```
2. nginx 用 `nginx-xiqian.conf`，把 `server_name your-domain.com;` 改成你的公网 IP，跳过 certbot。
3. 玩家端二维码会是 `http://你的IP/`（后端下发为空时前端回退到同源）。
4. 玩家端在 HTTP 下也能用：`crypto.randomUUID` 不可用，但前端有 `getRandomValues` 兜底实现。
5. **风险**：管理员口令是明文传输。仅建议在活动现场内网或临时演示时使用；一旦有公网域名，优先切到 HTTPS。

---

## 九、附录：直接在服务器上编译（不用开发机打包）

不想在 Windows 上打包时，可以整包上传源码后在服务器上编译。
需要额外装 Node.js（构建两个前端用）：

```bash
# Ubuntu / Debian
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# RHEL 系
dnf module install -y nodejs:20
```

> 构建前端约需 1GB 内存，2GB 内存以下的机器建议先加 2GB swap，否则 `vite build` 可能被 OOM Kill。

在**开发机**上传源码（排除依赖与产物，体积小很多）：

```powershell
# 用 scp：先把源目录打成压缩包更快
tar -czf chouka-src.tar.gz --exclude=node_modules --exclude=dist --exclude=target chouka
scp chouka-src.tar.gz root@你的公网IP:/root/
```
```bash
# 服务器上
cd /root && tar -xzf chouka-src.tar.gz && cd chouka
```

编译并组装发布包（结构与 `build.ps1` 完全一致）：

```bash
# 前端
(cd player-web && npm ci && npm run build)
(cd admin-web  && npm ci && npm run build)

# 后端（mvnw 会自动从阿里云下载 Maven，首次约几分钟）
export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
(cd server && ./mvnw -DskipTests clean package)

# 组装
stage=/tmp/xiqian-stage
rm -rf "$stage" && mkdir -p "$stage/player" "$stage/admin"
cp "$(ls -1 server/target/draw-server-*.jar | grep -v '\.original$' | head -n1)" "$stage/draw-server.jar"
cp -r player-web/dist/. "$stage/player/"
cp -r admin-web/dist/.  "$stage/admin/"
tar -czf "/tmp/xiqian-$(date +%Y%m%d-%H%M%S).tar.gz" -C "$stage" draw-server.jar player admin

# 发布
sudo /opt/xiqian/bin/server-release.sh /tmp/xiqian-*.tar.gz
```

> 首次编译会下载 Maven 与全部依赖（约 100~200MB）。后续增量编译很快。
> 如果服务器访问 Maven 中央仓库较慢，可以在 `~/.m2/settings.xml` 里配置阿里云镜像。
