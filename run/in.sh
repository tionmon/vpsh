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

# 检查并临时安装 CA 证书
check_and_install_ca_certificates() {
    log_info "检查 CA 证书..."

    # 检查是否存在 ca-certificates 包
    if ! dpkg -l | grep -q "^ii.*ca-certificates"; then
        log_warn "检测到系统缺少 CA 证书，正在临时安装..."

        # 临时将 HTTPS 源改为 HTTP
        if [ -f /etc/apt/sources.list ]; then
            cp /etc/apt/sources.list /etc/apt/sources.list.backup.ca
            sed -i 's|https://|http://|g' /etc/apt/sources.list
            log_info "已临时将源改为 HTTP"
        fi

        # 更新并安装 ca-certificates
        apt update
        apt install -y ca-certificates

        # 恢复 HTTPS 源（如果之前有备份）
        if [ -f /etc/apt/sources.list.backup.ca ]; then
            mv /etc/apt/sources.list.backup.ca /etc/apt/sources.list
            log_info "已恢复 HTTPS 源"
        fi

        log_info "CA 证书安装完成"
    else
        log_info "CA 证书已存在，无需安装"
    fi
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

# 询问是否安装 Docker
ask_install_docker() {
    echo ""
    echo -e "${YELLOW}================================================${NC}"
    echo -e "${YELLOW}检测到系统未安装 Docker${NC}"
    echo -e "${YELLOW}是否需要安装 Docker？${NC}"
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
            log_warn "无效的输入，默认不安装 Docker"
            return 1
            ;;
    esac
}

# 询问是否配置 Docker 镜像加速
ask_configure_docker_mirror() {
    echo ""
    echo -e "${YELLOW}================================================${NC}"
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

# 国内优化（仅配置源）
optimize_for_china() {
    log_info "开始国内优化..."

    # 检查并安装 CA 证书
    check_and_install_ca_certificates

    # 配置 APT 源
    configure_apt_sources

    # 安装基础软件包
    install_basic_packages

    echo ""
    log_info "================================"
    log_info "国内优化完成！"
    log_info "================================"
    echo ""
}

# 主函数
main() {
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}       系统优化脚本${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""

    # 检查 root 权限
    check_root

    # 检测系统版本
    detect_system

    # 直接执行国内优化
    optimize_for_china

    # Docker 安装标志
    DOCKER_INSTALLED=false

    # 检查 Docker 是否已安装
    if check_docker_installed; then
        log_info "检测到系统已安装 Docker"
        DOCKER_INSTALLED=true

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
        # Docker 未安装，询问是否安装
        if ask_install_docker; then
            # 询问是否配置镜像加速
            CONFIGURE_MIRROR=false
            if ask_configure_docker_mirror; then
                CONFIGURE_MIRROR=true
            fi

            # 配置镜像加速（如果选择了）
            if [ "$CONFIGURE_MIRROR" = true ]; then
                configure_docker_registry
            fi

            # 安装 Docker
            install_docker

            # 启用 Docker 开机自启
            enable_docker_autostart

            DOCKER_INSTALLED=true

            if [ "$CONFIGURE_MIRROR" = true ]; then
                log_info "Docker 安装完成，镜像加速配置已生效"
            else
                log_info "Docker 安装完成"
            fi
        else
            log_info "已跳过 Docker 安装"
        fi
    fi

    # 如果 Docker 已安装（无论是之前就有还是刚装的），询问是否安装 v2raya
    if [ "$DOCKER_INSTALLED" = true ]; then
        if ask_install_v2raya; then
            install_v2raya
        else
            log_info "已跳过 v2raya 安装"
        fi
    fi

    echo ""
    log_info "================================"
    log_info "脚本执行完成！"
    log_info "================================"
    echo ""
}

# 执行主函数
main
