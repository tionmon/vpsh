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

# 显示网卡流量信息
show_network_interfaces() {
    print_info "当前网卡流量统计（接收/发送字节数）："
    echo ""
    echo "网卡名称          接收流量(MB)    发送流量(MB)    总流量(MB)"
    echo "------------------------------------------------------------"

    # 临时文件存储网卡信息
    local temp_file=$(mktemp)

    # 获取所有网卡及其流量信息
    for interface in $(ls /sys/class/net/ 2>/dev/null | grep -v "^lo$"); do
        if [[ -f "/sys/class/net/$interface/statistics/rx_bytes" ]]; then
            rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null || echo 0)
            tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null || echo 0)

            # 转换为 MB (使用纯 bash 算术)
            rx_mb=$((rx_bytes / 1024 / 1024))
            tx_mb=$((tx_bytes / 1024 / 1024))
            total_mb=$((rx_mb + tx_mb))

            # 保存到临时文件，按总流量排序
            echo "$total_mb $interface $rx_mb $tx_mb" >> "$temp_file"
        fi
    done

    # 按总流量排序并显示
    if [[ -f "$temp_file" ]]; then
        sort -rn "$temp_file" | while read total interface rx tx; do
            printf "%-15s %12s %15s %15s\n" "$interface" "$rx" "$tx" "$total"
        done
        rm -f "$temp_file"
    fi

    echo ""
}

# 检查 NAT 是否已配置
check_nat_configured() {
    # 检查 IP 转发是否开启
    local ipv4_forward=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo 0)
    local ipv6_forward=$(cat /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null || echo 0)

    # 检查是否有 MASQUERADE 规则
    local has_nat=$(iptables -t nat -L POSTROUTING -n 2>/dev/null | grep -c MASQUERADE || echo 0)

    if [[ "$ipv4_forward" == "1" ]] && [[ "$ipv6_forward" == "1" ]] && [[ "$has_nat" -gt 0 ]]; then
        return 0  # 已配置
    else
        return 1  # 未配置
    fi
}

# 配置 IP 转发与 NAT
configure_nat() {
    echo ""
    echo "=========================================="
    print_info "透明网关配置"
    echo "=========================================="
    echo ""

    # 显示网卡流量统计
    show_network_interfaces

    print_info "请输入网卡名称（通常选择总流量最大的网卡）："
    read -r interface_name

    # 检查输入是否为空
    while [[ -z "$interface_name" ]]; do
        print_warning "网卡名称不能为空！"
        read -r interface_name
    done

    # 检查网卡是否存在
    if [[ ! -d "/sys/class/net/$interface_name" ]]; then
        print_error "网卡 $interface_name 不存在！"
        return 1
    fi

    print_info "开始配置 IP 转发与 NAT..."

    # 1. 开启 IPv4 转发
    print_info "开启 IPv4 转发..."
    sysctl -w net.ipv4.ip_forward=1 &>/dev/null
    print_info "IPv4 转发已开启"

    # 2. 开启 IPv6 转发
    print_info "开启 IPv6 转发..."
    sysctl -w net.ipv6.conf.all.forwarding=1 &>/dev/null
    print_info "IPv6 转发已开启"

    # 3. 配置 NAT 规则（检查是否已存在）
    print_info "配置 NAT 规则..."
    if iptables -t nat -C POSTROUTING -o "$interface_name" -j MASQUERADE 2>/dev/null; then
        print_info "NAT 规则已存在"
    else
        iptables -t nat -A POSTROUTING -o "$interface_name" -j MASQUERADE
        print_info "NAT 规则添加成功"
    fi

    # 4. 固化配置
    print_info "固化配置（重启后仍然有效）..."

    # 持久化 IP 转发到 /etc/sysctl.conf
    if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
    if ! grep -q "^net.ipv6.conf.all.forwarding=1" /etc/sysctl.conf 2>/dev/null; then
        echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    fi

    # 保存网卡名到配置文件，用于卸载
    echo "$interface_name" > /home/docker/mihomo/.nat_interface 2>/dev/null

    # 保存 iptables 规则
    mkdir -p /etc/iptables 2>/dev/null
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save 2>/dev/null && print_info "iptables 规则已保存 (netfilter-persistent)"
    else
        iptables-save > /etc/iptables/rules.v4 2>/dev/null && print_info "iptables 规则已保存到 /etc/iptables/rules.v4"
    fi

    echo ""
    print_info "IP 转发与 NAT 配置完成！"
    echo ""
    echo "配置信息："
    echo "  网卡: $interface_name"
    echo "  IPv4 转发: 已开启"
    echo "  IPv6 转发: 已开启"
    echo "  NAT 规则: 已配置"
    echo "  配置已固化: 重启后仍然有效"
    echo ""
}

# 卸载 NAT 配置
uninstall_nat() {
    print_info "卸载 IP 转发与 NAT 配置..."

    # 读取之前保存的网卡名
    if [[ -f /home/docker/mihomo/.nat_interface ]]; then
        local interface_name=$(cat /home/docker/mihomo/.nat_interface)
        # 删除 NAT 规则
        if iptables -t nat -C POSTROUTING -o "$interface_name" -j MASQUERADE 2>/dev/null; then
            iptables -t nat -D POSTROUTING -o "$interface_name" -j MASQUERADE 2>/dev/null
            print_info "已删除 NAT 规则"
        fi
    else
        # 尝试删除所有 MASQUERADE 规则
        while iptables -t nat -D POSTROUTING -j MASQUERADE 2>/dev/null; do
            :
        done
        print_info "已尝试删除所有 MASQUERADE 规则"
    fi

    # 删除 sysctl.conf 中的配置
    if [[ -f /etc/sysctl.conf ]]; then
        sed -i '/^net.ipv4.ip_forward=1/d' /etc/sysctl.conf 2>/dev/null
        sed -i '/^net.ipv6.conf.all.forwarding=1/d' /etc/sysctl.conf 2>/dev/null
        print_info "已删除 sysctl.conf 中的配置"
    fi

    # 关闭 IP 转发
    sysctl -w net.ipv4.ip_forward=0 &>/dev/null
    sysctl -w net.ipv6.conf.all.forwarding=0 &>/dev/null
    print_info "已关闭 IP 转发"

    # 保存 iptables 规则
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save 2>/dev/null
    else
        mkdir -p /etc/iptables 2>/dev/null
        iptables-save > /etc/iptables/rules.v4 2>/dev/null
    fi

    print_info "NAT 配置卸载完成"
}

# 完整卸载
uninstall_mihomo() {
    echo ""
    echo "=========================================="
    print_warning "卸载 Mihomo"
    echo "=========================================="
    echo ""

    read -p "确认要卸载 Mihomo 吗？这将删除所有配置文件！(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "取消卸载"
        return 0
    fi

    # 停止并删除容器
    if [[ -d /home/docker/mihomo ]]; then
        print_info "停止并删除 Docker 容器..."
        cd /home/docker/mihomo 2>/dev/null && docker compose down 2>/dev/null
        print_info "Docker 容器已停止"
    fi

    # 卸载 NAT 配置
    if check_nat_configured; then
        uninstall_nat
    fi

    # 删除文件夹
    if [[ -d /home/docker/mihomo ]]; then
        print_info "删除 /home/docker/mihomo 文件夹..."
        rm -rf /home/docker/mihomo
        print_info "文件夹已删除"
    fi

    echo ""
    print_info "Mihomo 卸载完成！"
    echo ""
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

    # 检查 root 权限
    check_root

    # 检查是否已安装
    if [[ -d /home/docker/mihomo ]]; then
        print_warning "检测到 Mihomo 已安装！"
        echo ""
        echo "请选择操作："
        echo "  1) 卸载 Mihomo"
        echo "  2) 配置透明网关（IP 转发与 NAT）"
        echo "  3) 退出"
        echo ""
        read -p "请输入选项 (1-3): " -n 1 -r choice
        echo ""
        echo ""

        case $choice in
            1)
                uninstall_mihomo
                exit 0
                ;;
            2)
                if check_nat_configured; then
                    print_info "透明网关已配置"
                    echo ""
                    read -p "是否重新配置？(y/n): " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                        print_info "退出"
                        exit 0
                    fi
                    # 先卸载旧配置
                    uninstall_nat
                fi
                # 配置透明网关
                configure_nat
                exit 0
                ;;
            3)
                print_info "退出"
                exit 0
                ;;
            *)
                print_error "无效的选项"
                exit 1
                ;;
        esac
    fi

    # 以下是全新安装流程
    echo ""

    # 1. 先获取并验证订阅链接
    get_and_verify_subscription
    echo ""

    # 2. 检查 Docker 是否安装
    check_docker
    echo ""

    # 3. 创建目录结构
    create_directories

    # 4. 下载配置文件
    download_files

    # 5. 配置订阅链接
    configure_subscription

    # 6. 启动服务
    start_docker_compose

    # 7. 显示完成信息
    show_completion_message

    # 8. 询问是否配置透明网关
    echo ""
    read -p "是否需要开启 IP 转发与 NAT（实现透明网关功能）？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        configure_nat
    else
        print_info "跳过透明网关配置"
    fi

    echo ""
    print_info "全部完成！"
}

# 运行主函数
main
