#!/bin/bash

# Mihomo Docker 一键安装脚本
# 配置文件取自 YouTuber @hj12123 hanjiang thanks.

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 全局变量
SUBSCRIBE_URL=""

# 打印带颜色的消息
print_info() {
    echo -e "${GREEN}[信息]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 获取订阅链接并验证
get_and_verify_subscription() {
    print_info "请输入您的订阅链接（proxy-provider 订阅地址）："
    read -r SUBSCRIBE_URL

    # 检查输入是否为空
    while [[ -z "$SUBSCRIBE_URL" ]]; do
        print_warning "订阅链接不能为空！"
        read -r SUBSCRIBE_URL
    done

    # 验证订阅链接是否可访问
    print_info "正在验证订阅链接..."

    # 尝试访问订阅链接，设置超时时间为 10 秒
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 -m 10 "$SUBSCRIBE_URL" | grep -q "^[23]"; then
        print_info "订阅链接验证成功！"
        return 0
    else
        print_error "订阅链接无法访问或返回错误"
        echo ""
        echo "可能的原因："
        echo "  1. 链接地址不正确"
        echo "  2. 网络连接问题"
        echo "  3. 订阅服务暂时不可用"
        echo ""
        read -p "是否重新输入订阅链接？(y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            get_and_verify_subscription
        else
            print_error "无法验证订阅链接，退出安装"
            exit 1
        fi
    fi
}

# 检查是否以 root 权限运行
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要 root 权限运行"
        echo "请使用 sudo 运行此脚本: sudo bash $0"
        exit 1
    fi
}

# 检查 Docker 是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装！"
        echo ""
        echo "请先安装 Docker，您可以使用以下命令安装："
        echo ""
        echo "  curl -fsSL https://get.docker.com | sh"
        echo ""
        echo "或者访问 https://docs.docker.com/engine/install/ 查看详细安装说明"
        exit 1
    fi

    # 检查 Docker 服务是否运行
    if ! systemctl is-active --quiet docker; then
        print_warning "Docker 服务未运行，正在启动..."
        systemctl start docker
        systemctl enable docker
    fi

    print_info "Docker 已安装并运行"
}

# 检查文件是否存在并询问是否覆盖
check_file_exists() {
    local file_path=$1
    if [[ -f "$file_path" ]]; then
        print_warning "文件 $file_path 已存在"
        read -p "是否覆盖？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    return 0
}

# 创建目录结构
create_directories() {
    print_info "创建目录结构..."
    mkdir -p /home/docker/mihomo/clash_meta/clash
    print_info "目录创建完成"
}

# 下载文件
download_files() {
    local docker_compose_url="https://gh-proxy.com/raw.githubusercontent.com/tionmon/vpsh/refs/heads/main/file/mihomo/docker/docker-compose.yaml"
    local config_url="https://gh-proxy.com/raw.githubusercontent.com/tionmon/vpsh/refs/heads/main/file/mihomo/docker/config.yaml"

    local docker_compose_path="/home/docker/mihomo/docker-compose.yaml"
    local config_path="/home/docker/mihomo/clash_meta/clash/config.yaml"

    # 下载 docker-compose.yaml
    print_info "下载 docker-compose.yaml..."
    if check_file_exists "$docker_compose_path"; then
        if curl -fsSL "$docker_compose_url" -o "$docker_compose_path"; then
            print_info "docker-compose.yaml 下载成功"
        else
            print_error "docker-compose.yaml 下载失败"
            exit 1
        fi
    else
        print_info "跳过 docker-compose.yaml 下载"
    fi

    # 下载 config.yaml
    print_info "下载 config.yaml..."
    if check_file_exists "$config_path"; then
        if curl -fsSL "$config_url" -o "$config_path"; then
            print_info "config.yaml 下载成功"
        else
            print_error "config.yaml 下载失败"
            exit 1
        fi
    else
        print_info "跳过 config.yaml 下载"
    fi
}

# 配置订阅链接
configure_subscription() {
    local config_path="/home/docker/mihomo/clash_meta/clash/config.yaml"

    print_info "配置订阅链接..."

    # 使用 sed 替换 config.yaml 中的订阅链接
    # 查找 url: "" 并替换为用户输入的 URL
    if sed -i "s|url: \"\"|url: \"$SUBSCRIBE_URL\"|g" "$config_path"; then
        print_info "订阅链接配置成功"
    else
        print_error "订阅链接配置失败"
        exit 1
    fi
}

# 启动 Docker Compose
start_docker_compose() {
    print_info "启动 Mihomo Docker 容器..."
    cd /home/docker/mihomo

    if docker compose up -d; then
        print_info "Mihomo 容器启动成功！"
    else
        print_error "Mihomo 容器启动失败"
        exit 1
    fi
}

# 获取本机 IP 地址（IPv4 和 IPv6）
get_ip_addresses() {
    local ipv4=""
    local ipv6=""

    # 尝试获取公网 IPv4
    ipv4=$(curl -4 -s --connect-timeout 5 ifconfig.me 2>/dev/null || curl -4 -s --connect-timeout 5 icanhazip.com 2>/dev/null || echo "")

    # 如果没有获取到公网 IPv4，尝试获取本地 IPv4
    if [[ -z "$ipv4" ]]; then
        ipv4=$(hostname -I | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)
    fi

    # 尝试获取公网 IPv6
    ipv6=$(curl -6 -s --connect-timeout 5 ifconfig.me 2>/dev/null || curl -6 -s --connect-timeout 5 icanhazip.com 2>/dev/null || echo "")

    # 如果没有获取到公网 IPv6，尝试获取本地 IPv6（排除本地链路地址 fe80::）
    if [[ -z "$ipv6" ]]; then
        ipv6=$(ip -6 addr show scope global 2>/dev/null | grep -oP '(?<=inet6\s)[\da-f:]+' | grep -v '^fe80:' | head -n 1)
    fi

    # 返回 IPv4 和 IPv6，用竖线分隔
    echo "${ipv4}|${ipv6}"
}

# 显示完成信息
show_completion_message() {
    local ip_info=$(get_ip_addresses)
    local ipv4=$(echo "$ip_info" | cut -d'|' -f1)
    local ipv6=$(echo "$ip_info" | cut -d'|' -f2)

    echo ""
    echo "=========================================="
    print_info "Mihomo 安装完成！"
    echo "=========================================="
    echo ""
    echo "Dashboard 面板访问地址："

    # 显示 IPv4 地址
    if [[ -n "$ipv4" ]]; then
        echo "  IPv4: http://${ipv4}:19090/"
    fi

    # 显示 IPv6 地址（使用方括号包裹）
    if [[ -n "$ipv6" ]]; then
        echo "  IPv6: http://[${ipv6}]:19090/"
    fi

    echo ""
    echo "面板配置信息："

    # 显示 IPv4 配置
    if [[ -n "$ipv4" ]]; then
        echo "  IPv4 主机: ${ipv4}"
    fi

    # 显示 IPv6 配置
    if [[ -n "$ipv6" ]]; then
        echo "  IPv6 主机: ${ipv6}"
    fi

    echo "  端口: 9090"
    echo ""
    echo "配置文件夹位置："
    echo "  /home/docker/mihomo/clash_meta/clash"
    echo ""
    echo "配置文件取自 YouTuber @hj12123 hanjiang thanks."
    echo "=========================================="
}

# 主函数
main() {
    echo "=========================================="
    echo "  Mihomo Docker 一键安装脚本"
    echo "=========================================="
    echo ""

    # 1. 先获取并验证订阅链接
    get_and_verify_subscription
    echo ""

    # 2. 检查 root 权限
    check_root

    # 3. 检查 Docker 是否安装
    check_docker
    echo ""

    # 4. 创建目录结构
    create_directories

    # 5. 下载配置文件
    download_files

    # 6. 配置订阅链接
    configure_subscription

    # 7. 启动服务
    start_docker_compose

    # 8. 显示完成信息
    show_completion_message
}

# 运行主函数
main
