#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# DeepSeek Harness (DSH) + Caddy 2 + Basic Auth + Remote Settings V2
# -----------------------------------------------------------------
# Goal:
#   Internet -> Caddy HTTPS + Basic Auth -> 127.0.0.1:3080 -> DSH
#
# V2 fixes DSH remote-browser Settings/Models limitations by installing
# dsh-web-lan-access, while overriding its default 0.0.0.0 bind back to
# 127.0.0.1. Caddy is the only public ingress and rewrites upstream Host/
# Origin to loopback AFTER Basic Auth succeeds, so DSH's privileged API
# loopback fence remains behind the external authentication layer.
#
# Supported: Debian/Ubuntu + systemd, amd64/arm64
#
# Fresh install / upgrade current V1:
#   bash install-dsh-caddy-v2.sh
#
# Non-interactive:
#   DOMAIN=dsh.example.com AUTH_USER=admin AUTH_PASS='strong-pass' \
#     bash install-dsh-caddy-v2.sh
#
# Optional:
#   DSH_CHANNEL=latest|next     (default: latest)
#   DSH_PORT=3080
#   DSH_USER=dsh
#   DSH_HOME=/var/lib/dsh
#   DSH_WORKSPACE=/srv/dsh/workspace

DSH_PORT="${DSH_PORT:-3080}"
DOMAIN="${DOMAIN:-${1:-}}"
AUTH_USER="${AUTH_USER:-}"
AUTH_PASS="${AUTH_PASS:-}"
DSH_USER="${DSH_USER:-dsh}"
DSH_HOME="${DSH_HOME:-/var/lib/dsh}"
DSH_WORKSPACE="${DSH_WORKSPACE:-/srv/dsh/workspace}"
CREDENTIAL_FILE="${CREDENTIAL_FILE:-/root/dsh-access.txt}"
NODE_MAJOR="${NODE_MAJOR:-24}"
DSH_CHANNEL="${DSH_CHANNEL:-latest}"
REMOTE_PLUGIN="dsh-web-lan-access"
REMOTE_PLUGIN_SPEC="${REMOTE_PLUGIN_SPEC:-dsh-web-lan-access@latest}"
PROFILE_DIR="${DSH_HOME}/profiles/web"
PROFILE_PATCH="${PROFILE_DIR}/cordis.patch.yml"
LOOPBACK_PATCH="${DSH_HOME}/dsh-caddy-loopback.patch.yml"
PATH_DSH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

log()  { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
info() { printf '\033[1;36m[i]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

trap 'die "脚本在第 ${LINENO} 行失败。请查看上方错误信息。"' ERR

[[ "${EUID}" -eq 0 ]] || die "请使用 root 运行：sudo bash $0"
[[ -r /etc/os-release ]] || die "无法识别 Linux 发行版。"
# shellcheck disable=SC1091
source /etc/os-release
case "${ID:-}" in
  debian|ubuntu) ;;
  *) die "当前脚本仅支持 Debian / Ubuntu；检测到：${ID:-unknown}" ;;
esac
command -v systemctl >/dev/null 2>&1 || die "需要 systemd。"

ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
  amd64|arm64) ;;
  *) die "当前自动安装仅支持 amd64/arm64；检测到：$ARCH" ;;
esac

case "$DSH_CHANNEL" in
  latest|next) ;;
  *) die "DSH_CHANNEL 仅支持 latest 或 next；当前：$DSH_CHANNEL" ;;
esac

# Reuse V1 credentials when upgrading unless the caller explicitly overrides them.
if [[ -f "$CREDENTIAL_FILE" ]]; then
  if [[ -z "$DOMAIN" ]]; then
    DOMAIN="$(sed -n 's/^URL=https:\/\/\([^\/?]*\).*/\1/p' "$CREDENTIAL_FILE" | head -n 1 || true)"
  fi
  if [[ -z "$AUTH_USER" ]]; then
    AUTH_USER="$(sed -n 's/^USERNAME=//p' "$CREDENTIAL_FILE" | head -n 1 || true)"
  fi
  if [[ -z "$AUTH_PASS" ]]; then
    AUTH_PASS="$(sed -n 's/^PASSWORD=//p' "$CREDENTIAL_FILE" | head -n 1 || true)"
  fi
  if [[ -n "$DOMAIN" ]]; then
    info "检测到现有部署，将优先复用：${DOMAIN}"
  fi
fi

if [[ -z "$DOMAIN" ]]; then
  read -r -p "请输入 DSH 域名（例如 dsh.example.com）: " DOMAIN
fi
DOMAIN="${DOMAIN#http://}"
DOMAIN="${DOMAIN#https://}"
DOMAIN="${DOMAIN%%/*}"
[[ "$DOMAIN" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] || die "域名格式不正确：$DOMAIN"
[[ "$DOMAIN" == *.* ]] || die "请使用完整域名，例如 dsh.example.com"

if [[ -z "$AUTH_USER" ]]; then
  if [[ -t 0 ]]; then
    read -r -p "Basic Auth 用户名 [admin]: " AUTH_USER
  fi
  AUTH_USER="${AUTH_USER:-admin}"
fi
[[ "$AUTH_USER" =~ ^[A-Za-z0-9_.-]+$ ]] || die "用户名仅允许字母、数字、_、.、-"

if [[ -z "$AUTH_PASS" && -t 0 ]]; then
  read -r -s -p "Basic Auth 密码（直接回车则自动生成）: " AUTH_PASS || true
  printf '\n'
fi

export DEBIAN_FRONTEND=noninteractive
log "安装基础依赖..."
apt-get update
apt-get install -y \
  ca-certificates curl gnupg debian-keyring debian-archive-keyring \
  apt-transport-https build-essential python3 make g++ git openssl iproute2

if [[ -z "$AUTH_PASS" ]]; then
  AUTH_PASS="$(openssl rand -hex 18)"
  AUTO_PASS=1
else
  AUTO_PASS=0
fi

log "安装/更新 Node.js ${NODE_MAJOR}.x LTS..."
curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" -o /tmp/nodesource_setup.sh
bash /tmp/nodesource_setup.sh
rm -f /tmp/nodesource_setup.sh
apt-get install -y --allow-downgrades nodejs
hash -r

NODE_VERSION="$(node -v)"
NODE_NUM="${NODE_VERSION#v}"
NODE_MAJ="${NODE_NUM%%.*}"
[[ "$NODE_MAJ" -eq "$NODE_MAJOR" ]] || die "Node.js 主版本异常：期望 ${NODE_MAJOR}.x，实际 ${NODE_VERSION}"

# DSH's plugin manager uses pnpm. Keep npm on 11.x for Node 24 native-package compatibility.
log "安装兼容的 npm 11 与最新 pnpm..."
npm install -g npm@11 pnpm@latest
hash -r
log "Node.js: $(node -v) / npm: $(npm -v) / pnpm: $(pnpm -v)"

log "停止现有 DSH 服务（如存在）..."
systemctl stop dsh.service >/dev/null 2>&1 || true

log "全局安装/更新 DeepSeek Harness (${DSH_CHANNEL})..."
DSH_SPEC="@deepseek-ai/dsh@${DSH_CHANNEL}"
npm install -g "$DSH_SPEC" --foreground-scripts
hash -r
DSH_BIN="$(command -v dsh || true)"
[[ -n "$DSH_BIN" ]] || die "DSH 已安装但找不到 dsh 命令。"
DSH_VERSION="$($DSH_BIN --version 2>/dev/null | tail -n 1 || true)"
[[ -n "$DSH_VERSION" ]] || die "dsh --version 没有输出，安装可能异常。"
log "DSH: $DSH_VERSION ($DSH_BIN)"

log "创建/修复隔离的 DSH 用户、数据目录与工作区..."
if ! id "$DSH_USER" >/dev/null 2>&1; then
  useradd --system --create-home --home-dir "$DSH_HOME" --shell /usr/sbin/nologin "$DSH_USER"
fi
mkdir -p "$DSH_HOME" "$DSH_WORKSPACE"
chown -R "$DSH_USER:$DSH_USER" "$DSH_HOME" "$DSH_WORKSPACE"
chmod 750 "$DSH_HOME" "$DSH_WORKSPACE"

# Repair the broken V2 marker block from older versions of this installer.
# A freshly initialized DSH profile may contain a standalone `[]`; appending a
# second YAML document/list item after it makes the profile invalid. We only
# remove our own managed block and preserve every other user patch verbatim.
if [[ -f "$PROFILE_PATCH" ]]; then
  log "检查并修复旧版 V2 profile patch（如存在）..."
  python3 - "$PROFILE_PATCH" <<'PY_REPAIR'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding='utf-8')
s2 = re.sub(r'\n?# BEGIN DSH-CADDY-V2-LOOPBACK.*?# END DSH-CADDY-V2-LOOPBACK\n?', '\n', s, flags=re.S)
if s2 != s:
    s2 = s2.strip()
    # DSH expects a YAML patch list. Preserve an existing empty-list profile.
    p.write_text((s2 + '\n') if s2 else '[]\n', encoding='utf-8')
PY_REPAIR
  chown "$DSH_USER:$DSH_USER" "$PROFILE_PATCH"
fi

# Keep our loopback override in its own overlay instead of mutating the profile.
# This overlay is applied last via --patch, after the plugin bundle that binds
# 0.0.0.0, so DSH stays reachable only from local Caddy.
log "生成独立的 DSH loopback 安全覆盖层..."
cat > "$LOOPBACK_PATCH" <<EOF_LOOPBACK
# Managed by install-dsh-caddy-v2.sh -- do not expose DSH directly.
- id: webserver
  config:
    host: '127.0.0.1'
    port: ${DSH_PORT}
    compression: gzip
    compressionLevel: 1
    compressionThresholdBytes: 1024
EOF_LOOPBACK
chown "$DSH_USER:$DSH_USER" "$LOOPBACK_PATCH"
chmod 640 "$LOOPBACK_PATCH"

write_systemd_unit() {
  cat > /etc/systemd/system/dsh.service <<EOF_UNIT
[Unit]
Description=DeepSeek Harness Web UI
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${DSH_USER}
Group=${DSH_USER}
WorkingDirectory=${DSH_WORKSPACE}
Environment=HOME=${DSH_HOME}
Environment=DSH_HOME=${DSH_HOME}
Environment=PATH=${PATH_DSH}
ExecStart=${DSH_BIN} --profile web --patch ${LOOPBACK_PATCH} --host 127.0.0.1 --port ${DSH_PORT} --trusted-host ${DOMAIN}
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true

[Install]
WantedBy=multi-user.target
EOF_UNIT
  systemctl daemon-reload
}

write_systemd_unit

run_as_dsh() {
  runuser -u "$DSH_USER" -- env \
    HOME="$DSH_HOME" \
    DSH_HOME="$DSH_HOME" \
    PATH="$PATH_DSH" \
    "$@"
}

# The plugin manager expects an initialized web profile. On a truly fresh machine,
# briefly start stock DSH on loopback only, then stop it before installing plugins.
if [[ ! -d "$PROFILE_DIR" ]]; then
  log "首次初始化 DSH web profile（仅监听 127.0.0.1）..."
  systemctl start dsh.service
  PROFILE_READY=0
  for _ in $(seq 1 45); do
    if [[ -d "$PROFILE_DIR" ]]; then
      PROFILE_READY=1
      break
    fi
    sleep 1
  done
  systemctl stop dsh.service >/dev/null 2>&1 || true
  if [[ "$PROFILE_READY" -ne 1 ]]; then
    journalctl -u dsh.service -n 120 --no-pager || true
    die "DSH web profile 初始化失败：未找到 $PROFILE_DIR"
  fi
fi

log "安装/更新远程 Settings 修复插件：${REMOTE_PLUGIN_SPEC} ..."
# Reinstall cleanly so rerunning this script also upgrades the plugin.
run_as_dsh "$DSH_BIN" plugin --profile web remove "$REMOTE_PLUGIN" >/dev/null 2>&1 || true
run_as_dsh "$DSH_BIN" plugin --profile web add "$REMOTE_PLUGIN_SPEC"

[[ -d "$PROFILE_DIR" ]] || die "插件安装后仍找不到 profile：$PROFILE_DIR"

log "验证 DSH 配置层可以正常解析..."
if ! run_as_dsh "$DSH_BIN" --profile web --patch "$LOOPBACK_PATCH" --dump-config >/tmp/dsh-v2-dump-config.txt 2>/tmp/dsh-v2-dump-config.err; then
  cat /tmp/dsh-v2-dump-config.err >&2 || true
  die "DSH 配置解析失败。已停止启动，避免 systemd 反复重启。"
fi
rm -f /tmp/dsh-v2-dump-config.txt /tmp/dsh-v2-dump-config.err

log "启动 DSH V2..."
systemctl enable dsh.service >/dev/null 2>&1 || true
systemctl restart dsh.service

DSH_READY=0
for _ in $(seq 1 60); do
  if ss -H -lnt 2>/dev/null | awk -v p=":${DSH_PORT}" '$4 ~ p"$" {print $4}' | grep -q .; then
    DSH_READY=1
    break
  fi
  sleep 1
done
if [[ "$DSH_READY" -ne 1 ]]; then
  journalctl -u dsh.service -n 150 --no-pager || true
  die "DSH 未监听 ${DSH_PORT} 端口。"
fi

# Fail closed if the plugin's 0.0.0.0 bind escaped our override.
LISTEN_ADDRS="$(ss -H -lnt 2>/dev/null | awk -v p=":${DSH_PORT}" '$4 ~ p"$" {print $4}')"
if printf '%s\n' "$LISTEN_ADDRS" | grep -Eq '(^|\])0\.0\.0\.0:|^\*:|^\[::\]:'; then
  systemctl stop dsh.service || true
  die "安全检查失败：DSH 正在公网/全接口监听 ${DSH_PORT}：${LISTEN_ADDRS}"
fi
if printf '%s\n' "$LISTEN_ADDRS" | grep -Ev '^(127\.0\.0\.1|\[::1\]):[0-9]+$' | grep -q .; then
  systemctl stop dsh.service || true
  die "安全检查失败：发现非 loopback 监听地址：${LISTEN_ADDRS}"
fi
log "监听安全检查通过：${LISTEN_ADDRS//$'\n'/, }"

log "验证远程 Settings bootstrap（ownsHost）已注入..."
PLUGIN_OK=0
for _ in $(seq 1 20); do
  PAGE="$(curl -fsS "http://127.0.0.1:${DSH_PORT}/" 2>/dev/null || true)"
  if printf '%s' "$PAGE" | grep -q 'lan-access-polyfill' \
     && printf '%s' "$PAGE" | grep -q 'ownsHost:true'; then
    PLUGIN_OK=1
    break
  fi
  sleep 1
done
# Some DSH builds protect even the loopback index with the native browser cookie.
# In that case, verify both the installed bootstrap code and the composed bundle.
if [[ "$PLUGIN_OK" -ne 1 ]]; then
  if grep -Rqs 'ownsHost:true' "$PROFILE_DIR/node_modules/$REMOTE_PLUGIN" 2>/dev/null \
     && run_as_dsh "$DSH_BIN" --profile web --patch "$LOOPBACK_PATCH" --dump-config 2>/dev/null | grep -q 'lan-access'; then
    PLUGIN_OK=1
    info "首页受 DSH 原生认证保护；已通过插件文件 + composed config 验证 ownsHost bootstrap。"
  fi
fi
if [[ "$PLUGIN_OK" -ne 1 ]]; then
  journalctl -u dsh.service -n 150 --no-pager || true
  die "未检测到包含 ownsHost=true 的远程 Settings bootstrap。请不要继续公网使用该实例。"
fi

REMOTE_PLUGIN_VERSION="$(run_as_dsh npm view "$REMOTE_PLUGIN" version 2>/dev/null || true)"

log "安装/更新官方 Caddy 2 稳定版..."
install -d -m 0755 /usr/share/keyrings
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
  | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
  > /etc/apt/sources.list.d/caddy-stable.list
chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
chmod o+r /etc/apt/sources.list.d/caddy-stable.list
apt-get update
apt-get install -y caddy

log "生成 Caddy Basic Auth 密码哈希..."
AUTH_HASH="$(printf '%s\n' "$AUTH_PASS" | caddy hash-password --algorithm argon2id)"
[[ -n "$AUTH_HASH" ]] || die "Caddy 密码哈希生成失败。"

log "写入 Caddy V2 反向代理配置（鉴权后才映射为 loopback authority）..."
mkdir -p /etc/caddy/conf.d
STAMP="$(date +%Y%m%d-%H%M%S)"
MAIN_BACKUP="/etc/caddy/Caddyfile.dsh-v2-backup-${STAMP}"
SITE_BACKUP="/etc/caddy/conf.d/dsh.caddy.v2-backup-${STAMP}"

if [[ -f /etc/caddy/Caddyfile ]]; then
  cp -a /etc/caddy/Caddyfile "$MAIN_BACKUP"
else
  : > /etc/caddy/Caddyfile
fi
if [[ -f /etc/caddy/conf.d/dsh.caddy ]]; then
  cp -a /etc/caddy/conf.d/dsh.caddy "$SITE_BACKUP"
fi

cat > /etc/caddy/conf.d/dsh.caddy <<EOF_CADDY
${DOMAIN} {
    basic_auth argon2id {
        ${AUTH_USER} ${AUTH_HASH}
    }

    reverse_proxy 127.0.0.1:${DSH_PORT} {
        # Caddy Basic Auth is the external identity gate. Only after it succeeds
        # do we present requests to DSH as loopback, which is required by DSH's
        # privileged settings/credentials API fence on current releases.
        header_up Host 127.0.0.1:${DSH_PORT}
        header_up Origin http://127.0.0.1:${DSH_PORT}

        # Never forward the user's Basic credentials into DSH.
        header_up -Authorization
        header_up -Proxy-Authorization

        # Keep original deployment metadata available to ordinary upstream code.
        header_up X-Forwarded-Host {host}
        header_up X-Forwarded-Proto {scheme}
    }
}
EOF_CADDY

if ! grep -Eq '^[[:space:]]*import[[:space:]]+/etc/caddy/conf\.d/\*\.caddy([[:space:]]|$)' /etc/caddy/Caddyfile; then
  printf '\n# DSH managed sites\nimport /etc/caddy/conf.d/*.caddy\n' >> /etc/caddy/Caddyfile
fi

caddy fmt --overwrite /etc/caddy/conf.d/dsh.caddy >/dev/null
caddy fmt --overwrite /etc/caddy/Caddyfile >/dev/null

if ! caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile; then
  warn "Caddy 配置验证失败，正在恢复原配置。"
  [[ -f "$MAIN_BACKUP" ]] && cp -a "$MAIN_BACKUP" /etc/caddy/Caddyfile
  if [[ -f "$SITE_BACKUP" ]]; then
    cp -a "$SITE_BACKUP" /etc/caddy/conf.d/dsh.caddy
  else
    rm -f /etc/caddy/conf.d/dsh.caddy
  fi
  die "Caddy 配置与现有站点可能冲突。"
fi

systemctl enable caddy >/dev/null 2>&1 || true
systemctl restart caddy

if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q '^Status: active'; then
  log "检测到 UFW 已启用，只放行 80/443（不会开放 ${DSH_PORT}）..."
  ufw allow 80/tcp >/dev/null
  ufw allow 443/tcp >/dev/null
fi

log "获取 DSH 当前启动 Token..."
DSH_TOKEN=""
for _ in $(seq 1 20); do
  DSH_TOKEN="$(journalctl -u dsh.service -b --no-pager -n 400 2>/dev/null \
    | sed -n 's/.*[?&]token=\([^[:space:]]*\).*/\1/p' \
    | tail -n 1 | tr -d '\r' || true)"
  [[ -n "$DSH_TOKEN" ]] && break
  sleep 1
done

ACCESS_URL="https://${DOMAIN}/"
if [[ -n "$DSH_TOKEN" ]]; then
  ACCESS_URL="https://${DOMAIN}/?token=${DSH_TOKEN}"
fi

install -d -m 0700 "$(dirname "$CREDENTIAL_FILE")"
cat > "$CREDENTIAL_FILE" <<EOF_CREDS
DeepSeek Harness external access (V2)
URL=${ACCESS_URL}
USERNAME=${AUTH_USER}
PASSWORD=${AUTH_PASS}
DSH_LOCAL=http://127.0.0.1:${DSH_PORT}
WORKSPACE=${DSH_WORKSPACE}
REMOTE_SETTINGS_PLUGIN=${REMOTE_PLUGIN}
REMOTE_SETTINGS_PLUGIN_VERSION=${REMOTE_PLUGIN_VERSION:-unknown}
EOF_CREDS
chmod 600 "$CREDENTIAL_FILE"

cat > /usr/local/bin/dsh-access-url <<EOF_HELPER
#!/usr/bin/env bash
set -euo pipefail
TOKEN="\$(journalctl -u dsh.service -b --no-pager -n 500 2>/dev/null | sed -n 's/.*[?&]token=\\([^[:space:]]*\\).*/\\1/p' | tail -n 1 | tr -d '\\r')"
if [[ -n "\$TOKEN" ]]; then
  printf 'https://${DOMAIN}/?token=%s\\n' "\$TOKEN"
else
  printf 'https://${DOMAIN}/\\n'
  printf '未从日志找到启动 token；若浏览器已有 DSH Cookie，可直接访问。\\n' >&2
fi
EOF_HELPER
chmod 0755 /usr/local/bin/dsh-access-url

cat > /usr/local/bin/dsh-v2-check <<EOF_CHECK
#!/usr/bin/env bash
set -euo pipefail
printf '== DSH ==\\n'
systemctl --no-pager --full status dsh | sed -n '1,12p' || true
printf '\\n== Listen ==\\n'
ss -H -lnt | awk '\$4 ~ /:${DSH_PORT}\$/ {print \$4}'
printf '\n== Remote settings bootstrap ==\n'
PAGE="\$(curl -fsS http://127.0.0.1:${DSH_PORT}/ 2>/dev/null || true)"
if printf '%s' "\$PAGE" | grep -q lan-access-polyfill && printf '%s' "\$PAGE" | grep -q 'ownsHost:true'; then
  echo 'OK (live HTML: ownsHost=true)'
elif grep -Rqs 'ownsHost:true' '${PROFILE_DIR}/node_modules/${REMOTE_PLUGIN}' 2>/dev/null; then
  echo 'OK (installed bootstrap contains ownsHost=true; live index requires DSH auth)'
else
  echo FAILED
fi
printf '\\n== Caddy ==\\n'
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
EOF_CHECK
chmod 0755 /usr/local/bin/dsh-v2-check

cat > /usr/local/bin/dsh-v2-rollback-remote-settings <<EOF_ROLLBACK
#!/usr/bin/env bash
set -Eeuo pipefail
DSH_BIN="${DSH_BIN}"
DSH_USER="${DSH_USER}"
DSH_HOME="${DSH_HOME}"
PROFILE_PATCH="${PROFILE_PATCH}"
LOOPBACK_PATCH="${LOOPBACK_PATCH}"
PATH_DSH="${PATH_DSH}"
systemctl stop dsh.service || true
runuser -u "\$DSH_USER" -- env HOME="\$DSH_HOME" DSH_HOME="\$DSH_HOME" PATH="\$PATH_DSH" \
  "\$DSH_BIN" plugin --profile web remove ${REMOTE_PLUGIN} || true
# Keep the loopback overlay: systemd still references it and it remains the safety boundary.
systemctl restart dsh.service
echo '已移除远程 Settings 插件；loopback 安全覆盖与 Caddy 配置保持不变。'
EOF_ROLLBACK
chmod 0755 /usr/local/bin/dsh-v2-rollback-remote-settings

printf '\n'
printf '=================================================================\n'
printf ' DeepSeek Harness + Caddy V2 安装/升级完成\n'
printf '=================================================================\n'
printf 'DSH 版本       : %s\n' "$DSH_VERSION"
printf 'Node.js        : %s\n' "$(node -v)"
printf 'npm / pnpm     : %s / %s\n' "$(npm -v)" "$(pnpm -v)"
printf 'Caddy          : %s\n' "$(caddy version)"
printf '远程设置插件   : %s %s\n' "$REMOTE_PLUGIN" "${REMOTE_PLUGIN_VERSION:-latest}"
printf 'DSH 本地监听   : %s\n' "${LISTEN_ADDRS//$'\n'/, }"
printf '公网地址       : %s\n' "$ACCESS_URL"
printf 'Basic 用户     : %s\n' "$AUTH_USER"
printf 'Basic 密码     : %s\n' "$AUTH_PASS"
printf '工作目录       : %s\n' "$DSH_WORKSPACE"
printf '凭据文件       : %s (600)\n' "$CREDENTIAL_FILE"
printf '\n'
printf '现在通过域名访问后，Settings -> Models / Provider / API Key 应可远程使用。\n'
printf '升级已有 V1 时，建议浏览器执行一次硬刷新：Ctrl+Shift+R。\n'
printf '\n'
printf '检查全部状态： dsh-v2-check\n'
printf '获取当前 Token：dsh-access-url\n'
printf '实时 DSH 日志： journalctl -u dsh -f\n'
printf '实时 Caddy 日志：journalctl -u caddy -f\n'
printf '仅回滚远程设置补丁：dsh-v2-rollback-remote-settings\n'
printf '\n'
printf '安全边界：${DSH_PORT} 未对公网开放；只有 Caddy 80/443 是公网入口。\n'
printf '=================================================================\n'

if [[ "$AUTO_PASS" -eq 1 ]]; then
  warn "Basic Auth 密码是自动生成的，请保存好；同时已写入：$CREDENTIAL_FILE"
fi
