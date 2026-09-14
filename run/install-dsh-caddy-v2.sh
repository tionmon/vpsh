#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# DeepSeek Harness + Caddy V2 installer entrypoint.
#
# The original, battle-tested installer is kept verbatim in:
#   install-dsh-caddy-v2-core.sh
#
# After the core deployment succeeds, this wrapper installs a small local DSH
# profile bundle that keeps remote Settings / Models / Provider / API Key
# access, but hides the Host-native "Open configuration file" action from
# non-loopback browsers. That action cannot work on a headless VPS because it
# asks the VPS itself to launch a desktop text editor.
#
# Disable only this guard when needed:
#   DSH_REMOTE_GUARD=0 bash install-dsh-caddy-v2.sh
#
# Optional raw source override (useful with a mirror):
#   VPSH_RAW_BASE=https://example.com/vpsh/run bash install-dsh-caddy-v2.sh

DSH_REMOTE_GUARD="${DSH_REMOTE_GUARD:-1}"
VPSH_RAW_BASE="${VPSH_RAW_BASE:-https://raw.githubusercontent.com/tionmon/vpsh/refs/heads/main/run}"

case "$DSH_REMOTE_GUARD" in
  0|1) ;;
  *) printf '[x] DSH_REMOTE_GUARD 仅支持 0 或 1。\n' >&2; exit 1 ;;
esac

log()  { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
info() { printf '\033[1;36m[i]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

TMP_DIR=""
cleanup() {
  [[ -n "$TMP_DIR" ]] && rm -rf -- "$TMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT
trap 'die "入口脚本在第 ${LINENO} 行失败。请查看上方错误信息。"' ERR

SCRIPT_PATH="${BASH_SOURCE[0]:-}"
SCRIPT_DIR=""
if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
  SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd -P)"
fi

TMP_DIR="$(mktemp -d)"

resolve_component() {
  local name="$1" destination="$2"

  if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/$name" ]]; then
    cp -a -- "$SCRIPT_DIR/$name" "$destination"
    info "使用本地组件：$SCRIPT_DIR/$name"
    return 0
  fi

  command -v curl >/dev/null 2>&1 || die "需要 curl 下载组件：$name"
  local url="${VPSH_RAW_BASE%/}/$name"
  info "下载组件：$url"
  curl -fsSL \
    --retry 3 \
    --retry-delay 2 \
    --connect-timeout 10 \
    --max-time 120 \
    "$url" -o "$destination"
  [[ -s "$destination" ]] || die "下载到的组件为空：$name"
}

CORE_SCRIPT="$TMP_DIR/install-dsh-caddy-v2-core.sh"
GUARD_SCRIPT="$TMP_DIR/dsh-caddy-remote-guard.sh"

resolve_component "install-dsh-caddy-v2-core.sh" "$CORE_SCRIPT"
chmod 0700 "$CORE_SCRIPT"

log "执行 DSH + Caddy 核心安装/升级流程..."
bash "$CORE_SCRIPT" "$@"

if [[ "$DSH_REMOTE_GUARD" == "0" ]]; then
  warn "DSH_REMOTE_GUARD=0：跳过远程“打开配置文件”按钮保护。"
  exit 0
fi

resolve_component "dsh-caddy-remote-guard.sh" "$GUARD_SCRIPT"
chmod 0700 "$GUARD_SCRIPT"

log "安装远程 Settings document guard..."
bash "$GUARD_SCRIPT"

printf '\n'
log "完整部署完成。"
printf '远程浏览器：Models / Provider / API Key 保持可用；“打开配置文件”不再显示。\n'
printf 'loopback 浏览器：保留 DSH 原生“打开配置文件”行为。\n'
