#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印信息函数
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要 root 权限运行"
        echo "请使用 sudo 或 root 用户执行此脚本"
        exit 1
    fi
}

# 检查 Docker 是否已安装
check_docker() {
    if command -v docker &> /dev/null; then
        print_info "检测到 Docker 已安装"
        docker --version
        return 0
    else
        print_warning "未检测到 Docker"
        return 1
    fi
}

# 安装 Docker
install_docker() {
    print_info "开始安装 Docker..."
    echo ""
    echo "请选择您的 VPS 所处环境："
    echo "1. 国内"
    echo "2. 国外"
    read -p "请输入选项 [1/2]: " choice

    case $choice in
        1)
            print_info "使用国内源安装 Docker..."
            bash <(curl -Ls sh.tionmon.de/in)
            ;;
        2)
            print_info "使用官方源安装 Docker..."
            curl -fsSL https://get.docker.com | bash -s docker
            ;;
        *)
            print_error "无效的选择"
            exit 1
            ;;
    esac

    # 检查安装是否成功
    if command -v docker &> /dev/null; then
        print_info "Docker 安装成功！"

        # 启动 Docker 服务
        systemctl start docker
        systemctl enable docker

        docker --version
    else
        print_error "Docker 安装失败"
        exit 1
    fi
}

# 下载 docker-compose.yaml
download_compose_file() {
    print_info "开始下载 docker-compose.yaml 文件..."

    # 创建目录
    mkdir -p /home/docker/115up

    # 下载文件
    if curl -fsSL -o /home/docker/115up/docker-compose.yaml "https://gh-proxy.com/raw.githubusercontent.com/tionmon/vpsh/refs/heads/main/file/115up.yaml"; then
        print_info "docker-compose.yaml 下载成功！"
    else
        print_error "docker-compose.yaml 下载失败"
        exit 1
    fi
}

# 启动 Docker Compose
start_docker_compose() {
    print_info "开始构建并启动 Docker 容器..."

    cd /home/docker/115up || exit 1

    if docker compose up -d; then
        print_info "Docker 容器启动成功！"
    else
        print_error "Docker 容器启动失败"
        exit 1
    fi

    # 等待容器完全启动
    print_info "等待容器完全启动..."
    sleep 5
}

# 获取访问信息
show_access_info() {
    print_info "获取访问信息..."

    # 获取当前 IP
    IP=$(curl -s 4.ipw.cn)

    if [ -z "$IP" ]; then
        print_warning "无法获取公网 IP，使用本地 IP"
        IP="localhost"
    fi

    echo ""
    echo "========================================"
    echo -e "${GREEN}安装完成！访问链接如下：${NC}"
    echo "========================================"
    echo ""
    echo -e "${YELLOW}CloudDrive:${NC}"
    echo "  http://$IP:19798/"
    echo ""
    echo -e "${YELLOW}FileBrowser:${NC}"
    echo "  http://$IP:7070/"
    echo ""
    echo -e "${YELLOW}qBittorrent:${NC}"
    echo "  http://$IP:8082/"
    echo ""
    echo "========================================"

    # 获取 qBittorrent 临时密码
    echo ""
    print_info "获取 qBittorrent 临时密码..."
    echo "----------------------------------------"
    docker logs $(docker ps -q -f name=qbittorrent) 2>&1 | grep -i "password\|temporary"
    echo "----------------------------------------"

    # 获取 FileBrowser 日志
    echo ""
    print_info "FileBrowser 日志信息..."
    echo "----------------------------------------"
    docker logs $(docker ps -q -f name=filebrowser) 2>&1 | tail -n 20
    echo "----------------------------------------"

    echo ""
    print_info "默认账号信息（如有）："
    echo "FileBrowser: admin / admin"
    echo "qBittorrent: admin / 请查看上方日志中的临时密码"
    echo ""
}

# 主函数
main() {
    clear
    echo "========================================"
    echo "  115UP Docker 一键安装脚本"
    echo "========================================"
    echo ""

    # 检查 root 权限
    check_root

    # 检查并安装 Docker
    if ! check_docker; then
        install_docker
    fi

    # 下载 docker-compose.yaml
    download_compose_file

    # 启动 Docker Compose
    start_docker_compose

    # 显示访问信息
    show_access_info

    echo ""
    print_info "安装完成！"
}

# 执行主函数
main
