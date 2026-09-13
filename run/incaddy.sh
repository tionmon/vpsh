#!/usr/bin/env bash

# Docker + Caddy v2 一键部署脚本
# 支持 Debian / Ubuntu
#
# 交互模式：
#   bash incaddy.sh
#
# 命令行模式：
#   bash incaddy.sh docker
#   bash incaddy.sh caddy-systemd
#   bash incaddy.sh caddy-docker
#
# 常用参数：
#   -y, --yes                  自动确认安全默认项
#   --region cn|global         强制指定 VPS 地区
#   --caddy-image IMAGE        指定 Caddy Docker 镜像
#   --caddy-dir DIR            指定 Caddy Compose 目录
#   -h, --help                 显示帮助
#
# 环境变量同样支持：
#   AUTO_YES=1
#   CADDY_INSTALL_REGION=CN|GLOBAL
#   CADDY_IMAGE=caddy:2-alpine
#   CADDY_DIR=/opt/caddy

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_VERSION="2.0.0"

CADDY_DIR="${CADDY_DIR:-/opt/caddy}"
CADDY_NETWORK="${CADDY_NETWORK:-caddy}"
CADDY_IMAGE="${CADDY_IMAGE:-caddy:2-alpine}"
DOCKER_INSTALL_URL="${DOCKER_INSTALL_URL:-https://get.docker.com}"
AUTO_YES="${AUTO_YES:-0}"

REGION_KIND=""
DETECTED_COUNTRY=""
OS_ID=""
OS_NAME=""
OS_VERSION=""
ARCH=""
ACTION=""
CHOSEN_MODE=""

APT_OPTS=(
  -o DPkg::Lock::Timeout=120
  -o Acquire::Retries=3
)

TMP_FILES=()

if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()   { error "$*"; exit 1; }
separator() { printf '\n============================================================\n\n'; }
timestamp() { date '+%Y%m%d-%H%M%S'; }

cleanup() {
  local f
  for f in "${TMP_FILES[@]:-}"; do
    [[ -n "$f" ]] && rm -f -- "$f" 2>/dev/null || true
  done
}

on_error() {
  local rc=$?
  local line="${BASH_LINENO[0]:-${LINENO}}"
  echo
  error "脚本执行过程中发生错误。"
  error "退出代码：${rc}"
  error "大致位置：第 ${line} 行"
  exit "$rc"
}

trap cleanup EXIT
trap on_error ERR
trap 'exit 130' INT
trap 'exit 143' TERM

show_help() {
  cat <<EOF_HELP
Docker + Caddy v2 一键部署脚本 v${SCRIPT_VERSION}

用法：
  $0 [ACTION] [OPTIONS]

ACTION：
  docker          只安装/准备 Docker Engine + Compose v2
  caddy-systemd   安装或更新 Caddy systemd 版
  caddy-docker    安装或更新 Caddy Docker Compose 版

OPTIONS：
  -y, --yes                  自动确认安全默认项
  --region cn|global         强制指定地区
  --caddy-image IMAGE        Caddy Docker 镜像，默认 caddy:2-alpine
  --caddy-dir DIR            Compose 目录，默认 /opt/caddy
  -v, --version              显示版本
  -h, --help                 显示帮助

示例：
  $0
  $0 docker --yes --region cn
  $0 caddy-docker --yes
  $0 caddy-docker --caddy-image caddy:2-alpine
EOF_HELP
}

parse_args() {
  while (($#)); do
    case "$1" in
      docker|caddy-systemd|caddy-docker)
        [[ -z "$ACTION" ]] || die "只能指定一个 ACTION。"
        ACTION="$1"
        ;;
      -y|--yes)
        AUTO_YES=1
        ;;
      --region)
        shift
        (($#)) || die "--region 缺少参数。"
        case "${1,,}" in
          cn) CADDY_INSTALL_REGION="CN" ;;
          global) CADDY_INSTALL_REGION="GLOBAL" ;;
          *) die "--region 仅支持 cn 或 global。" ;;
        esac
        ;;
      --caddy-image)
        shift
        (($#)) || die "--caddy-image 缺少参数。"
        CADDY_IMAGE="$1"
        ;;
      --caddy-dir)
        shift
        (($#)) || die "--caddy-dir 缺少参数。"
        CADDY_DIR="${1%/}"
        [[ -n "$CADDY_DIR" ]] || CADDY_DIR="/"
        ;;
      -v|--version)
        echo "$SCRIPT_VERSION"
        exit 0
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      --)
        shift
        break
        ;;
      *)
        die "未知参数：$1（使用 --help 查看帮助）"
        ;;
    esac
    shift
  done
}

prompt_read() {
  local prompt="$1" var_name="$2" value=""

  if [[ -r /dev/tty ]]; then
    IFS= read -r -p "$prompt" value </dev/tty || return 1
  elif [[ -t 0 ]]; then
    IFS= read -r -p "$prompt" value || return 1
  else
    return 1
  fi

  printf -v "$var_name" '%s' "$value"
}

ask_yes_no() {
  local prompt="$1" default="${2:-Y}" answer="" suffix=""

  if [[ "$AUTO_YES" == "1" ]]; then
    info "自动确认：$prompt"
    return 0
  fi

  [[ "$default" == "Y" ]] && suffix="[Y/n]" || suffix="[y/N]"

  while true; do
    if ! prompt_read "$prompt $suffix " answer; then
      [[ "$default" == "Y" ]] && return 0 || return 1
    fi
    [[ -z "$answer" ]] && answer="$default"
    case "${answer,,}" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) warn "请输入 y 或 n。" ;;
    esac
  done
}

check_root() {
  [[ "${EUID}" -eq 0 ]] || die "请使用 root 用户执行，或使用 sudo。"
}

check_os() {
  [[ -f /etc/os-release ]] || die "无法读取 /etc/os-release。"
  # shellcheck disable=SC1091
  . /etc/os-release

  OS_ID="${ID:-unknown}"
  OS_NAME="${PRETTY_NAME:-unknown}"
  OS_VERSION="${VERSION_ID:-unknown}"

  case "${OS_ID,,}" in
    debian|ubuntu) ;;
    *) die "当前只支持 Debian / Ubuntu，检测到：${OS_NAME}" ;;
  esac

  ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
}

check_architecture() {
  case "$ARCH" in
    amd64|arm64) ok "CPU 架构受支持：$ARCH" ;;
    *) warn "当前架构为 $ARCH；不会阻止安装，但主要测试 amd64 / arm64。" ;;
  esac
}

check_systemd() {
  command -v systemctl >/dev/null 2>&1 || die "未检测到 systemctl。"
  [[ -d /run/systemd/system ]] || die "当前系统似乎没有运行 systemd。"
}

show_system_info() {
  separator
  echo -e "${BOLD}系统信息${NC}"
  echo
  echo "系统     : $OS_NAME"
  echo "版本     : $OS_VERSION"
  echo "架构     : $ARCH"
  echo "内核     : $(uname -r)"
  echo "主机名   : $(hostname)"
  echo
}

apt_update() {
  info "更新 APT 软件包索引（最多等待 dpkg 锁 120 秒）..."
  apt-get "${APT_OPTS[@]}" update
}

apt_install() {
  DEBIAN_FRONTEND=noninteractive apt-get "${APT_OPTS[@]}" install -y "$@"
}

package_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

ensure_packages() {
  local missing=() package
  for package in "$@"; do
    package_installed "$package" || missing+=("$package")
  done

  ((${#missing[@]} == 0)) && { ok "前置依赖检查通过。"; return 0; }

  warn "检测到缺少依赖：${missing[*]}"
  ask_yes_no "是否自动安装这些依赖？" "Y" || die "缺少必要依赖，无法继续。"
  apt_update
  apt_install "${missing[@]}"
  ok "依赖安装完成。"
}

backup_file() {
  local file="$1" backup
  [[ -e "$file" ]] || return 0
  backup="${file}.bak.$(timestamp)"
  cp -a -- "$file" "$backup"
  ok "已备份：$backup"
}

get_port_conflicts() {
  ss -H -lntup 2>/dev/null | awk '$5 ~ /:80$/ || $5 ~ /:443$/ {print}' || true
}

ensure_ports_free() {
  local conflicts
  conflicts="$(get_port_conflicts)"
  [[ -z "$conflicts" ]] && { ok "80 / 443 端口未发现冲突。"; return 0; }
  warn "检测到 80 或 443 端口已被占用："
  echo
  echo "$conflicts"
  echo
  die "请先处理端口占用后重新运行脚本。"
}

detect_region() {
  local country=""

  if [[ -n "${CADDY_INSTALL_REGION:-}" ]]; then
    case "${CADDY_INSTALL_REGION^^}" in
      CN)
        REGION_KIND="CN"; DETECTED_COUNTRY="CN"
        warn "已强制指定地区：中国大陆。"
        return
        ;;
      GLOBAL)
        REGION_KIND="GLOBAL"; DETECTED_COUNTRY="MANUAL"
        warn "已强制指定地区：海外 / 其他地区。"
        return
        ;;
      *) warn "忽略无效 CADDY_INSTALL_REGION=${CADDY_INSTALL_REGION}" ;;
    esac
  fi

  info "检测 VPS 公网出口地区..."
  country="$(curl -fsSL --connect-timeout 5 --max-time 8 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null \
    | awk -F= '$1=="loc" {gsub(/[[:space:]\r]/,"",$2); print toupper($2); exit}' || true)"

  if [[ ! "$country" =~ ^[A-Z]{2}$ ]]; then
    country="$(curl -fsSL --connect-timeout 5 --max-time 8 https://ipapi.co/country/ 2>/dev/null \
      | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]' || true)"
  fi

  if [[ "$country" == "CN" ]]; then
    REGION_KIND="CN"; DETECTED_COUNTRY="CN"
    ok "检测到 VPS 公网出口：中国大陆。"
  elif [[ "$country" =~ ^[A-Z]{2}$ ]]; then
    REGION_KIND="GLOBAL"; DETECTED_COUNTRY="$country"
    ok "检测到 VPS 国家 / 地区代码：$country"
  elif [[ "$AUTO_YES" == "1" ]]; then
    REGION_KIND="GLOBAL"; DETECTED_COUNTRY="AUTO-GLOBAL"
    warn "无法判断地区；--yes 模式下按海外/官方源处理。"
  else
    local choice=""
    echo
    echo "无法可靠判断地区："
    echo "  1. 中国大陆"
    echo "  2. 海外 / 香港 / 澳门 / 台湾 / 其他地区"
    while true; do
      prompt_read "请选择 [1-2]: " choice || die "无可用交互终端，请使用 --region cn|global。"
      case "$choice" in
        1) REGION_KIND="CN"; DETECTED_COUNTRY="MANUAL-CN"; break ;;
        2) REGION_KIND="GLOBAL"; DETECTED_COUNTRY="MANUAL-GLOBAL"; break ;;
        *) warn "请输入 1 或 2。" ;;
      esac
    done
  fi
}

get_public_ip() {
  curl -fsSL --connect-timeout 5 --max-time 8 https://api64.ipify.org 2>/dev/null || true
}

print_test_url() {
  local ip
  ip="$(get_public_ip)"
  [[ -n "$ip" ]] || return 0
  [[ "$ip" == *:* ]] && echo "测试地址 : http://[$ip]" || echo "测试地址 : http://$ip"
}

handle_ufw() {
  local mode="${1:-systemd}"
  command -v ufw >/dev/null 2>&1 || return 0
  ufw status 2>/dev/null | grep -q '^Status: active' || return 0

  warn "检测到 UFW 已启用。"
  if [[ "$mode" == "docker" ]]; then
    warn "Docker 发布端口使用独立 iptables/nftables 规则，可能绕过 UFW 的常规过滤。"
    warn "若需要严格来源限制，请额外配置 Docker 的 DOCKER-USER/防火墙链。"
  fi

  echo
  echo "Caddy 通常需要开放：TCP 80、TCP 443、UDP 443（HTTP/3）"
  echo

  if ask_yes_no "是否自动添加这些 UFW 规则？" "N"; then
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 443/udp
    ok "UFW 规则添加完成。"
  else
    warn "未修改 UFW。"
  fi
}

run_docker_install_script() {
  local mode="$1" tmp
  tmp="$(mktemp)"
  TMP_FILES+=("$tmp")

  info "下载 Docker 官方安装脚本..."
  curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 120 \
    "$DOCKER_INSTALL_URL" -o "$tmp" || return 1
  [[ -s "$tmp" ]] || { warn "下载到的 Docker 安装脚本为空。"; return 1; }

  case "$mode" in
    aliyun)
      info "使用 Docker 官方脚本 + Aliyun Mirror..."
      bash "$tmp" --mirror Aliyun
      ;;
    official)
      info "使用 Docker 官方默认软件源..."
      bash "$tmp"
      ;;
    *) die "未知 Docker 安装模式：$mode" ;;
  esac
}

verify_docker_daemon() {
  if docker info >/dev/null 2>&1; then
    ok "Docker daemon 运行正常。"
    return 0
  fi

  error "Docker daemon 无法正常连接。"
  command -v journalctl >/dev/null 2>&1 && journalctl -u docker --no-pager -n 50 || true
  return 1
}

install_docker_engine() {
  check_systemd
  detect_region
  separator
  echo -e "${BOLD}Docker Engine 安装${NC}"
  echo

  if [[ "$REGION_KIND" == "CN" ]]; then
    echo "地区     : 中国大陆"
    echo "首选方案 : Docker 官方脚本 + Aliyun Mirror"
    echo "兜底方案 : Docker 官方默认源"
    echo
    if run_docker_install_script aliyun; then
      ok "Docker 已通过 Aliyun 软件源安装完成。"
    else
      warn "Aliyun 安装失败，自动回退官方源..."
      run_docker_install_script official || die "Aliyun 和 Docker 官方安装方式均失败。"
      ok "Docker 已通过官方默认源安装完成。"
    fi
  else
    echo "地区     : ${DETECTED_COUNTRY:-海外 / 其他地区}"
    echo "安装方式 : Docker 官方默认源"
    echo
    run_docker_install_script official || die "Docker 官方安装失败。"
    ok "Docker 官方安装完成。"
  fi

  systemctl enable --now docker
  sleep 2
  verify_docker_daemon || die "Docker 已安装，但服务启动失败。"
}

ensure_docker_compose() {
  docker compose version >/dev/null 2>&1 && { ok "Docker Compose Plugin 已安装。"; return 0; }

  warn "未检测到 Docker Compose v2。"
  ask_yes_no "是否自动安装 Docker Compose Plugin？" "Y" || die "Docker Compose Plugin 不存在。"
  apt_update

  if apt-cache show docker-compose-plugin >/dev/null 2>&1; then
    apt_install docker-compose-plugin
  elif apt-cache show docker-compose-v2 >/dev/null 2>&1; then
    apt_install docker-compose-v2
  else
    die "当前 APT 软件源中没有找到 Docker Compose v2。"
  fi

  docker compose version >/dev/null 2>&1 || die "Docker Compose 安装后仍无法正常运行。"
  ok "Docker Compose Plugin 安装完成。"
}

ensure_docker() {
  ensure_packages ca-certificates curl iproute2

  if ! command -v docker >/dev/null 2>&1; then
    warn "未检测到 Docker Engine。"
    ask_yes_no "是否自动安装 Docker Engine？" "Y" || die "Docker 不存在，已取消。"
    install_docker_engine
  else
    ok "检测到 Docker Engine：$(docker --version 2>/dev/null || true)"
    if ! docker info >/dev/null 2>&1; then
      warn "Docker 已安装，但 daemon 当前不可用。"
      ask_yes_no "是否启动 Docker 并设置开机启动？" "Y" || die "Docker daemon 未运行。"
      check_systemd
      systemctl enable --now docker
      sleep 2
    fi
    verify_docker_daemon || die "无法连接 Docker daemon。"
  fi

  ensure_docker_compose
}

show_docker_result() {
  separator
  echo -e "${GREEN}${BOLD}Docker 已准备完成${NC}"
  echo
  docker --version
  docker compose version
  echo
  echo "常用命令：docker ps | docker images | docker compose version"
  echo
}

install_docker_only() {
  separator
  echo -e "${BOLD}只安装 Docker${NC}"
  echo
  ensure_docker
  show_docker_result
}

setup_caddy_repository() {
  local key_tmp list_tmp
  key_tmp="$(mktemp)"; list_tmp="$(mktemp)"
  TMP_FILES+=("$key_tmp" "$list_tmp")

  info "配置 Caddy 官方 Stable APT 仓库..."
  curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 60 \
    'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' -o "$key_tmp" \
    || die "无法下载 Caddy 仓库 GPG Key。"

  gpg --dearmor --yes < "$key_tmp" > /usr/share/keyrings/caddy-stable-archive-keyring.gpg

  curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 60 \
    'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' -o "$list_tmp" \
    || die "无法下载 Caddy APT Repository 配置。"

  install -m 0644 "$list_tmp" /etc/apt/sources.list.d/caddy-stable.list
  chmod 0644 /usr/share/keyrings/caddy-stable-archive-keyring.gpg /etc/apt/sources.list.d/caddy-stable.list
  ok "Caddy 官方 Stable 仓库配置完成。"
}

write_default_system_caddyfile() {
  mkdir -p /etc/caddy
  cat > /etc/caddy/Caddyfile <<'EOF_CADDY'
# Caddy v2 默认测试配置
#
# 反向代理示例：
# example.com {
#     reverse_proxy 127.0.0.1:8080
# }

:80 {
    respond "Caddy is running!" 200
}
EOF_CADDY
  caddy fmt --overwrite /etc/caddy/Caddyfile >/dev/null
  ok "默认 Caddyfile 已生成。"
}

validate_system_caddy() {
  info "验证 Caddy 配置..."
  caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile \
    || die "Caddyfile 配置验证失败。"
  ok "Caddyfile 配置验证通过。"
}

start_system_caddy() {
  validate_system_caddy
  systemctl enable caddy >/dev/null

  if systemctl is-active --quiet caddy; then
    info "重新加载 Caddy..."
    systemctl reload caddy
  else
    info "启动 Caddy..."
    systemctl start caddy
  fi

  sleep 2
  if ! systemctl is-active --quiet caddy; then
    journalctl -u caddy --no-pager -n 50 || true
    die "Caddy systemd 服务启动失败。"
  fi
  ok "Caddy systemd 服务运行正常。"
}

test_system_caddy_http() {
  if curl -fsS --connect-timeout 3 http://127.0.0.1 2>/dev/null | grep -q "Caddy is running"; then
    ok "HTTP 本机测试通过。"
  else
    warn "Caddy 正在运行，但测试页未返回预期内容。"
  fi
}

show_system_caddy_result() {
  separator
  echo -e "${GREEN}${BOLD}Caddy 安装完成${NC}"
  echo
  echo "部署方式 : systemd"
  echo "Caddy版本: $(caddy version)"
  echo "配置文件 : /etc/caddy/Caddyfile"
  echo "日志     : journalctl -u caddy -f"
  print_test_url
  echo
}

choose_existing_mode() {
  local kind="$1" choice=""
  CHOSEN_MODE=""

  if [[ "$AUTO_YES" == "1" ]]; then
    CHOSEN_MODE="preserve"
    info "--yes 模式：检测到已有 ${kind}，默认保留配置并更新。"
    return 0
  fi

  echo
  echo "请选择："
  echo "  1. 保留现有配置并更新 ${kind}"
  echo "  2. 备份现有配置并重新部署"
  echo "  0. 退出"

  while true; do
    prompt_read "请选择 [0-2]: " choice || die "无可用交互终端，请使用 --yes 或明确处理现有部署。"
    case "$choice" in
      1) CHOSEN_MODE="preserve"; return 0 ;;
      2) CHOSEN_MODE="reset"; return 0 ;;
      0) CHOSEN_MODE="cancel"; return 0 ;;
      *) warn "请输入 0、1 或 2。" ;;
    esac
  done
}

install_caddy_systemd() {
  separator
  echo -e "${BOLD}安装 Caddy - systemd 系统服务${NC}"
  echo

  check_systemd
  ensure_packages ca-certificates curl gnupg debian-keyring debian-archive-keyring apt-transport-https iproute2

  local package_exists=0 mode="fresh"

  if package_installed caddy; then
    package_exists=1
  elif command -v caddy >/dev/null 2>&1; then
    warn "检测到非 APT 管理的 Caddy：$(caddy version 2>/dev/null || true)"
    die "为避免覆盖自定义 Caddy / 插件版本，本脚本不会自动替换。"
  fi

  if ((package_exists == 1)); then
    warn "检测到已经安装 Caddy：$(caddy version 2>/dev/null || true)"
    choose_existing_mode Caddy
    mode="$CHOSEN_MODE"
    [[ "$mode" == "cancel" ]] && { info "已取消。"; return 0; }
  elif [[ -f /etc/caddy/Caddyfile ]]; then
    warn "发现遗留配置 /etc/caddy/Caddyfile。"
    ask_yes_no "是否备份该配置后继续安装？" "N" || die "已取消安装。"
    backup_file /etc/caddy/Caddyfile
  fi

  if [[ "$mode" == "preserve" ]]; then
    [[ -f /etc/caddy/Caddyfile ]] || die "没有找到 /etc/caddy/Caddyfile。"
    backup_file /etc/caddy/Caddyfile
    validate_system_caddy
    setup_caddy_repository
    apt_update
    apt_install caddy
    validate_system_caddy
    start_system_caddy
    handle_ufw systemd
    show_system_caddy_result
    return 0
  fi

  if ((package_exists == 1)); then
    backup_file /etc/caddy/Caddyfile
    systemctl stop caddy || true
  fi

  ensure_ports_free
  setup_caddy_repository
  apt_update
  apt_install caddy

  [[ "$mode" == "fresh" && -f /etc/caddy/Caddyfile ]] && backup_file /etc/caddy/Caddyfile
  write_default_system_caddyfile
  start_system_caddy
  test_system_caddy_http
  handle_ufw systemd
  show_system_caddy_result
}

caddy_compose_valid() {
  [[ -f "$CADDY_DIR/docker-compose.yml" ]] || return 1
  (cd "$CADDY_DIR" && docker compose -f docker-compose.yml config >/dev/null 2>&1)
}

caddy_compose_has_service() {
  [[ -f "$CADDY_DIR/docker-compose.yml" ]] || return 1
  (cd "$CADDY_DIR" && docker compose -f docker-compose.yml config --services 2>/dev/null | grep -qx caddy)
}

stop_existing_caddy_compose() {
  caddy_compose_valid && caddy_compose_has_service || return 0
  info "停止旧 Caddy 容器..."
  (cd "$CADDY_DIR" && docker compose -f docker-compose.yml stop caddy || true)
  (cd "$CADDY_DIR" && docker compose -f docker-compose.yml rm -f caddy || true)
}

move_caddy_directory_to_backup() {
  [[ -e "$CADDY_DIR" ]] || return 0
  local backup="${CADDY_DIR}.bak.$(timestamp)"
  mv -- "$CADDY_DIR" "$backup"
  ok "原 Caddy 目录已完整备份：$backup"
}

ensure_no_caddy_container_conflict() {
  docker ps -a --format '{{.Names}}' | grep -qx caddy || return 0
  warn "检测到已经存在名称为 caddy 的 Docker 容器。"
  docker ps -a --filter 'name=^/caddy$' --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
  ask_yes_no "是否停止并删除这个 caddy 容器？" "N" || die "Docker 容器名称冲突，无法继续。"
  docker rm -f caddy
  ok "旧 caddy 容器已删除。"
}

create_caddy_network() {
  if docker network inspect "$CADDY_NETWORK" >/dev/null 2>&1; then
    ok "Docker 网络 '$CADDY_NETWORK' 已存在。"
  else
    docker network create "$CADDY_NETWORK" >/dev/null
    ok "已创建 Docker 网络：$CADDY_NETWORK"
  fi
}

write_docker_caddyfile() {
  mkdir -p "$CADDY_DIR/conf" "$CADDY_DIR/data" "$CADDY_DIR/config" "$CADDY_DIR/site"
  cat > "$CADDY_DIR/conf/Caddyfile" <<'EOF_CADDY'
# Caddy v2 - Docker Compose 默认测试配置
#
# 同一 caddy Docker 网络中的服务：
# example.com {
#     reverse_proxy app:8080
# }
#
# 宿主机服务：
# example.com {
#     reverse_proxy host.docker.internal:8080
# }

:80 {
    respond "Caddy is running!" 200
}
EOF_CADDY
  chmod 0644 "$CADDY_DIR/conf/Caddyfile"
  ok "Docker Caddyfile 已生成。"
}

write_docker_compose() {
  cat > "$CADDY_DIR/docker-compose.yml" <<EOF_COMPOSE
services:
  caddy:
    image: ${CADDY_IMAGE}
    container_name: caddy
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - ./conf:/etc/caddy:ro
      - ./data:/data
      - ./config:/config
      - ./site:/srv:ro
    networks:
      - caddy

networks:
  caddy:
    external: true
    name: ${CADDY_NETWORK}
EOF_COMPOSE
  chmod 0644 "$CADDY_DIR/docker-compose.yml"
  ok "docker-compose.yml 已生成。"
}

compose_validate_file() {
  (cd "$CADDY_DIR" && docker compose -f docker-compose.yml config >/dev/null)
}

validate_caddy_with_compose_image() {
  info "使用目标镜像预验证 Caddyfile..."
  (
    cd "$CADDY_DIR"
    docker compose -f docker-compose.yml run --rm --no-deps caddy \
      validate --config /etc/caddy/Caddyfile --adapter caddyfile
  )
  ok "目标镜像 Caddyfile 预验证通过。"
}

container_running() {
  local cid
  cid="$(cd "$CADDY_DIR" && docker compose -f docker-compose.yml ps -q caddy)"
  [[ -n "$cid" ]] || return 1
  [[ "$(docker inspect -f '{{.State.Running}}' "$cid" 2>/dev/null || true)" == "true" ]]
}

validate_running_caddy() {
  (
    cd "$CADDY_DIR"
    docker compose -f docker-compose.yml exec -T caddy \
      caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
  )
}

show_caddy_logs() {
  (cd "$CADDY_DIR" && docker compose -f docker-compose.yml logs --tail=100 caddy) || true
}

verify_docker_caddy() {
  compose_validate_file || die "Docker Compose 配置验证失败。"
  ok "Docker Compose 配置验证通过。"

  info "拉取 Caddy 镜像：$CADDY_IMAGE"
  (cd "$CADDY_DIR" && docker compose -f docker-compose.yml pull caddy)

  validate_caddy_with_compose_image || die "新镜像无法通过当前 Caddyfile 验证。"

  info "启动 Caddy..."
  if ! (cd "$CADDY_DIR" && docker compose -f docker-compose.yml up -d caddy); then
    show_caddy_logs
    die "Caddy Docker 容器启动失败。"
  fi

  sleep 3
  container_running || { show_caddy_logs; die "Caddy Docker 容器没有正常运行。"; }
  validate_running_caddy || { show_caddy_logs; die "运行中的 Caddy 配置验证失败。"; }
  ok "Caddy Docker 容器运行正常。"
}

test_docker_caddy_http() {
  if curl -fsS --connect-timeout 3 http://127.0.0.1 2>/dev/null | grep -q "Caddy is running"; then
    ok "HTTP 本机测试通过。"
  else
    warn "Caddy 容器正在运行，但测试页未返回预期内容。"
  fi
}

update_existing_docker_caddy() {
  cd "$CADDY_DIR"
  caddy_compose_valid || die "现有 docker-compose.yml 无法通过配置验证。"
  caddy_compose_has_service || die "现有 Compose 中没有名为 caddy 的服务。"

  backup_file "$CADDY_DIR/docker-compose.yml"
  [[ -f "$CADDY_DIR/conf/Caddyfile" ]] && backup_file "$CADDY_DIR/conf/Caddyfile"

  local old_cid="" old_image_id="" old_image_ref="" rollback_tag=""
  old_cid="$(docker compose -f docker-compose.yml ps -q caddy 2>/dev/null || true)"
  if [[ -n "$old_cid" ]]; then
    old_image_id="$(docker inspect -f '{{.Image}}' "$old_cid" 2>/dev/null || true)"
    old_image_ref="$(docker inspect -f '{{.Config.Image}}' "$old_cid" 2>/dev/null || true)"
  fi

  if [[ -n "$old_image_id" ]]; then
    rollback_tag="caddy-local-rollback:$(date +%s)"
    docker image tag "$old_image_id" "$rollback_tag"
    info "已保留升级前镜像用于失败回滚。"
  fi

  info "拉取最新 Caddy 镜像..."
  docker compose -f docker-compose.yml pull caddy

  if ! validate_caddy_with_compose_image; then
    [[ -n "$rollback_tag" ]] && docker image rm "$rollback_tag" >/dev/null 2>&1 || true
    die "新 Caddy 镜像与当前配置不兼容，已取消升级；旧容器未被替换。"
  fi

  info "更新 Caddy 容器..."
  if ! docker compose -f docker-compose.yml up -d --no-deps caddy; then
    warn "更新失败，准备回滚..."
  fi

  sleep 3

  if ! container_running || ! validate_running_caddy; then
    show_caddy_logs
    if [[ -n "$rollback_tag" ]]; then
      warn "新版本运行检查失败，正在自动回滚到升级前镜像..."
      [[ -n "$old_image_ref" ]] || old_image_ref="$CADDY_IMAGE"
      docker image tag "$rollback_tag" "$old_image_ref"
      docker compose -f docker-compose.yml up -d --no-deps --force-recreate --pull never caddy
      sleep 3
      if container_running && validate_running_caddy; then
        ok "已成功回滚到升级前版本。"
        warn "本次升级未完成，当前继续使用升级前版本。"
        docker image rm "$rollback_tag" >/dev/null 2>&1 || true
        return 0
      fi
      error "自动回滚后 Caddy 仍未恢复，请检查日志。"
    fi
    die "Caddy 更新失败。"
  fi

  [[ -n "$rollback_tag" ]] && docker image rm "$rollback_tag" >/dev/null 2>&1 || true
  ok "现有 Caddy Docker 部署更新完成。"
}

show_docker_caddy_result() {
  separator
  echo -e "${GREEN}${BOLD}Caddy Docker Compose 部署完成${NC}"
  echo
  echo "部署方式 : Docker Compose"
  echo "目录     : $CADDY_DIR"
  local running_image=""
  running_image="$(cd "$CADDY_DIR" && docker compose -f docker-compose.yml ps -q caddy 2>/dev/null | xargs -r docker inspect -f '{{.Config.Image}}' 2>/dev/null || true)"
  echo "镜像     : ${running_image:-$CADDY_IMAGE}"
  echo "网络     : $CADDY_NETWORK"
  echo -n "Caddy版本: "
  (cd "$CADDY_DIR" && docker compose -f docker-compose.yml exec -T caddy caddy version 2>/dev/null) || echo "未知"
  print_test_url
  echo
  echo "常用命令："
  echo "  cd $CADDY_DIR"
  echo "  docker compose ps"
  echo "  docker compose logs -f caddy"
  echo "  docker compose restart caddy"
  echo
}

install_caddy_docker() {
  separator
  echo -e "${BOLD}安装 Caddy - Docker Compose${NC}"
  echo

  ensure_docker
  ensure_packages curl iproute2

  local mode="fresh"

  if [[ -d "$CADDY_DIR" ]] && [[ -n "$(find "$CADDY_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    warn "检测到已有目录：$CADDY_DIR"

    if caddy_compose_valid && caddy_compose_has_service; then
      choose_existing_mode Caddy
      mode="$CHOSEN_MODE"
      [[ "$mode" == "cancel" ]] && { info "已取消。"; return 0; }
    else
      warn "$CADDY_DIR 不是本脚本能够识别的标准 Caddy Compose 部署。"
      ask_yes_no "是否完整备份该目录后重新部署？" "N" || die "已取消部署。"
      mode="reset"
    fi
  fi

  if [[ "$mode" == "preserve" ]]; then
    update_existing_docker_caddy
    handle_ufw docker
    show_docker_caddy_result
    return 0
  fi

  if [[ "$mode" == "reset" ]]; then
    caddy_compose_valid && caddy_compose_has_service && stop_existing_caddy_compose || true
    move_caddy_directory_to_backup
  fi

  ensure_no_caddy_container_conflict
  ensure_ports_free
  create_caddy_network
  mkdir -p "$CADDY_DIR"
  write_docker_caddyfile
  write_docker_compose
  verify_docker_caddy
  test_docker_caddy_http
  handle_ufw docker
  show_docker_caddy_result
}

main_menu() {
  separator
  echo -e "${CYAN}${BOLD}        Docker + Caddy v2 一键部署脚本${NC}"
  echo
  echo "支持：Debian / Ubuntu"
  echo
  echo "  1. 只安装 Docker"
  echo "  2. 安装 Caddy - systemd"
  echo "  3. 安装 Caddy - Docker Compose"
  echo "  0. 退出"
  echo

  local choice=""
  while true; do
    prompt_read "请选择 [0-3]: " choice || die "无可用交互终端，请指定 ACTION，例如：$0 caddy-docker --yes"
    case "$choice" in
      1) install_docker_only; return ;;
      2) install_caddy_systemd; return ;;
      3) install_caddy_docker; return ;;
      0) info "退出。"; return ;;
      *) warn "请输入 0、1、2 或 3。" ;;
    esac
  done
}

main() {
  parse_args "$@"
  check_root
  check_os
  check_architecture
  show_system_info

  case "$ACTION" in
    docker) install_docker_only ;;
    caddy-systemd) install_caddy_systemd ;;
    caddy-docker) install_caddy_docker ;;
    "") main_menu ;;
    *) die "内部错误：未知 ACTION $ACTION" ;;
  esac
}

main "$@"
