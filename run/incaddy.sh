#!/usr/bin/env bash

# ==============================================================================
#
#  Docker + Caddy v2 一键部署脚本
#
#  支持系统：
#    - Debian
#    - Ubuntu
#
#  主菜单：
#    1. 只安装 Docker
#    2. 安装 Caddy - systemd
#    3. 安装 Caddy - Docker Compose
#
#  Docker 安装策略：
#
#    中国大陆：
#      get.docker.com + --mirror Aliyun
#
#      等价命令：
#      curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
#
#      如果 Aliyun 安装失败：
#      自动回退到 get.docker.com 官方默认源
#
#    海外 / 其他地区：
#      get.docker.com 官方默认源
#
#  注意：
#    --mirror Aliyun 加速的是 Docker CE 软件包下载，
#    不等于 Docker Hub registry-mirrors。
#
#    本脚本不会自动写入公共 Docker Hub 镜像源，
#    避免镜像源失效导致 Docker 无法正常拉取镜像。
#
#  Caddy Docker Compose 默认目录：
#    /opt/caddy
#
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'


# ==============================================================================
# 全局配置
# ==============================================================================

CADDY_DIR="/opt/caddy"
CADDY_NETWORK="caddy"
CADDY_IMAGE="caddy:2-alpine"

DOCKER_INSTALL_URL="https://get.docker.com"

REGION_KIND=""
DETECTED_COUNTRY=""

OS_ID=""
OS_NAME=""
OS_VERSION=""
ARCH=""


# ==============================================================================
# 颜色
# ==============================================================================

if [[ -t 1 ]]; then

    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'

else

    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    NC=''

fi


# ==============================================================================
# 输出函数
# ==============================================================================

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

ok() {
    echo -e "${GREEN}[ OK ]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

die() {
    error "$*"
    exit 1
}

separator() {
    echo
    echo "============================================================"
    echo
}

timestamp() {
    date '+%Y%m%d-%H%M%S'
}


# ==============================================================================
# 错误处理
# ==============================================================================

on_error() {

    local rc=$?
    local line="${BASH_LINENO[0]:-${LINENO}}"

    echo
    error "脚本执行过程中发生错误。"
    error "退出代码：${rc}"
    error "大致位置：第 ${line} 行"

    exit "$rc"
}

trap on_error ERR


# ==============================================================================
# 用户输入
# ==============================================================================

prompt_read() {

    local prompt="$1"
    local var_name="$2"
    local value=""

    if [[ -r /dev/tty ]]; then

        IFS= read -r -p "$prompt" value </dev/tty || true

    else

        IFS= read -r -p "$prompt" value || true

    fi

    printf -v "$var_name" '%s' "$value"
}


ask_yes_no() {

    local prompt="$1"
    local default="${2:-Y}"
    local answer=""
    local suffix=""

    if [[ "$default" == "Y" ]]; then
        suffix="[Y/n]"
    else
        suffix="[y/N]"
    fi

    while true; do

        prompt_read "$prompt $suffix " answer

        if [[ -z "$answer" ]]; then
            answer="$default"
        fi

        case "${answer,,}" in

            y|yes)
                return 0
                ;;

            n|no)
                return 1
                ;;

            *)
                warn "请输入 y 或 n。"
                ;;

        esac

    done
}


# ==============================================================================
# ROOT 检测
# ==============================================================================

check_root() {

    if [[ "${EUID}" -ne 0 ]]; then

        die "请使用 root 用户执行，或使用 sudo ./脚本名.sh"

    fi
}


# ==============================================================================
# 系统检测
# ==============================================================================

check_os() {

    [[ -f /etc/os-release ]] || \
        die "无法读取 /etc/os-release。"

    # shellcheck disable=SC1091
    . /etc/os-release

    OS_ID="${ID:-unknown}"
    OS_NAME="${PRETTY_NAME:-unknown}"
    OS_VERSION="${VERSION_ID:-unknown}"

    case "${OS_ID,,}" in

        debian|ubuntu)
            ;;

        *)
            die "当前只支持 Debian / Ubuntu，检测到：${OS_NAME}"
            ;;

    esac

    ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
}


check_architecture() {

    case "$ARCH" in

        amd64|arm64)
            ok "CPU 架构受支持：$ARCH"
            ;;

        *)
            warn "当前架构为：$ARCH"
            warn "脚本不会阻止安装，但主要测试目标为 amd64 / arm64。"
            ;;

    esac
}


check_systemd() {

    command -v systemctl >/dev/null 2>&1 || \
        die "未检测到 systemctl。"

    [[ -d /run/systemd/system ]] || \
        die "当前系统似乎没有运行 systemd。"
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


# ==============================================================================
# APT
# ==============================================================================

package_installed() {

    dpkg-query \
        -W \
        -f='${Status}' \
        "$1" \
        2>/dev/null |
        grep -q "install ok installed"
}


ensure_packages() {

    local missing=()
    local package=""

    for package in "$@"; do

        if ! package_installed "$package"; then

            missing+=("$package")

        fi

    done

    if (( ${#missing[@]} == 0 )); then

        ok "前置依赖检查通过。"
        return 0

    fi

    warn "检测到缺少以下依赖："
    echo

    for package in "${missing[@]}"; do
        echo "  - $package"
    done

    echo

    if ! ask_yes_no "是否自动安装这些依赖？" "Y"; then

        die "缺少必要依赖，无法继续。"

    fi

    info "更新 APT 软件包索引..."

    apt-get update

    info "安装依赖..."

    DEBIAN_FRONTEND=noninteractive \
        apt-get install -y "${missing[@]}"

    ok "依赖安装完成。"
}


# ==============================================================================
# 文件备份
# ==============================================================================

backup_file() {

    local file="$1"

    [[ -e "$file" ]] || return 0

    local backup="${file}.bak.$(timestamp)"

    cp -a "$file" "$backup"

    ok "已备份：$backup"
}


# ==============================================================================
# 端口检测
# ==============================================================================

get_port_conflicts() {

    ss -H -lntup 2>/dev/null |
        awk '
            $5 ~ /:80$/ ||
            $5 ~ /:443$/ {
                print
            }
        ' || true
}


ensure_ports_free() {

    local conflicts=""

    conflicts="$(get_port_conflicts)"

    if [[ -z "$conflicts" ]]; then

        ok "80 / 443 端口未发现冲突。"
        return 0

    fi

    warn "检测到 80 或 443 端口已被占用："

    echo
    echo "$conflicts"
    echo

    die "请先处理 80 / 443 端口占用后重新运行脚本。"
}


# ==============================================================================
# VPS 地区检测
#
# 可手动覆盖：
#
#   CADDY_INSTALL_REGION=CN ./install.sh
#
#   CADDY_INSTALL_REGION=GLOBAL ./install.sh
#
# ==============================================================================

detect_region() {

    local country=""

    if [[ -n "${CADDY_INSTALL_REGION:-}" ]]; then

        case "${CADDY_INSTALL_REGION^^}" in

            CN)

                REGION_KIND="CN"
                DETECTED_COUNTRY="CN"

                warn "已通过环境变量强制指定：中国大陆。"

                return
                ;;

            GLOBAL)

                REGION_KIND="GLOBAL"
                DETECTED_COUNTRY="MANUAL"

                warn "已通过环境变量强制指定：海外 / 其他地区。"

                return
                ;;

            *)

                warn "忽略无效参数："
                warn "CADDY_INSTALL_REGION=${CADDY_INSTALL_REGION}"
                ;;

        esac

    fi

    info "检测 VPS 公网出口地区..."

    # --------------------------------------------------------------------------
    # 第一检测源：Cloudflare
    # --------------------------------------------------------------------------

    country="$(
        curl \
            -fsSL \
            --connect-timeout 5 \
            --max-time 8 \
            https://www.cloudflare.com/cdn-cgi/trace \
            2>/dev/null |
        awk -F= '
            $1 == "loc" {
                gsub(/[[:space:]\r]/, "", $2);
                print toupper($2);
                exit
            }
        ' || true
    )"

    # --------------------------------------------------------------------------
    # 第二检测源
    # --------------------------------------------------------------------------

    if [[ ! "$country" =~ ^[A-Z]{2}$ ]]; then

        country="$(
            curl \
                -fsSL \
                --connect-timeout 5 \
                --max-time 8 \
                https://ipapi.co/country/ \
                2>/dev/null |
            tr -d '[:space:]' |
            tr '[:lower:]' '[:upper:]' || true
        )"

    fi

    # --------------------------------------------------------------------------
    # 判断
    # --------------------------------------------------------------------------

    if [[ "$country" == "CN" ]]; then

        REGION_KIND="CN"
        DETECTED_COUNTRY="CN"

        ok "检测到 VPS 公网出口：中国大陆。"

    elif [[ "$country" =~ ^[A-Z]{2}$ ]]; then

        REGION_KIND="GLOBAL"
        DETECTED_COUNTRY="$country"

        ok "检测到 VPS 国家 / 地区代码：$country"

    else

        warn "无法可靠判断 VPS 所在地区。"

        echo
        echo "请选择："
        echo
        echo "  1. 中国大陆"
        echo "  2. 海外 / 香港 / 澳门 / 台湾 / 其他地区"
        echo

        local choice=""

        while true; do

            prompt_read "请选择 [1-2]: " choice

            case "$choice" in

                1)

                    REGION_KIND="CN"
                    DETECTED_COUNTRY="MANUAL-CN"

                    break
                    ;;

                2)

                    REGION_KIND="GLOBAL"
                    DETECTED_COUNTRY="MANUAL-GLOBAL"

                    break
                    ;;

                *)

                    warn "请输入 1 或 2。"
                    ;;

            esac

        done

    fi
}


# ==============================================================================
# 获取公网 IP
# ==============================================================================

get_public_ip() {

    curl \
        -fsSL \
        --connect-timeout 5 \
        --max-time 8 \
        https://api64.ipify.org \
        2>/dev/null || true
}


print_test_url() {

    local ip=""

    ip="$(get_public_ip)"

    [[ -n "$ip" ]] || return 0

    if [[ "$ip" == *:* ]]; then

        echo "测试地址 : http://[$ip]"

    else

        echo "测试地址 : http://$ip"

    fi
}


# ==============================================================================
# UFW
# ==============================================================================

handle_ufw() {

    if ! command -v ufw >/dev/null 2>&1; then
        return 0
    fi

    if ! ufw status 2>/dev/null |
        grep -q '^Status: active'; then

        return 0

    fi

    warn "检测到 UFW 已启用。"

    echo
    echo "Caddy 通常需要开放："
    echo
    echo "  TCP 80"
    echo "  TCP 443"
    echo "  UDP 443    # HTTP/3"
    echo

    if ask_yes_no \
        "是否自动添加这些 UFW 规则？" \
        "N"; then

        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow 443/udp

        ok "UFW 规则添加完成。"

    else

        warn "未修改 UFW。"

    fi
}


# ==============================================================================
#
# Docker 安装
#
# ==============================================================================


# ==============================================================================
# 下载并执行 Docker 官方安装脚本
#
# 参数：
#
#   aliyun
#   official
#
# ==============================================================================

run_docker_install_script() {

    local mode="$1"
    local tmp=""

    tmp="$(mktemp)"

    info "下载 Docker 官方安装脚本..."

    if ! curl \
        -fsSL \
        --retry 3 \
        --retry-delay 2 \
        --connect-timeout 10 \
        --max-time 120 \
        "$DOCKER_INSTALL_URL" \
        -o "$tmp"; then

        rm -f "$tmp"

        return 1
    fi

    if [[ ! -s "$tmp" ]]; then

        rm -f "$tmp"

        warn "下载到的 Docker 安装脚本为空。"

        return 1
    fi

    case "$mode" in

        aliyun)

            info "使用 Docker 官方脚本 + Aliyun Mirror..."

            echo
            echo "软件源："
            echo "  https://mirrors.aliyun.com/docker-ce"
            echo

            if bash "$tmp" --mirror Aliyun; then

                rm -f "$tmp"

                return 0

            else

                rm -f "$tmp"

                return 1

            fi
            ;;

        official)

            info "使用 Docker 官方默认软件源..."

            if bash "$tmp"; then

                rm -f "$tmp"

                return 0

            else

                rm -f "$tmp"

                return 1

            fi
            ;;

        *)

            rm -f "$tmp"

            die "未知 Docker 安装模式：$mode"
            ;;

    esac
}


# ==============================================================================
# 验证 Docker daemon
# ==============================================================================

verify_docker_daemon() {

    if docker info >/dev/null 2>&1; then

        ok "Docker daemon 运行正常。"
        return 0

    fi

    error "Docker daemon 无法正常连接。"

    if command -v journalctl >/dev/null 2>&1; then

        echo

        journalctl \
            -u docker \
            --no-pager \
            -n 50 || true

    fi

    return 1
}


# ==============================================================================
# 安装 Docker Engine
# ==============================================================================

install_docker_engine() {

    check_systemd

    detect_region

    separator

    echo -e "${BOLD}Docker Engine 安装${NC}"
    echo

    # --------------------------------------------------------------------------
    # 中国大陆
    # --------------------------------------------------------------------------

    if [[ "$REGION_KIND" == "CN" ]]; then

        echo "地区     : 中国大陆"
        echo "首选方案 : Docker 官方脚本 + Aliyun Mirror"
        echo "兜底方案 : Docker 官方默认源"

        echo

        if run_docker_install_script "aliyun"; then

            ok "Docker 已通过 Aliyun 软件源安装完成。"

        else

            warn "Aliyun 软件源安装失败。"
            warn "自动回退 Docker 官方默认源..."

            echo

            if ! run_docker_install_script "official"; then

                die "Aliyun 和 Docker 官方安装方式均失败。"

            fi

            ok "Docker 已通过官方默认源安装完成。"

        fi

    # --------------------------------------------------------------------------
    # 海外
    # --------------------------------------------------------------------------

    else

        echo "地区     : ${DETECTED_COUNTRY:-海外 / 其他地区}"
        echo "安装方式 : Docker 官方默认源"

        echo

        if ! run_docker_install_script "official"; then

            die "Docker 官方安装失败。"

        fi

        ok "Docker 官方安装完成。"

    fi


    # --------------------------------------------------------------------------
    # 启动 Docker
    # --------------------------------------------------------------------------

    info "启动 Docker 服务..."

    systemctl enable --now docker

    sleep 2

    if ! verify_docker_daemon; then

        die "Docker 已安装，但服务启动失败。"

    fi
}


# ==============================================================================
# Docker Compose Plugin
# ==============================================================================

ensure_docker_compose() {

    if docker compose version >/dev/null 2>&1; then

        ok "Docker Compose Plugin 已安装。"

        return 0
    fi

    warn "未检测到 Docker Compose Plugin。"

    echo

    if ! ask_yes_no \
        "是否自动安装 Docker Compose Plugin？" \
        "Y"; then

        die "Docker Compose Plugin 不存在。"
    fi

    info "更新 APT 软件包索引..."

    apt-get update

    # --------------------------------------------------------------------------
    # Docker 官方仓库
    # --------------------------------------------------------------------------

    if apt-cache show docker-compose-plugin \
        >/dev/null 2>&1; then

        info "安装 docker-compose-plugin..."

        DEBIAN_FRONTEND=noninteractive \
            apt-get install -y docker-compose-plugin

    # --------------------------------------------------------------------------
    # Debian / Ubuntu 自带包
    # --------------------------------------------------------------------------

    elif apt-cache show docker-compose-v2 \
        >/dev/null 2>&1; then

        info "安装 docker-compose-v2..."

        DEBIAN_FRONTEND=noninteractive \
            apt-get install -y docker-compose-v2

    else

        die "当前 APT 软件源中没有找到 Docker Compose v2。"

    fi

    if ! docker compose version >/dev/null 2>&1; then

        die "Docker Compose 安装完成后仍无法正常运行。"

    fi

    ok "Docker Compose Plugin 安装完成。"
}


# ==============================================================================
# 检测 / 准备 Docker
#
# Caddy Docker Compose 和“只安装 Docker”共用
#
# ==============================================================================

ensure_docker() {

    ensure_packages \
        ca-certificates \
        curl \
        iproute2

    # --------------------------------------------------------------------------
    # Docker 不存在
    # --------------------------------------------------------------------------

    if ! command -v docker >/dev/null 2>&1; then

        warn "未检测到 Docker Engine。"

        echo

        if ! ask_yes_no \
            "是否自动安装 Docker Engine？" \
            "Y"; then

            die "Docker 不存在，已取消。"

        fi

        install_docker_engine

    # --------------------------------------------------------------------------
    # Docker 已存在
    # --------------------------------------------------------------------------

    else

        ok "检测到 Docker Engine："

        echo
        docker --version || true
        echo

        if ! docker info >/dev/null 2>&1; then

            warn "Docker 已安装，但 Docker daemon 当前不可用。"

            echo

            if ask_yes_no \
                "是否启动 Docker 并设置开机启动？" \
                "Y"; then

                check_systemd

                systemctl enable --now docker

                sleep 2

            else

                die "Docker daemon 未运行。"

            fi

        fi

        if ! verify_docker_daemon; then

            die "无法连接 Docker daemon。"

        fi

    fi

    ensure_docker_compose
}


# ==============================================================================
# Docker 安装结果
# ==============================================================================

show_docker_result() {

    separator

    echo -e "${GREEN}${BOLD}Docker 已准备完成${NC}"

    echo

    echo "Docker："
    docker --version

    echo

    echo "Docker Compose："
    docker compose version

    echo

    echo "Docker 服务："

    if systemctl is-active --quiet docker 2>/dev/null; then
        echo "  running"
    else
        echo "  unknown"
    fi

    echo
    echo "常用命令："
    echo
    echo "  docker ps"
    echo "  docker ps -a"
    echo "  docker images"
    echo "  docker compose version"
    echo
    echo "  systemctl status docker"
    echo "  systemctl restart docker"
    echo "  journalctl -u docker -f"

    echo
}


# ==============================================================================
# 菜单功能：只安装 Docker
# ==============================================================================

install_docker_only() {

    separator

    echo -e "${BOLD}只安装 Docker${NC}"
    echo

    ensure_docker

    show_docker_result
}


# ==============================================================================
#
# Caddy systemd
#
# ==============================================================================


# ==============================================================================
# Caddy 官方 APT Repository
# ==============================================================================

setup_caddy_repository() {

    local key_tmp=""
    local list_tmp=""

    key_tmp="$(mktemp)"
    list_tmp="$(mktemp)"

    info "配置 Caddy 官方 Stable APT 仓库..."

    if ! curl \
        -1fsSL \
        --retry 3 \
        --retry-delay 2 \
        --connect-timeout 10 \
        --max-time 60 \
        'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
        -o "$key_tmp"; then

        rm -f "$key_tmp" "$list_tmp"

        die "无法下载 Caddy 仓库 GPG Key。"
    fi

    gpg \
        --dearmor \
        --yes \
        < "$key_tmp" \
        > /usr/share/keyrings/caddy-stable-archive-keyring.gpg

    if ! curl \
        -1fsSL \
        --retry 3 \
        --retry-delay 2 \
        --connect-timeout 10 \
        --max-time 60 \
        'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
        -o "$list_tmp"; then

        rm -f "$key_tmp" "$list_tmp"

        die "无法下载 Caddy APT Repository 配置。"
    fi

    install \
        -m 0644 \
        "$list_tmp" \
        /etc/apt/sources.list.d/caddy-stable.list

    chmod 0644 \
        /usr/share/keyrings/caddy-stable-archive-keyring.gpg

    chmod 0644 \
        /etc/apt/sources.list.d/caddy-stable.list

    rm -f "$key_tmp" "$list_tmp"

    ok "Caddy 官方 Stable 仓库配置完成。"
}


# ==============================================================================
# 默认 Caddyfile
# ==============================================================================

write_default_system_caddyfile() {

    mkdir -p /etc/caddy

    cat > /etc/caddy/Caddyfile <<'EOF'
# ==============================================================================
# Caddy v2
# ==============================================================================
#
# 当前默认配置用于测试 Caddy 是否安装成功。
#
# 访问：
#
#   http://服务器IP
#
# 应返回：
#
#   Caddy is running!
#
# ------------------------------------------------------------------------------
#
# 反向代理示例：
#
# example.com {
#     reverse_proxy 127.0.0.1:8080
# }
#
# ------------------------------------------------------------------------------
#
# 多域名示例：
#
# app.example.com {
#     reverse_proxy 127.0.0.1:3000
# }
#
# api.example.com {
#     reverse_proxy 127.0.0.1:8080
# }
#
# ==============================================================================

:80 {
    respond "Caddy is running!" 200
}
EOF

    caddy fmt \
        --overwrite \
        /etc/caddy/Caddyfile \
        >/dev/null

    ok "默认 Caddyfile 已生成。"
}


# ==============================================================================
# Caddy systemd 配置验证
# ==============================================================================

validate_system_caddy() {

    info "验证 Caddy 配置..."

    if ! caddy validate \
        --config /etc/caddy/Caddyfile \
        --adapter caddyfile; then

        die "Caddyfile 配置验证失败。"

    fi

    ok "Caddyfile 配置验证通过。"
}


# ==============================================================================
# 启动 Caddy systemd
# ==============================================================================

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

        error "Caddy 服务启动失败。"

        journalctl \
            -u caddy \
            --no-pager \
            -n 50 || true

        die "Caddy systemd 服务启动失败。"

    fi

    ok "Caddy systemd 服务运行正常。"
}


# ==============================================================================
# Caddy systemd 测试
# ==============================================================================

test_system_caddy_http() {

    if curl \
        -fsS \
        --connect-timeout 3 \
        http://127.0.0.1 \
        2>/dev/null |
        grep -q "Caddy is running"; then

        ok "HTTP 本机测试通过。"

    else

        warn "Caddy 服务正在运行，但 HTTP 本机测试未返回预期内容。"

    fi
}


# ==============================================================================
# Caddy systemd 结果
# ==============================================================================

show_system_caddy_result() {

    separator

    echo -e "${GREEN}${BOLD}Caddy 安装完成${NC}"

    echo

    echo "部署方式 : systemd"
    echo "Caddy版本: $(caddy version)"
    echo "配置文件 : /etc/caddy/Caddyfile"
    echo "日志     : journalctl -u caddy -f"

    echo

    print_test_url

    echo
    echo "常用命令："
    echo
    echo "  systemctl status caddy"
    echo "  systemctl restart caddy"
    echo "  systemctl reload caddy"
    echo
    echo "  journalctl -u caddy -f"
    echo

    echo "验证配置："
    echo
    echo "  caddy validate \\"
    echo "    --config /etc/caddy/Caddyfile \\"
    echo "    --adapter caddyfile"
    echo

    echo "格式化配置："
    echo
    echo "  caddy fmt --overwrite /etc/caddy/Caddyfile"

    echo
}


# ==============================================================================
# 安装 Caddy systemd
# ==============================================================================

install_caddy_systemd() {

    separator

    echo -e "${BOLD}安装 Caddy - systemd 系统服务${NC}"
    echo

    check_systemd

    ensure_packages \
        ca-certificates \
        curl \
        gnupg \
        debian-keyring \
        debian-archive-keyring \
        apt-transport-https \
        iproute2

    local package_exists=0
    local mode="fresh"
    local choice=""

    # --------------------------------------------------------------------------
    # 检查是否通过 APT 安装
    # --------------------------------------------------------------------------

    if package_installed caddy; then

        package_exists=1

    # --------------------------------------------------------------------------
    # 检测自定义 Caddy
    # --------------------------------------------------------------------------

    elif command -v caddy >/dev/null 2>&1; then

        warn "检测到 Caddy 二进制文件，但它不是由 Debian APT 包管理器安装。"

        echo
        caddy version || true
        echo

        die "为避免覆盖自定义 Caddy / 插件版本，本脚本不会自动替换。"

    fi


    # --------------------------------------------------------------------------
    # 已安装 Caddy
    # --------------------------------------------------------------------------

    if (( package_exists == 1 )); then

        warn "检测到已经安装 Caddy。"

        echo
        echo "当前版本："
        echo
        caddy version || true

        echo
        echo "请选择："
        echo
        echo "  1. 保留现有 Caddyfile 并更新 Caddy"
        echo "  2. 备份现有配置并重新部署"
        echo "  0. 退出"
        echo

        while true; do

            prompt_read "请选择 [0-2]: " choice

            case "$choice" in

                1)

                    mode="preserve"
                    break
                    ;;

                2)

                    mode="reset"
                    break
                    ;;

                0)

                    info "已取消。"
                    return 0
                    ;;

                *)

                    warn "请输入 0、1 或 2。"
                    ;;

            esac

        done

    # --------------------------------------------------------------------------
    # 未安装，但存在遗留配置
    # --------------------------------------------------------------------------

    elif [[ -f /etc/caddy/Caddyfile ]]; then

        warn "虽然没有检测到 Caddy APT 包，但发现已有配置："
        echo
        echo "  /etc/caddy/Caddyfile"
        echo

        if ask_yes_no \
            "是否备份该配置后继续安装？" \
            "N"; then

            backup_file /etc/caddy/Caddyfile

        else

            die "已取消安装。"

        fi

    fi


    # ==========================================================================
    # 保留配置更新
    # ==========================================================================

    if [[ "$mode" == "preserve" ]]; then

        [[ -f /etc/caddy/Caddyfile ]] || \
            die "没有找到 /etc/caddy/Caddyfile。"

        backup_file /etc/caddy/Caddyfile

        # 先验证现有配置
        validate_system_caddy

        setup_caddy_repository

        apt-get update

        DEBIAN_FRONTEND=noninteractive \
            apt-get install -y caddy

        validate_system_caddy

        start_system_caddy

        handle_ufw

        show_system_caddy_result

        return 0
    fi


    # ==========================================================================
    # 全新 / 重装
    # ==========================================================================

    if (( package_exists == 1 )); then

        backup_file /etc/caddy/Caddyfile

        info "停止现有 Caddy 服务..."

        systemctl stop caddy || true

    fi

    ensure_ports_free

    setup_caddy_repository

    info "更新 APT 软件包索引..."

    apt-get update

    info "安装 Caddy..."

    DEBIAN_FRONTEND=noninteractive \
        apt-get install -y caddy

    # --------------------------------------------------------------------------
    # APT 安装可能生成默认配置
    # --------------------------------------------------------------------------

    if [[ "$mode" == "fresh" ]] &&
       [[ -f /etc/caddy/Caddyfile ]]; then

        backup_file /etc/caddy/Caddyfile

    fi

    write_default_system_caddyfile

    start_system_caddy

    test_system_caddy_http

    handle_ufw

    show_system_caddy_result
}


# ==============================================================================
#
# Caddy Docker Compose
#
# ==============================================================================


# ==============================================================================
# 判断 /opt/caddy 是否为可识别 Compose
# ==============================================================================

caddy_compose_valid() {

    [[ -f "$CADDY_DIR/docker-compose.yml" ]] || \
        return 1

    (
        cd "$CADDY_DIR"

        docker compose \
            -f docker-compose.yml \
            config \
            >/dev/null 2>&1
    )
}


caddy_compose_has_service() {

    [[ -f "$CADDY_DIR/docker-compose.yml" ]] || \
        return 1

    (
        cd "$CADDY_DIR"

        docker compose \
            -f docker-compose.yml \
            config \
            --services \
            2>/dev/null |
        grep -qx "caddy"
    )
}


# ==============================================================================
# 停止旧 Caddy Compose
# ==============================================================================

stop_existing_caddy_compose() {

    if ! caddy_compose_valid; then
        return 0
    fi

    if ! caddy_compose_has_service; then
        return 0
    fi

    info "停止旧 Caddy 容器..."

    (
        cd "$CADDY_DIR"

        docker compose \
            -f docker-compose.yml \
            stop caddy || true

        docker compose \
            -f docker-compose.yml \
            rm -f caddy || true
    )
}


# ==============================================================================
# 完整备份 /opt/caddy
# ==============================================================================

move_caddy_directory_to_backup() {

    [[ -e "$CADDY_DIR" ]] || return 0

    local backup="${CADDY_DIR}.bak.$(timestamp)"

    mv "$CADDY_DIR" "$backup"

    ok "原 Caddy 目录已完整备份："

    echo
    echo "  $backup"
    echo
}


# ==============================================================================
# 检查 container_name=caddy 冲突
# ==============================================================================

ensure_no_caddy_container_conflict() {

    if ! docker ps -a \
        --format '{{.Names}}' |
        grep -qx 'caddy'; then

        return 0
    fi

    warn "检测到已经存在名称为 caddy 的 Docker 容器。"

    echo

    docker ps -a \
        --filter "name=^/caddy$" \
        --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'

    echo

    if ask_yes_no \
        "是否停止并删除这个 caddy 容器？" \
        "N"; then

        docker rm -f caddy

        ok "旧 caddy 容器已删除。"

    else

        die "Docker 容器名称冲突，无法继续。"

    fi
}


# ==============================================================================
# 创建 Caddy Docker Network
# ==============================================================================

create_caddy_network() {

    if docker network inspect "$CADDY_NETWORK" \
        >/dev/null 2>&1; then

        ok "Docker 网络 '$CADDY_NETWORK' 已存在。"

    else

        docker network create "$CADDY_NETWORK" \
            >/dev/null

        ok "已创建 Docker 网络：$CADDY_NETWORK"

    fi
}


# ==============================================================================
# Docker Caddyfile
# ==============================================================================

write_docker_caddyfile() {

    mkdir -p \
        "$CADDY_DIR/conf" \
        "$CADDY_DIR/data" \
        "$CADDY_DIR/config" \
        "$CADDY_DIR/site"

    cat > "$CADDY_DIR/conf/Caddyfile" <<'EOF'
# ==============================================================================
# Caddy v2 - Docker Compose
# ==============================================================================
#
# 当前默认配置用于测试。
#
# 访问：
#
#   http://服务器IP
#
# 应返回：
#
#   Caddy is running!
#
# ------------------------------------------------------------------------------
#
# 示例 1：
# 反向代理同一个 caddy Docker 网络中的容器
#
# example.com {
#     reverse_proxy app:8080
# }
#
# app 容器需要加入：
#
#   caddy
#
# Docker external network。
#
# ------------------------------------------------------------------------------
#
# 示例 2：
# 反向代理宿主机服务
#
# example.com {
#     reverse_proxy host.docker.internal:8080
# }
#
# ------------------------------------------------------------------------------
#
# 示例 3：
#
# app.example.com {
#     reverse_proxy app:3000
# }
#
# api.example.com {
#     reverse_proxy api:8080
# }
#
# ==============================================================================

:80 {
    respond "Caddy is running!" 200
}
EOF

    chmod 0644 "$CADDY_DIR/conf/Caddyfile"

    ok "Docker Caddyfile 已生成。"
}


# ==============================================================================
# docker-compose.yml
# ==============================================================================

write_docker_compose() {

    cat > "$CADDY_DIR/docker-compose.yml" <<EOF
services:

  caddy:
    image: ${CADDY_IMAGE}
    container_name: caddy
    restart: unless-stopped

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
EOF

    chmod 0644 "$CADDY_DIR/docker-compose.yml"

    ok "docker-compose.yml 已生成。"
}


# ==============================================================================
# 验证 / 启动 Docker Caddy
# ==============================================================================

verify_docker_caddy() {

    local cid=""

    cd "$CADDY_DIR"

    info "验证 Docker Compose 配置..."

    docker compose \
        -f docker-compose.yml \
        config \
        >/dev/null

    ok "Docker Compose 配置验证通过。"


    # --------------------------------------------------------------------------
    # 拉取镜像
    # --------------------------------------------------------------------------

    info "拉取 Caddy 镜像：$CADDY_IMAGE"

    docker compose \
        -f docker-compose.yml \
        pull caddy


    # --------------------------------------------------------------------------
    # 启动
    # --------------------------------------------------------------------------

    info "启动 Caddy..."

    if ! docker compose \
        -f docker-compose.yml \
        up -d caddy; then

        echo

        docker compose \
            -f docker-compose.yml \
            logs \
            --tail=100 \
            caddy || true

        die "Caddy Docker 容器启动失败。"
    fi

    sleep 3


    # --------------------------------------------------------------------------
    # 获取 Container ID
    # --------------------------------------------------------------------------

    cid="$(
        docker compose \
            -f docker-compose.yml \
            ps \
            -q \
            caddy
    )"

    if [[ -z "$cid" ]]; then

        die "没有找到 Caddy Docker 容器。"

    fi


    # --------------------------------------------------------------------------
    # 判断运行状态
    # --------------------------------------------------------------------------

    if [[ "$(docker inspect \
        -f '{{.State.Running}}' \
        "$cid")" != "true" ]]; then

        docker compose \
            -f docker-compose.yml \
            logs \
            --tail=100 \
            caddy || true

        die "Caddy Docker 容器没有正常运行。"

    fi

    ok "Caddy Docker 容器运行正常。"


    # --------------------------------------------------------------------------
    # Caddyfile 验证
    # --------------------------------------------------------------------------

    info "验证 Caddyfile..."

    docker compose \
        -f docker-compose.yml \
        exec \
        -T \
        caddy \
        caddy validate \
        --config /etc/caddy/Caddyfile \
        --adapter caddyfile

    ok "Caddyfile 验证通过。"
}


# ==============================================================================
# Docker Caddy HTTP 测试
# ==============================================================================

test_docker_caddy_http() {

    if curl \
        -fsS \
        --connect-timeout 3 \
        http://127.0.0.1 \
        2>/dev/null |
        grep -q "Caddy is running"; then

        ok "HTTP 本机测试通过。"

    else

        warn "Caddy 容器正在运行，但 HTTP 本机测试未返回预期内容。"

    fi
}


# ==============================================================================
# 更新已有 Docker Caddy
# ==============================================================================

update_existing_docker_caddy() {

    cd "$CADDY_DIR"

    if ! caddy_compose_valid; then

        die "现有 docker-compose.yml 无法通过配置验证。"

    fi

    if ! caddy_compose_has_service; then

        die "现有 Compose 中没有名为 caddy 的服务。"

    fi

    backup_file "$CADDY_DIR/docker-compose.yml"

    if [[ -f "$CADDY_DIR/conf/Caddyfile" ]]; then

        backup_file "$CADDY_DIR/conf/Caddyfile"

    fi

    info "拉取最新 Caddy 镜像..."

    docker compose \
        -f docker-compose.yml \
        pull caddy

    info "更新 Caddy 容器..."

    docker compose \
        -f docker-compose.yml \
        up -d caddy

    sleep 3

    if ! docker compose \
        -f docker-compose.yml \
        ps \
        --status running \
        caddy \
        2>/dev/null |
        grep -q caddy; then

        docker compose \
            -f docker-compose.yml \
            logs \
            --tail=100 \
            caddy || true

        die "Caddy 更新后没有正常运行。"

    fi

    docker compose \
        -f docker-compose.yml \
        exec \
        -T \
        caddy \
        caddy validate \
        --config /etc/caddy/Caddyfile \
        --adapter caddyfile

    ok "现有 Caddy Docker 部署更新完成。"
}


# ==============================================================================
# Docker Caddy 结果
# ==============================================================================

show_docker_caddy_result() {

    separator

    echo -e "${GREEN}${BOLD}Caddy Docker Compose 部署完成${NC}"

    echo

    echo "部署方式 : Docker Compose"
    echo "目录     : $CADDY_DIR"
    echo "镜像     : $CADDY_IMAGE"
    echo "网络     : $CADDY_NETWORK"

    echo

    echo -n "Caddy版本: "

    (
        cd "$CADDY_DIR"

        docker compose \
            -f docker-compose.yml \
            exec \
            -T \
            caddy \
            caddy version \
            2>/dev/null
    ) || echo "未知"

    echo

    print_test_url

    echo
    echo "目录结构："
    echo
    echo "  /opt/caddy/"
    echo "  ├── docker-compose.yml"
    echo "  ├── conf/"
    echo "  │   └── Caddyfile"
    echo "  ├── data/"
    echo "  ├── config/"
    echo "  └── site/"
    echo

    echo "常用命令："
    echo
    echo "  cd /opt/caddy"
    echo
    echo "  docker compose ps"
    echo "  docker compose logs -f caddy"
    echo "  docker compose restart caddy"
    echo
    echo "  docker compose pull"
    echo "  docker compose up -d"
    echo

    echo "修改 Caddyfile 后重新加载："
    echo
    echo "  cd /opt/caddy"
    echo "  docker compose exec -w /etc/caddy caddy caddy reload"
    echo

    echo "验证配置："
    echo
    echo "  cd /opt/caddy"
    echo "  docker compose exec -T caddy \\"
    echo "    caddy validate \\"
    echo "    --config /etc/caddy/Caddyfile \\"
    echo "    --adapter caddyfile"
    echo

    echo "其他 Docker 容器需要被 Caddy 反代时，"
    echo "可以加入 external Docker network："
    echo
    echo "  caddy"
    echo
}


# ==============================================================================
# 安装 Docker Compose Caddy
# ==============================================================================

install_caddy_docker() {

    separator

    echo -e "${BOLD}安装 Caddy - Docker Compose${NC}"
    echo

    # --------------------------------------------------------------------------
    # Docker 前置条件
    # --------------------------------------------------------------------------

    ensure_docker

    ensure_packages \
        curl \
        iproute2

    local mode="fresh"
    local choice=""


    # ==========================================================================
    # 检查现有 /opt/caddy
    # ==========================================================================

    if [[ -d "$CADDY_DIR" ]] &&
       [[ -n "$(
            find \
                "$CADDY_DIR" \
                -mindepth 1 \
                -maxdepth 1 \
                -print \
                -quit \
                2>/dev/null
        )" ]]; then

        warn "检测到已有目录：$CADDY_DIR"

        echo

        # ----------------------------------------------------------------------
        # 可识别的 Caddy Compose
        # ----------------------------------------------------------------------

        if caddy_compose_valid &&
           caddy_compose_has_service; then

            echo "请选择："
            echo
            echo "  1. 保留现有配置并更新 Caddy"
            echo "  2. 完整备份后重新部署"
            echo "  0. 退出"
            echo

            while true; do

                prompt_read "请选择 [0-2]: " choice

                case "$choice" in

                    1)

                        mode="preserve"
                        break
                        ;;

                    2)

                        mode="reset"
                        break
                        ;;

                    0)

                        info "已取消。"
                        return 0
                        ;;

                    *)

                        warn "请输入 0、1 或 2。"
                        ;;

                esac

            done

        # ----------------------------------------------------------------------
        # 无法识别的 /opt/caddy
        # ----------------------------------------------------------------------

        else

            warn "$CADDY_DIR 不是本脚本能够识别的标准 Caddy Compose 部署。"

            echo
            echo "为了避免覆盖数据，默认不会修改。"
            echo

            if ask_yes_no \
                "是否完整备份该目录后重新部署？" \
                "N"; then

                mode="reset"

            else

                die "已取消部署。"

            fi

        fi

    fi


    # ==========================================================================
    # 保留现有配置更新
    # ==========================================================================

    if [[ "$mode" == "preserve" ]]; then

        update_existing_docker_caddy

        handle_ufw

        show_docker_caddy_result

        return 0
    fi


    # ==========================================================================
    # 重装
    # ==========================================================================

    if [[ "$mode" == "reset" ]]; then

        if caddy_compose_valid &&
           caddy_compose_has_service; then

            stop_existing_caddy_compose

        fi

        move_caddy_directory_to_backup
    fi


    # ==========================================================================
    # 防止 caddy container name 冲突
    # ==========================================================================

    ensure_no_caddy_container_conflict


    # ==========================================================================
    # 检测端口
    # ==========================================================================

    ensure_ports_free


    # ==========================================================================
    # 创建 Docker network
    # ==========================================================================

    create_caddy_network


    # ==========================================================================
    # 创建目录
    # ==========================================================================

    mkdir -p "$CADDY_DIR"


    # ==========================================================================
    # 写入配置
    # ==========================================================================

    write_docker_caddyfile

    write_docker_compose


    # ==========================================================================
    # 启动和验证
    # ==========================================================================

    verify_docker_caddy

    test_docker_caddy_http

    handle_ufw

    show_docker_caddy_result
}


# ==============================================================================
#
# 主菜单
#
# ==============================================================================

main_menu() {

    separator

    echo -e "${CYAN}${BOLD}"
    echo "        Docker + Caddy v2 一键部署脚本"
    echo -e "${NC}"

    echo "支持：Debian / Ubuntu"

    echo
    echo "请选择功能："
    echo

    echo "  1. 只安装 Docker"
    echo "     Docker Engine + Docker Compose v2"
    echo

    echo "  2. 安装 Caddy - systemd"
    echo "     Caddy 官方 APT + systemd"
    echo

    echo "  3. 安装 Caddy - Docker Compose"
    echo "     默认部署到 /opt/caddy"
    echo

    echo "  0. 退出"

    echo

    local choice=""

    while true; do

        prompt_read "请选择 [0-3]: " choice

        case "$choice" in

            1)

                install_docker_only
                return
                ;;

            2)

                install_caddy_systemd
                return
                ;;

            3)

                install_caddy_docker
                return
                ;;

            0)

                info "退出。"
                exit 0
                ;;

            *)

                warn "请输入 0、1、2 或 3。"
                ;;

        esac

    done
}


# ==============================================================================
# Main
# ==============================================================================

main() {

    check_root

    check_os

    check_architecture

    show_system_info

    main_menu
}


main "$@"
