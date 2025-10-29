#!/bin/bash

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 用户运行此脚本"
        exit 1
    fi
}

# 检测系统版本
detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        VERSION_CODENAME=$VERSION_CODENAME
    else
        log_error "无法检测系统版本"
        exit 1
    fi

    log_info "检测到系统: $OS $VERSION ($VERSION_CODENAME)"
}

# 配置 APT 源
configure_apt_sources() {
    log_info "正在配置 APT 源..."

    # 备份原有源
    if [ -f /etc/apt/sources.list ]; then
        cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d%H%M%S)
        log_info "已备份原有源文件"
    fi

    case "$OS" in
        debian)
            case "$VERSION_CODENAME" in
                bullseye)
                    log_info "配置 Debian 11 (bullseye) 源..."
                    cat > /etc/apt/sources.list << 'EOF'
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye main contrib non-free

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-updates main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-updates main contrib non-free

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-backports main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-backports main contrib non-free

# 以下安全更新软件源包含了官方源与镜像站配置，如有需要可自行修改注释切换
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bullseye-security main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian-security bullseye-security main contrib non-free
EOF
                    ;;
                bookworm)
                    log_info "配置 Debian 12 (bookworm) 源..."
                    cat > /etc/apt/sources.list << 'EOF'
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware

# 以下安全更新软件源包含了官方源与镜像站配置，如有需要可自行修改注释切换
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware
EOF
                    ;;
                trixie)
                    log_info "配置 Debian 13 (trixie) 源..."
                    cat > /etc/apt/sources.list << 'EOF'
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-updates main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-updates main contrib non-free non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-backports main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-backports main contrib non-free non-free-firmware

# 以下安全更新软件源包含了官方源与镜像站配置，如有需要可自行修改注释切换
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security trixie-security main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian-security trixie-security main contrib non-free non-free-firmware
EOF
                    ;;
                *)
                    log_error "不支持的 Debian 版本: $VERSION_CODENAME"
                    exit 1
                    ;;
            esac
            ;;
        ubuntu)
            case "$VERSION_CODENAME" in
                noble)
                    log_info "配置 Ubuntu 24.04 LTS (noble) 源..."
                    cat > /etc/apt/sources.list << 'EOF'
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble-backports main restricted universe multiverse

# 以下安全更新软件源包含了官方源与镜像站配置，如有需要可自行修改注释切换
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble-security main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble-security main restricted universe multiverse
EOF
                    ;;
                plucky)
                    log_info "配置 Ubuntu 25.04 (plucky) 源..."
                    cat > /etc/apt/sources.list << 'EOF'
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ plucky main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ plucky main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ plucky-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ plucky-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ plucky-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ plucky-backports main restricted universe multiverse

# 以下安全更新软件源包含了官方源与镜像站配置，如有需要可自行修改注释切换
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ plucky-security main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ plucky-security main restricted universe multiverse
EOF
                    ;;
                oracular)
                    log_info "配置 Ubuntu 24.10 (oracular) 源..."
                    cat > /etc/apt/sources.list << 'EOF'
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ oracular main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ oracular main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ oracular-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ oracular-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ oracular-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ oracular-backports main restricted universe multiverse

# 以下安全更新软件源包含了官方源与镜像站配置，如有需要可自行修改注释切换
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ oracular-security main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ oracular-security main restricted universe multiverse
EOF
                    ;;
                *)
                    log_error "不支持的 Ubuntu 版本: $VERSION_CODENAME"
                    exit 1
                    ;;
            esac
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac

    log_info "APT 源配置完成"
}

# 安装基础软件包
install_basic_packages() {
    log_info "更新软件包索引..."
    apt update

    log_info "安装必要的软件包 (curl, wget, sudo, unzip, netcat-openbsd)..."
    apt install -y curl wget sudo unzip netcat-openbsd

    log_info "基础软件包安装完成"
}

# 配置 Docker 镜像加速
configure_docker_registry() {
    log_info "配置 Docker 镜像加速..."

    # 检查 /etc/docker 目录是否存在，如果不存在则创建
    if [ ! -d "/etc/docker" ]; then
        log_info "创建 /etc/docker 目录..."
        mkdir -p /etc/docker
    fi

    # 创建 /etc/docker/daemon.json 文件
    cat > /etc/docker/daemon.json << 'EOF'
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.ketches.cn",
    "https://docker.1panel.top",
    "https://proxy.1panel.live",
    "https://dockerproxy.1panel.live",
    "https://docker.1panel.live",
    "https://docker.1panelproxy.com",
    "https://dockerproxy.net",
    "https://docker-registry.nmqu.com",
    "https://hub1.nat.tf"
  ]
}
EOF

    log_info "Docker 镜像加速配置完成"
}

# 安装 Docker
install_docker() {
    log_info "开始安装 Docker..."

    # 设置下载 URL 环境变量
    export DOWNLOAD_URL="https://mirrors.tuna.tsinghua.edu.cn/docker-ce"
    log_info "使用清华镜像源安装 Docker"

    # 安装 Docker
    curl -fsSL https://gh-proxy.com/raw.githubusercontent.com/docker/docker-install/master/install.sh | bash

    if [ $? -eq 0 ]; then
        log_info "Docker 安装成功"
    else
        log_error "Docker 安装失败"
        exit 1
    fi
}

# 启用 Docker 开机自启
enable_docker_autostart() {
    log_info "设置 Docker 开机自启..."

    systemctl enable docker
    systemctl start docker

    if systemctl is-enabled docker &> /dev/null; then
        log_info "Docker 开机自启已启用"
    else
        log_warn "Docker 开机自启设置可能失败，请手动检查"
    fi

    # 检查 Docker 运行状态
    if systemctl is-active docker &> /dev/null; then
        log_info "Docker 服务运行正常"
    else
        log_error "Docker 服务未运行"
        exit 1
    fi
}

# 安装 v2raya
install_v2raya() {
    log_info "开始安装 v2raya..."

    # 创建目录并下载 docker-compose 配置文件
    mkdir -p /home/docker/v2raya
    cd /home/docker/v2raya

    log_info "下载 v2raya docker-compose 配置文件..."
    curl -L -o docker-compose.yaml https://gh-proxy.com/raw.githubusercontent.com/tionmon/vpsh/refs/heads/main/file/v2raya.yaml

    if [ $? -ne 0 ]; then
        log_error "下载 docker-compose.yaml 失败"
        exit 1
    fi

    # 启动 docker-compose
    log_info "启动 v2raya..."
    docker compose up -d

    if [ $? -eq 0 ]; then
        log_info "v2raya 安装并启动成功"

        # 获取本机 IP
        log_info "获取本机 IP 地址..."
        IP=$(curl -s ip.sb)

        if [ -n "$IP" ]; then
            echo ""
            log_info "================================"
            log_info "v2raya 已成功安装！"
            log_info "访问地址: http://${IP}:2017"
            log_info "================================"
            echo ""
        else
            log_warn "无法获取本机 IP 地址，请手动查看"
        fi
    else
        log_error "v2raya 启动失败"
        exit 1
    fi
}

# 检查 Docker 是否已安装
check_docker_installed() {
    if command -v docker &> /dev/null; then
        return 0  # Docker 已安装
    else
        return 1  # Docker 未安装
    fi
}

# 询问是否配置 Docker 镜像加速
ask_configure_docker_mirror() {
    echo ""
    echo -e "${YELLOW}================================================${NC}"
    echo -e "${YELLOW}检测到系统已安装 Docker${NC}"
    echo -e "${YELLOW}是否需要配置 Docker 镜像加速？${NC}"
    echo -e "${YELLOW}输入 y 或 yes 继续配置，输入 n 或 no 跳过配置${NC}"
    echo -e "${YELLOW}================================================${NC}"
    read -p "请选择 [y/n]: " choice

    case "$choice" in
        y|Y|yes|YES)
            return 0
            ;;
        n|N|no|NO)
            return 1
            ;;
        *)
            log_warn "无效的输入，默认不配置镜像加速"
            return 1
            ;;
    esac
}

# 显示系统选择菜单
show_system_menu() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}       系统重装脚本 - 选择目标系统${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    echo "请选择要安装的系统："
    echo ""
    echo "  1. Debian 11 (bullseye)"
    echo "  2. Debian 12 (bookworm)"
    echo "  3. Debian 13 (trixie)"
    echo "  4. Ubuntu 20.04 LTS (focal)"
    echo "  5. Ubuntu 22.04 LTS (jammy)"
    echo ""
    echo -e "${YELLOW}================================================${NC}"
    read -p "请输入选项 [1-5]: " system_choice
    echo ""
}

# 获取系统参数
get_system_params() {
    case "$system_choice" in
        1)
            SYSTEM_FLAG="-d 11"
            MIRROR_URL="https://mirrors.tuna.tsinghua.edu.cn/debian/"
            SYSTEM_NAME="Debian 11 (bullseye)"
            ;;
        2)
            SYSTEM_FLAG="-d 12"
            MIRROR_URL="https://mirrors.tuna.tsinghua.edu.cn/debian/"
            SYSTEM_NAME="Debian 12 (bookworm)"
            ;;
        3)
            SYSTEM_FLAG="-d 13"
            MIRROR_URL="https://mirrors.tuna.tsinghua.edu.cn/debian/"
            SYSTEM_NAME="Debian 13 (trixie)"
            ;;
        4)
            SYSTEM_FLAG="-u 20.04"
            MIRROR_URL="https://mirrors.tuna.tsinghua.edu.cn/ubuntu/"
            SYSTEM_NAME="Ubuntu 20.04 LTS (focal)"
            ;;
        5)
            SYSTEM_FLAG="-u 22.04"
            MIRROR_URL="https://mirrors.tuna.tsinghua.edu.cn/ubuntu/"
            SYSTEM_NAME="Ubuntu 22.04 LTS (jammy)"
            ;;
        *)
            log_error "无效的选项，请输入 1-5"
            exit 1
            ;;
    esac
}

# 获取用户输入的密码
get_password() {
    echo ""
    echo -e "${YELLOW}================================================${NC}"
    echo -e "${YELLOW}设置 Root 密码${NC}"
    echo -e "${YELLOW}================================================${NC}"
    while true; do
        read -sp "请输入 root 密码: " password
        echo ""
        if [ -z "$password" ]; then
            log_error "密码不能为空，请重新输入"
            continue
        fi

        read -sp "请再次输入密码: " password_confirm
        echo ""

        if [ "$password" != "$password_confirm" ]; then
            log_error "两次密码输入不一致，请重新输入"
            continue
        fi

        break
    done
    echo ""
}

# 获取用户输入的 SSH 端口
get_ssh_port() {
    echo ""
    echo -e "${YELLOW}================================================${NC}"
    echo -e "${YELLOW}设置 SSH 端口${NC}"
    echo -e "${YELLOW}================================================${NC}"
    while true; do
        read -p "请输入 SSH 端口 (默认: 22): " ssh_port

        # 如果为空，使用默认端口 22
        if [ -z "$ssh_port" ]; then
            ssh_port=22
            break
        fi

        # 检查是否为数字
        if ! [[ "$ssh_port" =~ ^[0-9]+$ ]]; then
            log_error "端口必须是数字，请重新输入"
            continue
        fi

        # 检查端口范围
        if [ "$ssh_port" -lt 1 ] || [ "$ssh_port" -gt 65535 ]; then
            log_error "端口范围必须在 1-65535 之间，请重新输入"
            continue
        fi

        break
    done
    echo ""
}

# 获取服务器 IP 地址
get_server_ip() {
    log_info "正在获取服务器 IP 地址..."

    # 临时禁用错误退出，防止 curl 失败导致脚本退出
    set +e

    # 尝试获取 IPv4 地址
    SERVER_IP=$(curl -s --max-time 5 4.ipw.cn 2>/dev/null)

    # 如果 IPv4 获取失败，尝试 IPv6
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(curl -s --max-time 5 6.ipw.cn 2>/dev/null)
    fi

    # 如果都失败，使用备用方法
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(curl -s --max-time 5 ip.sb 2>/dev/null)
    fi

    # 恢复错误退出设置
    set -e

    if [ -z "$SERVER_IP" ]; then
        log_warn "无法自动获取服务器 IP，请手动记录"
        SERVER_IP="<您的服务器IP>"
    else
        log_info "服务器 IP: ${SERVER_IP}"
    fi
}

# 确认系统重装信息
confirm_system_reinstall() {
    # 生成检测命令
    MONITOR_CMD="apt install netcat-openbsd -y && while true; do nc -zv ${SERVER_IP} ${ssh_port}; sleep 5; done"

    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}       安装信息确认${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo "  目标系统: ${SYSTEM_NAME}"
    echo "  服务器 IP: ${SERVER_IP}"
    echo "  SSH 端口: ${ssh_port}"
    echo "  镜像源: ${MIRROR_URL}"
    echo ""
    echo -e "${BLUE}重装完成检测命令:${NC}"
    echo -e "${YELLOW}${MONITOR_CMD}${NC}"
    echo ""
    echo -e "${YELLOW}================================================${NC}"
    read -p "确认安装？(输入 yes 继续): " confirm
    echo ""

    if [ "$confirm" != "yes" ]; then
        log_warn "已取消安装"
        exit 0
    fi
}

# 执行系统重装
execute_system_reinstall() {
    log_info "开始执行系统重装..."
    echo ""

    # 构建完整命令
    INSTALL_CMD="bash <(wget --no-check-certificate -qO- 'https://gh-proxy.com/https://raw.githubusercontent.com/MoeClub/Note/master/InstallNET.sh') ${SYSTEM_FLAG} -v 64 -p \"${password}\" -port \"${ssh_port}\" --mirror '${MIRROR_URL}'"

    log_info "执行命令: ${INSTALL_CMD}"
    echo ""

    # 临时禁用错误退出，因为系统重装会断开连接
    set +e

    # 执行安装命令
    eval "$INSTALL_CMD"

    # 不管返回值如何，都显示信息
    echo ""
    log_info "================================"
    log_info "系统重装命令已执行！"
    log_info "系统将在几分钟后重启并开始安装"
    log_info "================================"
    echo ""
    log_info "安装信息:"
    log_info "  系统: ${SYSTEM_NAME}"
    log_info "  服务器 IP: ${SERVER_IP}"
    log_info "  SSH 端口: ${ssh_port}"
    log_info "  Root 密码: (您设置的密码)"
    echo ""
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}请在另一台机器上执行以下命令，监控重装进度:${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo ""
    echo -e "${YELLOW}${MONITOR_CMD}${NC}"
    echo ""
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${GREEN}当看到 'Connection to ${SERVER_IP} ${ssh_port} port [tcp/*] succeeded!' 时${NC}"
    echo -e "${GREEN}表示系统重装完成，可以使用 SSH 登录了${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo ""
}

# 询问是否安装 v2raya
ask_install_v2raya() {
    echo ""
    echo -e "${YELLOW}================================================${NC}"
    echo -e "${YELLOW}是否需要安装 v2raya？${NC}"
    echo -e "${YELLOW}输入 y 或 yes 继续安装，输入 n 或 no 跳过安装${NC}"
    echo -e "${YELLOW}================================================${NC}"
    read -p "请选择 [y/n]: " choice

    case "$choice" in
        y|Y|yes|YES)
            return 0
            ;;
        n|N|no|NO)
            return 1
            ;;
        *)
            log_warn "无效的输入，默认不安装 v2raya"
            return 1
            ;;
    esac
}

# 国内优化（仅配置源和镜像加速）
optimize_for_china() {
    log_info "开始国内优化..."

    # 配置 APT 源
    configure_apt_sources

    # 安装基础软件包
    install_basic_packages

    # 检查 Docker 是否已安装
    if check_docker_installed; then
        # Docker 已安装，询问是否配置镜像加速
        if ask_configure_docker_mirror; then
            configure_docker_registry
            # 重启 Docker 服务以应用配置
            log_info "重启 Docker 服务以应用镜像加速配置..."
            systemctl restart docker
            if [ $? -eq 0 ]; then
                log_info "Docker 镜像加速配置已生效"
            else
                log_error "Docker 服务重启失败"
                exit 1
            fi
        else
            log_info "已跳过 Docker 镜像加速配置"
        fi
    else
        log_warn "系统未安装 Docker，跳过 Docker 镜像加速配置"
    fi

    echo ""
    log_info "================================"
    log_info "国内优化完成！"
    log_info "================================"
    echo ""
}

# 国内重装（完整系统重装流程）
reinstall_for_china() {
    log_info "开始国内重装..."
    echo ""

    # 显示系统选择菜单
    show_system_menu

    # 获取系统参数
    get_system_params

    # 获取密码
    get_password

    # 获取 SSH 端口
    get_ssh_port

    # 获取服务器 IP 地址
    get_server_ip

    # 确认系统重装信息
    confirm_system_reinstall

    # 执行系统重装
    execute_system_reinstall

    # 系统重装后脚本会断开，直接退出
    exit 0
}

# 显示菜单
show_menu() {
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}       Docker 自动配置/安装脚本${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo "请选择操作："
    echo "  1. 国内优化 "
    echo "  2. 国内重装 "
    echo ""
    echo -e "${YELLOW}================================================${NC}"
    read -p "请输入选项 [1-2]: " menu_choice
    echo ""
}

# 主函数
main() {
    # 检查 root 权限
    check_root

    # 检测系统版本
    detect_system

    # 显示菜单并处理选择
    show_menu

    case "$menu_choice" in
        1)
            optimize_for_china
            ;;
        2)
            reinstall_for_china
            ;;
        *)
            log_error "无效的选项，请输入 1 或 2"
            exit 1
            ;;
    esac

    # 在执行完主要操作后，询问是否安装 v2raya
    INSTALL_V2RAYA=false
    if ask_install_v2raya; then
        INSTALL_V2RAYA=true
    fi

    # 如果用户选择安装 v2raya，则继续安装
    if [ "$INSTALL_V2RAYA" = true ]; then
        # 确保 Docker 已安装
        if ! check_docker_installed; then
            log_error "Docker 未安装，无法安装 v2raya"
            exit 1
        fi
        install_v2raya
    else
        log_info "已跳过 v2raya 安装"
    fi

    echo ""
    log_info "================================"
    log_info "脚本执行完成！"
    log_info "================================"
    echo ""
}

# 执行主函数
main
