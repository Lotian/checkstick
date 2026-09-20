#!/usr/bin/env bash
# 囍签 · 发布 / 更新（在服务器上执行；首次部署与后续升级都用它）
#
# 用法：
#   sudo /opt/xiqian/bin/server-release.sh /tmp/xiqian-20260901-120000.tar.gz
#
# 流程：解包校验 -> 原子切换 current 软链接 -> 重启服务 -> 健康检查
#       任一环节失败都会回滚到上一个版本（含启动失败）
#
# 可用的环境变量（一般不用改）：
#   APP_ROOT=/opt/xiqian  SERVICE=xiqian-draw  RUN_USER=xiqian
#   ENV_FILE=/etc/xiqian/draw.env   HEALTH_URL（默认按 ENV_FILE 里的 SERVER_PORT 推导）
#   HEALTH_TIMEOUT=90  KEEP_RELEASES=5
set -euo pipefail

APP_ROOT="${APP_ROOT:-/opt/xiqian}"
SERVICE="${SERVICE:-xiqian-draw}"
RUN_USER="${RUN_USER:-xiqian}"
ENV_FILE="${ENV_FILE:-/etc/xiqian/draw.env}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-90}"
KEEP_RELEASES="${KEEP_RELEASES:-5}"

# 健康检查端口默认跟着环境变量文件里的 SERVER_PORT 走，避免改了端口后每次发布都被误判为不健康
if [ -z "${HEALTH_URL:-}" ]; then
  ENV_PORT=""
  if [ -r "$ENV_FILE" ]; then
    # 与 systemd 解析 EnvironmentFile 一致：去掉回车、两侧空白与引号
    ENV_PORT="$(sed -n 's/^SERVER_PORT=//p' "$ENV_FILE" | tail -n1 | tr -d '\r' \
      | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
            -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")"
  fi
  case "$ENV_PORT" in
    ''|*[!0-9]*) ENV_PORT=8080 ;;
  esac
  HEALTH_URL="http://127.0.0.1:${ENV_PORT}/actuator/health"
fi

# 数字型变量：非法值回落默认，并用 10# 规范化，避免 "08" 被当成八进制（$(( )) 会直接报错）
case "$HEALTH_TIMEOUT" in
  ''|*[!0-9]*) HEALTH_TIMEOUT=90 ;;
esac
HEALTH_TIMEOUT=$((10#$HEALTH_TIMEOUT))
case "$KEEP_RELEASES" in
  ''|*[!0-9]*) KEEP_RELEASES=5 ;;
esac
KEEP_RELEASES=$((10#$KEEP_RELEASES))

log()  { printf '\033[36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[32m    %s\033[0m\n' "$*"; }
warn() { printf '\033[33m!!  %s\033[0m\n' "$*"; }
fail() { printf '\033[31m!!  %s\033[0m\n' "$*" >&2; }

if [ "$(id -u)" -ne 0 ]; then
  fail "请用 root 或 sudo 执行"
  exit 1
fi

TARBALL="${1:-}"
if [ -z "$TARBALL" ]; then
  fail "用法: $0 /path/to/xiqian-<时间戳>.tar.gz"
  exit 1
fi
# 用通配符时可能一次匹配到多个包（例如 /root/release 里同时留着新旧两份），
# 那样第一个参数未必是你要发布的那一个，这里直接拒绝而不是猜。
if [ "$#" -gt 1 ]; then
  fail "一次只能发布一个包，但匹配到了 $# 个："
  printf '    %s\n' "$@" >&2
  fail "请明确指定要发布的那一个，例如：$0 release/xiqian-20260918231517.tar.gz"
  exit 1
fi
if [ ! -f "$TARBALL" ]; then
  fail "发布包不存在: $TARBALL"

  # 常见误用：把「上传包 bundle」当成了发布包 —— bundle 里还套着一层 release/
  for candidate in "$TARBALL" ./*.tar.gz /tmp/*.tar.gz; do
    [ -f "$candidate" ] || continue
    if tar -tzf "$candidate" 2>/dev/null | grep -qE '^release/.*\.tar\.gz$'; then
      inner="$(tar -tzf "$candidate" | grep -E '^release/.*\.tar\.gz$' | head -n1 || true)"
      warn "$candidate 是上传包（bundle），要发布的是解包后里面的发布包："
      warn "    tar -xzf \"$candidate\" && bash $0 \"$inner\""
      exit 1
    fi
  done

  warn "可用的 tar.gz（当前目录 / release / tmp）："
  # shellcheck disable=SC2012
  (ls -1 ./*.tar.gz release/*.tar.gz /tmp/*.tar.gz 2>/dev/null || true) >&2
  exit 1
fi
for bin in tar curl systemctl readlink; do
  command -v "$bin" >/dev/null 2>&1 || { fail "缺少命令: $bin"; exit 1; }
done
if ! id -u "$RUN_USER" >/dev/null 2>&1; then
  fail "运行用户 $RUN_USER 不存在，请先执行 server-install.sh"
  exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
RELEASE_DIR="$APP_ROOT/releases/$STAMP"
STAGE_DIR="$APP_ROOT/releases/.staging-$STAMP"

cleanup() {
  if [ -d "$STAGE_DIR" ]; then
    rm -rf "$STAGE_DIR"
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------- 解包校验
log "解包发布包：$TARBALL"

# 以 root 解包，因此先做成员白名单校验：只允许约定好的三样内容
# （PaxHeader/pax_global_header 是 tar 的元数据条目，非文件内容，容忍掉）
unexpected="$(tar -tzf "$TARBALL" \
  | sed -e 's#^\./##' \
  | grep -vE '^(draw-server\.jar|player(/.*)?|admin(/.*)?)$' \
  | grep -vE '(^|/)PaxHeaders([./]|$)|^pax_global_header$' \
  || true)"
if [ -n "$unexpected" ]; then
  fail "发布包包含预期外的成员，已拒绝解包："
  printf '%s\n' "$unexpected" >&2
  exit 1
fi

mkdir -p "$APP_ROOT/releases" "$STAGE_DIR"
tar -xzf "$TARBALL" -C "$STAGE_DIR"

# 落盘结果再校验一次：这才是真正防"多解出东西"的那道网
if [ -n "$(cd "$STAGE_DIR" && ls -A | grep -vxE 'draw-server\.jar|player|admin' || true)" ]; then
  fail "解包后出现预期外的顶层内容："
  (cd "$STAGE_DIR" && ls -A | grep -vxE 'draw-server\.jar|player|admin') >&2 || true
  exit 1
fi

for required in draw-server.jar player/index.html admin/index.html; do
  if [ ! -e "$STAGE_DIR/$required" ]; then
    fail "发布包内容不完整，缺少：$required（请用 deploy/build.ps1 重新打包）"
    exit 1
  fi
done
ok "成员白名单与必需文件校验通过"

chown -R "$RUN_USER:$RUN_USER" "$STAGE_DIR"
# nginx(www-data) 需要能读取静态文件
chmod -R a+rX "$STAGE_DIR"

if [ -e "$RELEASE_DIR" ]; then
  fail "版本目录已存在（同一秒内重复发布？）：$RELEASE_DIR"
  exit 1
fi
mv -T "$STAGE_DIR" "$RELEASE_DIR"
ok "已解包到 $RELEASE_DIR"

PREVIOUS=""
if [ -L "$APP_ROOT/current" ]; then
  PREVIOUS="$(readlink -f "$APP_ROOT/current" || true)"
fi

# ---------------------------------------------------------------- 切换版本
log "切换 current 软链接"
ln -sfn "releases/$STAMP" "$APP_ROOT/current.new"
mv -T "$APP_ROOT/current.new" "$APP_ROOT/current"
ok "current -> $(readlink -f "$APP_ROOT/current" || true)"

is_up() {
  local body
  body="$(curl -fsS --max-time 5 "$HEALTH_URL" 2>/dev/null || true)"
  [[ "$body" == *'"status":"UP"'* ]]
}

# 等到服务就绪或超时；返回 0 表示就绪
wait_for_health() {
  local timeout="$1" deadline
  deadline=$(( $(date +%s) + timeout ))
  while :; do
    if is_up; then
      return 0
    fi
    if [ "$(date +%s)" -ge "$deadline" ]; then
      return 1
    fi
    sleep 2
  done
}

rollback() {
  if [ -n "$PREVIOUS" ] && [ -d "$PREVIOUS" ]; then
    fail "正在回滚到上一个版本：$PREVIOUS"
    ln -sfn "$PREVIOUS" "$APP_ROOT/current.new"
    mv -T "$APP_ROOT/current.new" "$APP_ROOT/current"
    systemctl restart "$SERVICE" || true
    # 旧版本启动同样需要十几秒，这里必须给足时间，否则会误报"回滚失败"
    if wait_for_health "${ROLLBACK_TIMEOUT:-60}"; then
      fail "回滚完成，服务已恢复为旧版本，请排查新版本问题后再发布"
    else
      fail "回滚后健康检查仍然失败，请立即人工介入：journalctl -u $SERVICE -n 100 --no-pager"
    fi
  else
    fail "没有可回滚的历史版本，请立即人工介入：journalctl -u $SERVICE -n 100 --no-pager"
  fi
  exit 1
}

# ---------------------------------------------------------------- 重启与健康检查
log "重启服务 $SERVICE"
if ! systemctl restart "$SERVICE"; then
  fail "systemctl restart 失败"
  systemctl status "$SERVICE" --no-pager >&2 || true
  rollback
fi

log "等待健康检查通过（最长 ${HEALTH_TIMEOUT}s，探测 $HEALTH_URL）"
if ! wait_for_health "$HEALTH_TIMEOUT"; then
  fail "健康检查超时"
  echo '--- 最近日志 ---' >&2
  journalctl -u "$SERVICE" -n 60 --no-pager >&2 || true
  rollback
fi
ok "服务已就绪"

# ---------------------------------------------------------------- 清理旧版本
# KEEP_RELEASES=0 表示不清理（保留全部历史版本）
if [ "$KEEP_RELEASES" -gt 0 ]; then
  log "清理历史版本（保留最近 $KEEP_RELEASES 个）"
  CURRENT_TARGET="$(readlink -f "$APP_ROOT/current" || true)"
  removed=0
  while IFS= read -r old; do
    if [ -z "$old" ]; then
      continue
    fi
    if [ "$(readlink -f "$old" || true)" = "$CURRENT_TARGET" ]; then
      continue
    fi
    rm -rf "$old"
    ok "已删除 $(basename "$old")"
    removed=$((removed + 1))
  done < <(ls -1dt "$APP_ROOT"/releases/*/ 2>/dev/null | tail -n +$((KEEP_RELEASES + 1)) || true)
  if [ "$removed" -eq 0 ]; then
    ok "没有需要清理的旧版本"
  fi
fi

# 断电/kill -9 可能留下点开头的暂存目录，这里顺手清掉一天前的
find "$APP_ROOT/releases" -maxdepth 1 -name '.staging-*' -mtime +1 -exec rm -rf {} + 2>/dev/null || true

# ---------------------------------------------------------------- 完成
echo
log "发布完成"
echo "    版本目录 : $RELEASE_DIR"
echo "    当前版本 : $(readlink -f "$APP_ROOT/current" || true)"
echo "    服务状态 : $(systemctl is-active "$SERVICE")"
if [ -n "$PREVIOUS" ]; then
  echo "    可回滚至 : $PREVIOUS"
fi
echo
echo "    建议在浏览器里做一次冒烟验证：登录后台并新建一个组局（验证写接口与 CSRF 正常）"
