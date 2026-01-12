#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 询问用户确认
ask_confirm() {
    local prompt="$1"
    local response
    
    while true; do
        read -p "$(echo -e ${YELLOW}${prompt}${NC}) [Y/n]: " response
        response=${response:-Y}  # 默认为 Y
        
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                print_warning "请输入 Y/y (是) 或 N/n (否)"
                ;;
        esac
    done
}

# 检查命令是否执行成功
check_status() {
    if [ $? -eq 0 ]; then
        print_success "$1"
    else
        print_error "$2"
        return 1
    fi
}

# 1. 安装 Docker
install_docker() {
    print_info "开始安装 Docker..."
    bash <(curl -Ls sh.tionmon.de/wud)
    check_status "Docker 安装完成" "Docker 安装失败"
}

# 2. 安装基础工具
install_basic_tools() {
    print_info "开始安装基础工具..."
    apt update -y && apt full-upgrade -y && apt install -y curl wget sudo unzip tar
    check_status "基础工具安装完成" "基础工具安装失败"
}

# 3. BBR 网络优化
install_bbr() {
    print_info "开始执行 BBR 网络优化..."
    bash <(curl -sL https://raw.githubusercontent.com/yahuisme/network-optimization/main/script.sh)
    check_status "BBR 优化完成" "BBR 优化失败"
}

# 4. 安装 Caddy
install_caddy() {
    print_info "开始安装 Caddy..."
    sudo apt update && \
    sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https ca-certificates curl gnupg && \
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg && \
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null && \
    sudo apt update && \
    sudo apt install -y caddy
    check_status "Caddy 安装完成" "Caddy 安装失败"
}

# 主函数
main() {
    clear
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║     Linux VPS 初始化一键脚本                   ║"
    echo "║     VPS Initialization Script                  ║"
    echo "╚════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # 检查是否为 root 用户
    if [ "$EUID" -ne 0 ]; then 
        print_error "请使用 root 用户运行此脚本"
        exit 1
    fi
    
    # 询问执行模式
    print_info "请选择执行模式："
    echo "  输入 'a' 或 'A' - 自动执行所有步骤"
    echo "  输入其他任意键  - 自定义选择安装项"
    read -p "$(echo -e ${YELLOW}您的选择:${NC}) " mode
    
    echo ""
    
    # 声明选择变量
    local install_docker_opt=false
    local install_basic=false
    local install_bbr_opt=false
    local install_caddy_opt=false
    local auto_mode=false
    
    if [[ "$mode" == "a" || "$mode" == "A" ]]; then
        print_info "已选择自动模式，将执行所有步骤"
        install_docker_opt=true
        install_basic=true
        install_bbr_opt=true
        install_caddy_opt=true
        auto_mode=true
        
        echo ""
        echo -e "${GREEN}════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}开始执行安装...${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════${NC}"
        echo ""
    else
        print_info "已选择自定义模式，请选择需要安装的项目"
        echo ""
        
        # 一次性询问所有选项
        print_info "=== 请选择需要安装的项目 ==="
        echo ""
        
        if ask_confirm "1/4: 是否安装 Docker 容器引擎?"; then
            install_docker_opt=true
        fi
        echo ""
        
        if ask_confirm "2/4: 是否安装基础工具 (curl, wget, sudo, unzip, tar)?"; then
            install_basic=true
        fi
        echo ""
        
        if ask_confirm "3/4: 是否执行 BBR 网络优化?"; then
            install_bbr_opt=true
        fi
        echo ""
        
        if ask_confirm "4/4: 是否安装 Caddy Web 服务器?"; then
            install_caddy_opt=true
        fi
        echo ""
        
        # 显示安装计划
        echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║              安装计划确认                      ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
        echo ""
        
        if $install_docker_opt; then
            echo -e "  ${GREEN}✓${NC} 安装 Docker"
        else
            echo -e "  ${RED}✗${NC} 跳过 Docker"
        fi
        
        if $install_basic; then
            echo -e "  ${GREEN}✓${NC} 安装基础工具"
        else
            echo -e "  ${RED}✗${NC} 跳过基础工具"
        fi
        
        if $install_bbr_opt; then
            echo -e "  ${GREEN}✓${NC} BBR 网络优化"
        else
            echo -e "  ${RED}✗${NC} 跳过 BBR 优化"
        fi
        
        if $install_caddy_opt; then
            echo -e "  ${GREEN}✓${NC} 安装 Caddy"
        else
            echo -e "  ${RED}✗${NC} 跳过 Caddy"
        fi
        
        echo ""
        read -p "$(echo -e ${YELLOW}确认开始安装？${NC}) [Y/n]: " confirm
        confirm=${confirm:-Y}
        
        if [[ ! "$confirm" =~ ^[Yy]([Ee][Ss])?$ ]]; then
            print_warning "安装已取消"
            exit 0
        fi
        
        echo ""
        echo -e "${GREEN}════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}开始执行安装...${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════${NC}"
        echo ""
    fi
    
    # 按顺序执行安装
    local step=1
    local total_steps=0
    
    # 计算总步骤数
    $install_docker_opt && ((total_steps++))
    $install_basic && ((total_steps++))
    $install_bbr_opt && ((total_steps++))
    $install_caddy_opt && ((total_steps++))
    
    # 1. Docker 安装（优先）
    if $install_docker_opt; then
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "步骤 $step/$total_steps: 安装 Docker"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        install_docker
        echo ""
        ((step++))
    fi
    
    # 2. 基础工具安装
    if $install_basic; then
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "步骤 $step/$total_steps: 安装基础工具"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        install_basic_tools
        echo ""
        ((step++))
    fi
    
    # 3. BBR 优化
    if $install_bbr_opt; then
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "步骤 $step/$total_steps: BBR 网络优化"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        install_bbr
        echo ""
        ((step++))
    fi
    
    # 4. Caddy 安装
    if $install_caddy_opt; then
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "步骤 $step/$total_steps: 安装 Caddy"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        install_caddy
        echo ""
        ((step++))
    fi
    
    # 完成提示
    echo ""
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║            初始化脚本执行完成！                ║"
    echo "╚════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    print_info "安装摘要："
    $install_docker_opt && echo -e "  ${GREEN}✓${NC} Docker 容器引擎"
    $install_basic && echo -e "  ${GREEN}✓${NC} 基础工具: curl, wget, sudo, unzip, tar"
    $install_bbr_opt && echo -e "  ${GREEN}✓${NC} BBR 网络优化"
    $install_caddy_opt && echo -e "  ${GREEN}✓${NC} Caddy Web 服务器"
    echo ""
    
    if $install_bbr_opt; then
        print_warning "建议重启系统以使 BBR 优化生效: sudo reboot"
    fi
}

# 执行主函数
main

