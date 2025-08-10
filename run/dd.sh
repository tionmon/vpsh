#!/bin/bash

# 一键系统重装脚本
# 支持多种Linux发行版

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的文本
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

# 显示标题
show_banner() {
    echo -e "${GREEN}"
    echo "================================================"
    echo "           一键系统重装脚本"
    echo "        支持多种Linux发行版重装"
    echo "================================================"
    echo -e "${NC}"
}

# 显示系统选项菜单
show_menu() {
    echo -e "${YELLOW}请选择要安装的操作系统:${NC}"
    echo ""
    echo "1)  Debian 13"
    echo "2)  Debian 12 (推荐)"
    echo "3)  Debian 11"
    echo "4)  Debian 10"
    echo "5)  Debian 9"
    echo "6)  Ubuntu 24.04 LTS"
    echo "7)  Ubuntu 22.04 LTS"
    echo "8)  Ubuntu 20.04 LTS"
    echo "9)  Ubuntu 18.04 LTS"
    echo "10) Ubuntu 16.04 LTS"
    echo "11) CentOS 10"
    echo "12) CentOS 9"
    echo "13) Rocky Linux 10"
    echo "14) Rocky Linux 9"
    echo "15) Rocky Linux 8"
    echo "16) AlmaLinux 10"
    echo "17) AlmaLinux 9"
    echo "18) AlmaLinux 8"
    echo "19) Oracle Linux 9"
    echo "20) Oracle Linux 8"
    echo "21) Fedora 42"
    echo "22) Fedora 41"
    echo "23) OpenSUSE 15.6"
    echo "24) OpenSUSE Tumbleweed"
    echo "25) Alpine 3.22"
    echo "26) Alpine 3.21"
    echo "27) Alpine 3.20"
    echo "28) Alpine 3.19"
    echo "29) Anolis 23"
    echo "30) Anolis 8"
    echo "31) Anolis 7"
    echo "32) OpenCloudOS 23"
    echo "33) OpenCloudOS 9"
    echo "34) OpenCloudOS 8"
    echo "35) OpenEuler 25.03"
    echo "36) OpenEuler 24.03"
    echo "37) OpenEuler 22.03"
    echo "38) OpenEuler 20.03"
    echo "39) NixOS 25.05"
    echo "40) Kali Linux"
    echo "41) Arch Linux"
    echo "42) Gentoo"
    echo "43) AOSC OS"
    echo "44) Fedora CoreOS"
    echo ""
    echo "0)  退出脚本"
    echo ""
}

# 获取系统参数
get_system_params() {
    case $1 in
        1) echo "debian 13" ;;
        2) echo "debian 12" ;;
        3) echo "debian 11" ;;
        4) echo "debian 10" ;;
        5) echo "debian 9" ;;
        6) echo "ubuntu 24.04" ;;
        7) echo "ubuntu 22.04" ;;
        8) echo "ubuntu 20.04" ;;
        9) echo "ubuntu 18.04" ;;
        10) echo "ubuntu 16.04" ;;
        11) echo "centos 10" ;;
        12) echo "centos 9" ;;
        13) echo "rocky 10" ;;
        14) echo "rocky 9" ;;
        15) echo "rocky 8" ;;
        16) echo "almalinux 10" ;;
        17) echo "almalinux 9" ;;
        18) echo "almalinux 8" ;;
        19) echo "oracle 9" ;;
        20) echo "oracle 8" ;;
        21) echo "fedora 42" ;;
        22) echo "fedora 41" ;;
        23) echo "opensuse 15.6" ;;
        24) echo "opensuse tumbleweed" ;;
        25) echo "alpine 3.22" ;;
        26) echo "alpine 3.21" ;;
        27) echo "alpine 3.20" ;;
        28) echo "alpine 3.19" ;;
        29) echo "anolis 23" ;;
        30) echo "anolis 8" ;;
        31) echo "anolis 7" ;;
        32) echo "opencloudos 23" ;;
        33) echo "opencloudos 9" ;;
        34) echo "opencloudos 8" ;;
        35) echo "openeuler 25.03" ;;
        36) echo "openeuler 24.03" ;;
        37) echo "openeuler 22.03" ;;
        38) echo "openeuler 20.03" ;;
        39) echo "nixos 25.05" ;;
        40) echo "kali" ;;
        41) echo "arch" ;;
        42) echo "gentoo" ;;
        43) echo "aosc" ;;
        44) echo "fnos" ;;
        *) echo "" ;;
    esac
}

# 设置root密码
set_password() {
    echo ""
    print_info "请设置root用户密码 (默认: password)"
    read -p "请输入密码 [password]: " password
    password=${password:-password}
    print_success "密码设置为: $password"
}

# 确认安装
confirm_install() {
    local system_params="$1"
    local password="$2"
    
    echo ""
    print_warning "=== 安装确认 ==="
    print_info "系统: $system_params"
    print_info "密码: $password"
    print_warning "警告: 此操作将完全重装系统，所有数据将被清除！"
    echo ""
    read -p "确认继续安装? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        return 0
    else
        print_info "安装已取消"
        return 1
    fi
}

# 下载并执行重装脚本
install_system() {
    local system_params="$1"
    local password="$2"
    
    print_info "开始下载重装脚本..."
    
    # 下载脚本
    if command -v curl >/dev/null 2>&1; then
        curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
    elif command -v wget >/dev/null 2>&1; then
        wget -O reinstall.sh https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
    else
        print_error "错误: 系统中没有找到 curl 或 wget 命令"
        exit 1
    fi
    
    if [ ! -f "reinstall.sh" ]; then
        print_error "脚本下载失败"
        exit 1
    fi
    
    print_success "脚本下载完成"
    
    # 给脚本执行权限
    chmod +x reinstall.sh
    
    print_info "开始执行系统重装..."
    print_warning "系统将在安装完成后自动重启"
    
    # 执行重装命令
    bash reinstall.sh $system_params --password "$password"
    
    # 如果脚本没有自动重启，手动重启
    print_info "准备重启系统..."
    sleep 3
    reboot
}

# 主函数
main() {
    # 检查是否为root用户
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用root权限运行此脚本"
        print_info "使用命令: sudo $0"
        exit 1
    fi
    
    show_banner
    
    while true; do
        show_menu
        read -p "请输入选项 [1-43, 0退出]: " choice
        
        case $choice in
            0)
                print_info "退出脚本"
                exit 0
                ;;
            [1-9]|[1-3][0-9]|4[0-3])
                system_params=$(get_system_params $choice)
                if [ -n "$system_params" ]; then
                    set_password
                    if confirm_install "$system_params" "$password"; then
                        install_system "$system_params" "$password"
                    fi
                    break
                else
                    print_error "无效选项: $choice"
                fi
                ;;
            *)
                print_error "无效选项: $choice"
                ;;
        esac
        echo ""
    done
}

# 运行主函数
main "$@"