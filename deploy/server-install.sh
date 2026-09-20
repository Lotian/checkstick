#!/usr/bin/env bash
# 囍签 · 首次部署（在服务器上执行）
#
# 用法：
#   sudo deploy/server-install.sh              # 第 1 次：生成环境变量模板后中止（需你填写）
#   sudo deploy/server-install.sh              # 第 2 次：装目录/服务/nginx 配置
#   sudo deploy/server-install.sh --init-db    # 追加：在本机 PostgreSQL 上建角色与数据库
#
# 本脚本不安装系统软件包。JDK 21、nginx、PostgreSQL 请先按 deploy/README.md 手动安装。
#
# 它做这些事（可重复执行；已存在的配置不会被无条件覆盖）：
#   1. 创建运行用户 xiqian 与目录 /opt/xiqian/{releases,bin}
#   2. 放置 /etc/xiqian/draw.env（不存在时从示例复制并中止，等你填写）
#   3. 安装 /opt/xiqian/bin/server-release.sh 与 systemd 单元
#   4. 安装 nginx 站点配置（仅在域名已替换时安装，并自动备份旧文件）
#   5. （--init-db）在本机 PostgreSQL 上创建角色与数据库
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="${APP_ROOT:-/opt/xiqian}"
RUN_USER="${RUN_USER:-xiqian}"
SERVICE="${SERVICE:-xiqian-draw}"
ENV_FILE="${ENV_FILE:-/etc/xiqian/draw.env}"
NGINX_SITE="${NGINX_SITE:-/etc/nginx/sites-available/xiqian.conf}"

log()  { printf '\033[36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[32m    %s\033[0m\n' "$*"; }
warn() { printf '\033[33m!!  %s\033[0m\n' "$*"; }
fail() { printf '\033[31m!!  %s\033[0m\n' "$*" >&2; }

if [ "$(id -u)" -ne 0 ]; then
  fail "请用 root 或 sudo 执行"
  exit 1
fi

INIT_DB=0
FORCE_NGINX=0
for arg in "$@"; do
  case "$arg" in
    --init-db) INIT_DB=1 ;;
    --force-nginx) FORCE_NGINX=1 ;;
    *) fail "未知参数: $arg"; exit 1 ;;
  esac
done

for bin in install systemctl nginx java; do
  command -v "$bin" >/dev/null 2>&1 || { fail "缺少命令: $bin（请先按 deploy/README.md 安装）"; exit 1; }
done

# 读取 java 主版本；解析失败必须报错退出，不能静默放过。
# 注意：设置了 JAVA_TOOL_OPTIONS/_JAVA_OPTIONS 时 JVM 会往 stderr 打 "Picked up ..."，
# 那行会排在版本行之前，所以这里定位"含 version \"数字"的那一行，而不是取第 1 行。
JAVA_ALL="$(java -version 2>&1)"
JAVA_VER_LINE="$(printf '%s\n' "$JAVA_ALL" | grep -m1 -E 'version "[0-9]' || true)"
JAVA_MAJOR="$(printf '%s\n' "$JAVA_VER_LINE" | sed -nE 's/.*version "([0-9]+).*/\1/p')"
case "$JAVA_MAJOR" in
  ''|*[!0-9]*)
    fail "无法解析 java 版本（java -version 输出：$JAVA_ALL），本项目要求 JDK 21"
    exit 1
    ;;
esac
if [ "$JAVA_MAJOR" -lt 21 ]; then
  fail "当前 java 主版本为 $JAVA_MAJOR，本项目要求 JDK 21"
  exit 1
fi
ok "java 版本: $JAVA_VER_LINE"

# ---------------------------------------------------------------- 用户与目录
log "创建运行用户与目录"
if id -u "$RUN_USER" >/dev/null 2>&1; then
  ok "用户 $RUN_USER 已存在"
else
  useradd --system --create-home --home-dir "$APP_ROOT" --shell /usr/sbin/nologin "$RUN_USER"
  ok "已创建系统用户 $RUN_USER"
fi
install -d -m 755 -o "$RUN_USER" -g "$RUN_USER" "$APP_ROOT/releases"
install -d -m 755 -o root -g root "$APP_ROOT/bin" /etc/xiqian
chmod 755 "$APP_ROOT"
ok "$APP_ROOT/releases、$APP_ROOT/bin、/etc/xiqian 就绪"

# ---------------------------------------------------------------- 环境变量文件
log "检查环境变量文件 $ENV_FILE"
if [ ! -f "$ENV_FILE" ]; then
  install -m 600 -o root -g root "$SCRIPT_DIR/draw.env.example" "$ENV_FILE"
  warn "这是第 1 次执行：已生成 $ENV_FILE 模板"
  warn "请填写数据库口令、管理员口令等（不要给值加引号），然后重新执行本脚本"
  fail "未填写配置，本次安装中止"
  exit 1
fi

if grep -q '在这里填' "$ENV_FILE"; then
  fail "$ENV_FILE 里还有未填写的占位内容（搜索「在这里填」），请填完再执行"
  exit 1
fi
chmod 600 "$ENV_FILE"

# 与 systemd 的 EnvironmentFile 解析保持一致：去掉回车、两侧空白与引号
get_env() {
  sed -n "s/^$1=//p" "$ENV_FILE" | tail -n1 | tr -d '\r' \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
          -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
}

for key in DATABASE_URL DATABASE_USERNAME DATABASE_PASSWORD ADMIN_USERNAME ADMIN_PASSWORD; do
  value="$(get_env "$key" || true)"
  if [ -z "$value" ]; then
    fail "$ENV_FILE 缺少必填项 $key"
    exit 1
  fi
done
ok "必填项检查通过"

PUBLIC_BASE_URL_VALUE="$(get_env PUBLIC_BASE_URL || true)"
APP_COOKIE_SECURE_VALUE="$(get_env APP_COOKIE_SECURE || true)"
if [ -z "$PUBLIC_BASE_URL_VALUE" ]; then
  ok "PUBLIC_BASE_URL 为空：按「玩家端与后台同源」生成二维码"
else
  ok "PUBLIC_BASE_URL=$PUBLIC_BASE_URL_VALUE"
fi
if [ "$APP_COOKIE_SECURE_VALUE" = "true" ]; then
  warn "APP_COOKIE_SECURE=true：请确认确实是通过 HTTPS 访问，否则后台将无法登录"
fi

# ---------------------------------------------------------------- 部署脚本与 systemd
log "安装发布脚本与 systemd 单元"
install -m 755 -o root -g root "$SCRIPT_DIR/server-release.sh" "$APP_ROOT/bin/server-release.sh"
ok "$APP_ROOT/bin/server-release.sh"

# 手册不是必需品：找不到就跳过，绝不能因为缺一个文档而中断整个安装
README_SRC=""
for candidate in "$SCRIPT_DIR/README.md" "$SCRIPT_DIR/../README.md"; do
  if [ -f "$candidate" ]; then
    README_SRC="$candidate"
    break
  fi
done
if [ -n "$README_SRC" ]; then
  install -m 644 -o root -g root "$README_SRC" "$APP_ROOT/README.md"
  ok "$APP_ROOT/README.md"
else
  warn "找不到 README.md，跳过文档安装（不影响运行）"
fi

install -m 644 -o root -g root "$SCRIPT_DIR/xiqian-draw.service" "/etc/systemd/system/$SERVICE.service"
systemctl daemon-reload
systemctl enable "$SERVICE" >/dev/null
ok "systemd 单元已启用（单元带 ConditionPathExists，发布包铺开前不会反复重启）"

# ---------------------------------------------------------------- nginx
log "安装 nginx 站点配置"
NGX_SRC="$SCRIPT_DIR/nginx-xiqian.conf"

# 先确定目标文件位置，后面"已存在则不覆盖"的判断才可靠
# （只在沿用默认路径时自动切换到 conf.d 布局；用户显式指定 NGINX_SITE 时不改写）
if [ "$NGINX_SITE" = "/etc/nginx/sites-available/xiqian.conf" ] \
   && [ ! -d /etc/nginx/sites-available ] && [ -d /etc/nginx/conf.d ]; then
  NGINX_SITE=/etc/nginx/conf.d/xiqian.conf
fi

if [ ! -f "$NGX_SRC" ]; then
  warn "找不到 $NGX_SRC，跳过 nginx 配置"
elif grep -qE '^[[:space:]]*server_name[[:space:]]+your-domain\.com' "$NGX_SRC"; then
  # 只检查真正的 server_name 指令：配置文件顶部的注释里也写着 your-domain.com，
  # 早先按整文件 grep 会导致"无论怎么改都判定为占位域名、永远跳过安装"。
  # 占位域名下不安装：否则同一台机上的其它站点会全部落到囍签
  warn "$NGX_SRC 的 server_name 仍是占位域名，已跳过安装与 reload"
  warn "请先替换域名再重新执行本脚本（二选一）："
  warn "    有域名：sed -i 's/^\([[:space:]]*server_name[[:space:]]*\)your-domain.com;/\1你的域名;/' $NGX_SRC"
  warn "    用 IP ：sed -i 's/^\([[:space:]]*server_name[[:space:]]*\)your-domain.com;/\1_;/' $NGX_SRC"
elif [ -f "$NGINX_SITE" ] && [ "$FORCE_NGINX" -eq 0 ]; then
  # 已装过就不再覆盖：certbot 会把 443 配置写进该文件，覆盖会直接让 HTTPS 下线
  ok "$NGINX_SITE 已存在，跳过覆盖（需要强制覆盖请加 --force-nginx）"
else
  if [ -f "$NGINX_SITE" ] && ! cmp -s "$NGX_SRC" "$NGINX_SITE"; then
    backup="$NGINX_SITE.bak.$(date +%Y%m%d-%H%M%S)"
    cp -a "$NGINX_SITE" "$backup"
    warn "已备份原配置到 $backup（若其中含 certbot 追加的 443 配置，需自行合并回来）"
  fi
  install -m 644 -o root -g root "$NGX_SRC" "$NGINX_SITE"
  ok "$NGINX_SITE"

  if [ -d /etc/nginx/sites-enabled ]; then
    ln -sfn "$NGINX_SITE" /etc/nginx/sites-enabled/xiqian.conf
    if [ -e /etc/nginx/sites-enabled/default ]; then
      # 必须移出 sites-enabled：nginx 的 include 是 sites-enabled/*，
      # 改名成 default.disabled-by-xiqian 仍会被 include，它的 listen 80 default_server
      # 会让"用 IP 访问"直接落到 nginx 欢迎页。
      if [ -d /etc/nginx/sites-available ]; then
        mv -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default.disabled-by-xiqian
        ok "已停用默认站点（移到 sites-available/default.disabled-by-xiqian，可随时移回）"
      else
        # 没有 sites-available 的布局下也不要直接删除用户文件，移到 /etc/nginx 留档
        mv -f /etc/nginx/sites-enabled/default /etc/nginx/default.disabled-by-xiqian
        ok "已停用默认站点（移到 /etc/nginx/default.disabled-by-xiqian）"
      fi
    fi
  elif [ "$NGINX_SITE" != "/etc/nginx/conf.d/xiqian.conf" ]; then
    warn "未找到 /etc/nginx/sites-enabled，配置可能不会被 include，请手工确认"
  fi

  if nginx -t >/dev/null 2>&1; then
    if systemctl is-active --quiet nginx; then
      if systemctl reload nginx; then
        ok "nginx 配置校验通过并已 reload"
      else
        warn "nginx reload 失败，请手工检查：systemctl status nginx"
      fi
    else
      # 没在运行时必须尝试启动，并把"谁占着 80"直接打出来（否则站点静默不可用）
      if systemctl start nginx; then
        ok "nginx 已启动"
      else
        fail "nginx 启动失败，通常是 80 端口已被其它服务占用"
        warn "当前 80 端口占用情况："
        (ss -tlnp 2>/dev/null | grep -E ':80[[:space:]]' || true) >&2
        warn "请先停用占用者（例如 systemctl disable --now caddy），再执行：systemctl start nginx"
      fi
    fi

    if ss -tlnp 2>/dev/null | grep -qE ':80[[:space:]].*nginx'; then
      ok "80 端口确认由 nginx 监听"
    else
      warn "80 端口当前不是 nginx 在监听，站点可能无法访问，实际占用情况："
      (ss -tlnp 2>/dev/null | grep -E ':80[[:space:]]' || true) >&2
    fi
  else
    warn "nginx -t 校验失败，未执行 reload："
    nginx -t || true
  fi
fi

# ---------------------------------------------------------------- 数据库
if [ "$INIT_DB" -eq 1 ]; then
  log "在本机 PostgreSQL 上初始化数据库"

  if ! command -v psql >/dev/null 2>&1; then
    fail "找不到 psql（postgresql-client），跳过建库"
    exit 1
  fi

  DB_URL_VALUE="$(get_env DATABASE_URL)"
  DB_USER_VALUE="$(get_env DATABASE_USERNAME)"
  DB_PASS_VALUE="$(get_env DATABASE_PASSWORD)"

  case "$DB_URL_VALUE" in
    jdbc:postgresql://*/*) ;;
    *)
      fail "DATABASE_URL 格式应为 jdbc:postgresql://host[:port]/dbname[?params]（当前：$DB_URL_VALUE）"
      exit 1
      ;;
  esac

  rest="${DB_URL_VALUE#jdbc:postgresql://}"
  hostport="${rest%%/*}"
  dbname="${rest#*/}"
  dbname="${dbname%%\?*}"
  dbhost="${hostport%%:*}"
  dbport="${hostport##*:}"
  [ "$dbport" = "$dbhost" ] && dbport=5432

  for name in "$DB_USER_VALUE" "$dbname"; do
    if ! printf '%s' "$name" | grep -Eq '^[a-z_][a-z0-9_]*$'; then
      fail "库名/用户名只支持小写字母数字下划线（当前：$name），请修改 $ENV_FILE 后重试"
      exit 1
    fi
  done
  # 单引号会破坏 SQL 字面量；$$ 会提前终结 DO 块的 dollar-quoting
  if printf '%s' "$DB_PASS_VALUE" | grep -qF -e "'" -e '$$'; then
    fail "数据库口令不要包含单引号或两个连续的美元符号，请修改 $ENV_FILE 后重试"
    exit 1
  fi

  # 空主机名 = 本机 Unix socket 写法（jdbc:postgresql:///xiqian），同样按本机处理
  if [ -n "$dbhost" ] && [ "$dbhost" != "127.0.0.1" ] && [ "$dbhost" != "localhost" ]; then
    warn "DATABASE_URL 指向的是 $dbhost，不是本机；请在该数据库服务器上手工建库建角色："
    warn "    CREATE ROLE $DB_USER_VALUE LOGIN PASSWORD '<口令>';"
    warn "    CREATE DATABASE $dbname OWNER $DB_USER_VALUE ENCODING 'UTF8';"
  else
    ok "目标集群: ${dbhost:-localhost(unix socket)}:${dbport}  库=$dbname  角色=$DB_USER_VALUE"

    # 临时 SQL 文件集中放在私有目录，退出时整体清理（含口令，不能残留）
    TMPD="$(mktemp -d)"
    trap 'rm -rf "$TMPD"' EXIT

    # 通过 stdin 喂给 psql：重定向由 root 完成，postgres 用户不需要读该文件
    psql_as_postgres() {
      local file="$1" tuple="${2:-}" port="$dbport"
      local args=(-p "$port" -v ON_ERROR_STOP=1)
      [ "$tuple" = "tuple" ] && args=(-p "$port" -t -A -v ON_ERROR_STOP=1)
      if [ "$(id -un)" = "postgres" ]; then
        psql "${args[@]}" < "$file"
      elif command -v sudo >/dev/null 2>&1; then
        sudo -u postgres psql "${args[@]}" < "$file"
      else
        su - postgres -s /bin/bash -c "psql $(printf '%q ' "${args[@]}")" < "$file"
      fi
    }

    ROLE_SQL="$TMPD/role.sql"
    cat > "$ROLE_SQL" <<SQL
DO \$\$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER_VALUE') THEN
    ALTER ROLE "$DB_USER_VALUE" WITH LOGIN PASSWORD '$DB_PASS_VALUE';
  ELSE
    CREATE ROLE "$DB_USER_VALUE" WITH LOGIN PASSWORD '$DB_PASS_VALUE';
  END IF;
END
\$\$;
SQL
    psql_as_postgres "$ROLE_SQL"
    ok "角色 $DB_USER_VALUE 已就绪"

    CHECK_SQL="$TMPD/check.sql"
    printf "SELECT 1 FROM pg_database WHERE datname = '%s';\n" "$dbname" > "$CHECK_SQL"
    DB_EXISTS="$(psql_as_postgres "$CHECK_SQL" tuple | tr -d '[:space:]')"

    if [ "$DB_EXISTS" = "1" ]; then
      ok "数据库 $dbname 已存在，跳过创建"
    else
      CREATE_SQL="$TMPD/create.sql"
      printf "CREATE DATABASE \"%s\" OWNER \"%s\" ENCODING 'UTF8' TEMPLATE template0;\n" \
        "$dbname" "$DB_USER_VALUE" > "$CREATE_SQL"
      psql_as_postgres "$CREATE_SQL"
      ok "数据库 $dbname 已创建（表结构由后端启动时 Flyway 自动迁移）"
    fi
  fi
fi

# ---------------------------------------------------------------- 完成提示
echo
log "首次部署准备工作完成"
cat <<'NEXT'
    接下来发布应用本体：
      1) 在开发机执行：powershell -ExecutionPolicy Bypass -File deploy\build.ps1
      2) 上传并发布：
         scp deploy\out\xiqian-*.tar.gz root@服务器:/tmp/
         ssh root@服务器 "sudo /opt/xiqian/bin/server-release.sh /tmp/xiqian-....tar.gz"

    发布后检查：
      systemctl status xiqian-draw
      curl -s http://127.0.0.1:8080/actuator/health
      journalctl -u xiqian-draw -n 50 --no-pager     # 确认 Flyway 迁移成功

    若 nginx 配置里还是占位域名，请替换后执行：nginx -t && systemctl reload nginx
NEXT
