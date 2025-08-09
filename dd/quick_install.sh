#!/bin/bash

# 快速一键重装脚本 - Debian 12 (默认)
# 使用方法: bash quick_install.sh [系统] [版本] [密码]
# 例如: bash quick_install.sh debian 12 mypassword

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 默认参数
OS_NAME=${1:-"debian"}
OS_VERSION=${2:-"12"}
ROOT_PASSWORD=${3:-"password"}

print_info "=== 快速系统重装脚本 ==="
print_info "系统: $OS_NAME $OS_VERSION"
print_info "密码: $ROOT_PASSWORD"
print_info "开始下载并执行重装脚本..."

# 下载并执行
curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh || wget -O reinstall.sh https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh

if [ ! -f "reinstall.sh" ]; then
    print_error "脚本下载失败"
    exit 1
fi

print_success "脚本下载完成，开始重装系统..."
bash reinstall.sh $OS_NAME $OS_VERSION --password "$ROOT_PASSWORD"

# 重启系统
print_info "系统重装完成，准备重启..."
sleep 3
reboot