#!/bin/bash

# Cloudflare DNS 管理工具 - Debian 12 自动安装脚本
# 支持一键安装 Node.js、依赖包和系统服务

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 显示带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_header() {
    echo ""
    print_message $CYAN "=========================================="
    print_message $CYAN "  Cloudflare DNS 管理工具 - Debian 安装"
    print_message $CYAN "=========================================="
    echo ""
}

print_step() {
    print_message $BLUE ">>> $1"
}

print_success() {
    print_message $GREEN "✅ $1"
}

print_warning() {
    print_message $YELLOW "⚠️  $1"
}

print_error() {
    print_message $RED "❌ $1"
}

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_warning "检测到 root 用户，建议创建普通用户运行此服务"
        read -p "是否继续使用 root 用户安装？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_message $YELLOW "请创建普通用户后重新运行安装脚本"
            exit 1
        fi
    fi
}

# 检查系统版本
check_system() {
    print_step "检查系统环境..."
    
    if [ ! -f /etc/debian_version ]; then
        print_error "此脚本仅支持 Debian 系统"
        exit 1
    fi
    
    local version=$(cat /etc/debian_version)
    print_success "检测到 Debian 版本: $version"
    
    # 检查是否为 Debian 12
    if [[ $version == 12* ]] || [[ $version == "bookworm"* ]]; then
        print_success "Debian 12 (bookworm) 支持确认"
    else
        print_warning "检测到非 Debian 12 版本，可能存在兼容性问题"
        read -p "是否继续安装？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 更新系统包
update_system() {
    print_step "更新系统包..."
    sudo apt update
    sudo apt upgrade -y
    print_success "系统包更新完成"
}

# 安装基础依赖
install_dependencies() {
    print_step "安装基础依赖..."
    sudo apt install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates
    print_success "基础依赖安装完成"
}

# 安装 Node.js
install_nodejs() {
    print_step "安装 Node.js..."
    
    # 检查是否已安装 Node.js
    if command -v node &> /dev/null; then
        local node_version=$(node --version)
        print_warning "Node.js 已安装，版本: $node_version"
        
        # 检查版本是否满足要求 (>= 16.0.0)
        local major_version=$(echo $node_version | sed 's/v//' | cut -d. -f1)
        if [ "$major_version" -ge 16 ]; then
            print_success "Node.js 版本满足要求"
            return
        else
            print_warning "Node.js 版本过低，正在更新..."
        fi
    fi
    
    # 添加 NodeSource 仓库
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    
    # 安装 Node.js
    sudo apt install -y nodejs
    
    # 验证安装
    local node_version=$(node --version)
    local npm_version=$(npm --version)
    
    print_success "Node.js 安装完成"
    print_message $GREEN "  Node.js 版本: $node_version"
    print_message $GREEN "  npm 版本: $npm_version"
}

# 创建应用目录
create_app_directory() {
    print_step "创建应用目录..."
    
    local app_dir="/opt/cf-dns-manager"
    
    # 创建目录
    sudo mkdir -p $app_dir
    
    # 设置权限
    if [ "$EUID" -eq 0 ]; then
        # root 用户
        chown root:root $app_dir
    else
        # 普通用户
        sudo chown $USER:$USER $app_dir
    fi
    
    print_success "应用目录创建完成: $app_dir"
    echo $app_dir
}

# 复制文件
copy_files() {
    local app_dir=$1
    echo ">>> 复制应用文件..."
    
    # 检查源文件是否存在
    if [ ! -f "cf_dns_manager.html" ]; then
        print_error "找不到 cf_dns_manager.html 文件"
        exit 1
    fi
    
    if [ ! -f "cf-dns-proxy-server.js" ]; then
        print_error "找不到 cf-dns-proxy-server.js 文件"
        exit 1
    fi
    
    if [ ! -f "package.json" ]; then
        print_error "找不到 package.json 文件"
        exit 1
    fi
    
    # 复制主要文件
    sudo cp cf_dns_manager.html "$app_dir/"
    sudo cp cf-dns-proxy-server.js "$app_dir/"
    sudo cp package.json "$app_dir/"
    
    # 复制文档
    if [ -f README.md ]; then
        sudo cp README.md "$app_dir/"
    fi
    
    # 设置文件权限
    if [ "$EUID" -eq 0 ]; then
        chown -R root:root "$app_dir"
    else
        sudo chown -R $USER:$USER "$app_dir"
    fi
    
    print_success "文件复制完成"
}

# 安装 npm 依赖
install_npm_dependencies() {
    local app_dir=$1
    print_step "安装 npm 依赖..."
    
    cd $app_dir
    sudo npm install
    
    print_success "npm 依赖安装完成"
}

# 创建 systemd 服务
create_systemd_service() {
    local app_dir=$1
    print_step "创建 systemd 服务..."
    
    local service_file="/etc/systemd/system/cf-dns-manager.service"
    local user_name=$(whoami)
    
    if [ "$EUID" -eq 0 ]; then
        user_name="root"
    fi
    
    sudo tee $service_file > /dev/null <<EOF
[Unit]
Description=Cloudflare DNS Manager Proxy Server
Documentation=https://github.com/cf-dns-manager
After=network.target

[Service]
Type=simple
User=$user_name
WorkingDirectory=$app_dir
ExecStart=/usr/bin/node cf-dns-proxy-server.js
Restart=on-failure
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3001

# 安全设置
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$app_dir

# 日志设置
StandardOutput=journal
StandardError=journal
SyslogIdentifier=cf-dns-manager

[Install]
WantedBy=multi-user.target
EOF

    # 重载 systemd 配置
    sudo systemctl daemon-reload
    
    # 启用服务
    sudo systemctl enable cf-dns-manager.service
    
    print_success "systemd 服务创建完成"
}

# 配置防火墙
configure_firewall() {
    print_step "配置防火墙..."
    
    # 检查是否安装了 ufw
    if command -v ufw &> /dev/null; then
        print_message $YELLOW "检测到 ufw 防火墙"
        read -p "是否开放 3001 端口？(Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            print_warning "跳过防火墙配置"
        else
            sudo ufw allow 3001/tcp
            print_success "已开放 3001 端口"
        fi
    elif command -v iptables &> /dev/null; then
        print_warning "检测到 iptables，请手动配置防火墙规则："
        print_message $CYAN "sudo iptables -A INPUT -p tcp --dport 3001 -j ACCEPT"
    else
        print_warning "未检测到防火墙，请根据需要手动配置"
    fi
}

# 启动服务
start_service() {
    print_step "启动服务..."
    
    # 启动服务
    sudo systemctl start cf-dns-manager.service
    
    # 检查服务状态
    sleep 2
    if sudo systemctl is-active --quiet cf-dns-manager.service; then
        print_success "服务启动成功"
        
        # 显示服务状态
        print_message $GREEN "服务状态："
        sudo systemctl status cf-dns-manager.service --no-pager -l
    else
        print_error "服务启动失败"
        print_message $RED "错误日志："
        sudo journalctl -u cf-dns-manager.service --no-pager -l
        exit 1
    fi
}

# 显示完成信息
show_completion_info() {
    local app_dir=$1
    print_message $GREEN ""
    print_message $GREEN "=========================================="
    print_message $GREEN "           安装完成！"
    print_message $GREEN "=========================================="
    echo ""
    
    print_message $CYAN "🌐 访问地址："
    print_message $WHITE "  本地访问: http://localhost:3001"
    
    # 获取服务器 IP
    local server_ip=$(hostname -I | awk '{print $1}')
    if [ ! -z "$server_ip" ]; then
        print_message $WHITE "  远程访问: http://$server_ip:3001"
    fi
    
    echo ""
    print_message $CYAN "🔧 服务管理命令："
    print_message $WHITE "  启动服务: sudo systemctl start cf-dns-manager"
    print_message $WHITE "  停止服务: sudo systemctl stop cf-dns-manager"
    print_message $WHITE "  重启服务: sudo systemctl restart cf-dns-manager"
    print_message $WHITE "  查看状态: sudo systemctl status cf-dns-manager"
    print_message $WHITE "  查看日志: sudo journalctl -u cf-dns-manager -f"
    
    echo ""
    print_message $CYAN "📁 文件位置："
    print_message $WHITE "  应用目录: $app_dir"
    print_message $WHITE "  服务配置: /etc/systemd/system/cf-dns-manager.service"
    
    echo ""
    print_message $CYAN "🛡️  安全提醒："
    print_message $WHITE "  1. 请确保防火墙已正确配置"
    print_message $WHITE "  2. 建议使用 HTTPS 访问（可配置 Nginx 反向代理）"
    print_message $WHITE "  3. API Token 仅在浏览器本地存储"
    
    echo ""
    print_message $YELLOW "📖 更多信息请查看 README.md 文档"
}

# 主函数
main() {
    print_header
    
    # 检查系统
    check_root
    check_system
    
    # 安装过程
    update_system
    install_dependencies
    install_nodejs
    
    # 部署应用
    local app_dir=$(create_app_directory)
    copy_files $app_dir
    install_npm_dependencies $app_dir
    
    # 配置服务
    create_systemd_service $app_dir
    configure_firewall
    start_service
    
    # 完成
    show_completion_info $app_dir
}

# 执行主函数
main "$@"
