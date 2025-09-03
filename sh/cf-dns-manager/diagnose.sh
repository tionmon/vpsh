#!/bin/bash

# Cloudflare DNS 管理工具 - 诊断脚本
# 用于排查安装和启动问题

echo "🔍 Cloudflare DNS 管理工具 - 系统诊断"
echo "======================================="
echo ""

APP_DIR="/opt/cf-dns-manager"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_check() {
    local status=$1
    local message=$2
    if [ "$status" = "ok" ]; then
        echo -e "${GREEN}✅ $message${NC}"
    elif [ "$status" = "warning" ]; then
        echo -e "${YELLOW}⚠️  $message${NC}"
    else
        echo -e "${RED}❌ $message${NC}"
    fi
}

print_section() {
    echo ""
    echo -e "${BLUE}>>> $1${NC}"
}

# 1. 系统环境检查
print_section "系统环境检查"

# 操作系统
if [ -f /etc/debian_version ]; then
    version=$(cat /etc/debian_version)
    print_check "ok" "操作系统: Debian $version"
else
    print_check "error" "非 Debian 系统"
fi

# Node.js 检查
if command -v node >/dev/null 2>&1; then
    node_version=$(node --version)
    print_check "ok" "Node.js 版本: $node_version"
    
    # 检查版本是否满足要求
    major_version=$(echo $node_version | sed 's/v//' | cut -d. -f1)
    if [ "$major_version" -ge 14 ]; then
        print_check "ok" "Node.js 版本满足要求 (>= 14.0)"
    else
        print_check "error" "Node.js 版本过低，需要 >= 14.0"
    fi
else
    print_check "error" "Node.js 未安装"
fi

# npm 检查
if command -v npm >/dev/null 2>&1; then
    npm_version=$(npm --version)
    print_check "ok" "npm 版本: $npm_version"
else
    print_check "error" "npm 未安装"
fi

# 2. 应用文件检查
print_section "应用文件检查"

if [ -d "$APP_DIR" ]; then
    print_check "ok" "应用目录存在: $APP_DIR"
    
    # 检查关键文件
    files=("cf_dns_manager.html" "cf-dns-proxy-server.js" "package.json")
    for file in "${files[@]}"; do
        if [ -f "$APP_DIR/$file" ]; then
            size=$(ls -lh "$APP_DIR/$file" | awk '{print $5}')
            print_check "ok" "文件存在: $file ($size)"
        else
            print_check "error" "文件缺失: $file"
        fi
    done
    
    # 检查依赖
    if [ -d "$APP_DIR/node_modules" ]; then
        deps_count=$(ls -1 "$APP_DIR/node_modules" 2>/dev/null | wc -l)
        print_check "ok" "依赖已安装 ($deps_count 个包)"
    else
        print_check "error" "依赖未安装 (node_modules 不存在)"
    fi
else
    print_check "error" "应用目录不存在: $APP_DIR"
fi

# 3. 权限检查
print_section "权限检查"

if [ -d "$APP_DIR" ]; then
    # 文件所有者
    owner=$(ls -ld "$APP_DIR" | awk '{print $3":"$4}')
    print_check "ok" "目录所有者: $owner"
    
    # 文件权限
    perms=$(ls -ld "$APP_DIR" | awk '{print $1}')
    print_check "ok" "目录权限: $perms"
    
    # 检查关键文件权限
    if [ -f "$APP_DIR/cf-dns-proxy-server.js" ]; then
        if [ -r "$APP_DIR/cf-dns-proxy-server.js" ]; then
            print_check "ok" "应用文件可读"
        else
            print_check "error" "应用文件不可读"
        fi
    fi
fi

# 检查 npm 配置
if command -v npm >/dev/null 2>&1; then
    npm_prefix=$(npm config get prefix 2>/dev/null || echo "未设置")
    npm_cache=$(npm config get cache 2>/dev/null || echo "未设置")
    print_check "ok" "npm prefix: $npm_prefix"
    print_check "ok" "npm cache: $npm_cache"
    
    # 检查是否有权限问题
    if echo "$npm_prefix" | grep -q "/usr"; then
        print_check "warning" "npm 使用系统目录，可能有权限问题"
    fi
fi

# 4. 网络和端口检查
print_section "网络和端口检查"

# 检查端口占用
if command -v netstat >/dev/null 2>&1; then
    if netstat -tuln 2>/dev/null | grep -q ":3001 "; then
        pid=$(sudo lsof -t -i:3001 2>/dev/null || echo "未知")
        print_check "warning" "端口 3001 被占用 (PID: $pid)"
    else
        print_check "ok" "端口 3001 可用"
    fi
else
    print_check "warning" "netstat 未安装，无法检查端口"
fi

# 检查防火墙
if command -v ufw >/dev/null 2>&1; then
    if sudo ufw status | grep -q "Status: active"; then
        if sudo ufw status | grep -q "3001"; then
            print_check "ok" "防火墙已开放 3001 端口"
        else
            print_check "warning" "防火墙未开放 3001 端口"
        fi
    else
        print_check "ok" "防火墙未启用"
    fi
fi

# 5. 服务状态检查
print_section "服务状态检查"

# systemd 服务
if systemctl list-unit-files | grep -q "cf-dns-manager.service"; then
    print_check "ok" "systemd 服务已注册"
    
    # 服务状态
    if sudo systemctl is-active --quiet cf-dns-manager.service; then
        print_check "ok" "服务正在运行"
    else
        status=$(sudo systemctl is-active cf-dns-manager.service 2>/dev/null || echo "unknown")
        print_check "error" "服务未运行 (状态: $status)"
    fi
    
    # 服务是否启用
    if sudo systemctl is-enabled --quiet cf-dns-manager.service; then
        print_check "ok" "服务已设置为开机启动"
    else
        print_check "warning" "服务未设置为开机启动"
    fi
else
    print_check "error" "systemd 服务未注册"
fi

# 进程检查
if pgrep -f "cf-dns-proxy-server.js" >/dev/null; then
    pid=$(pgrep -f "cf-dns-proxy-server.js")
    print_check "ok" "应用进程正在运行 (PID: $pid)"
else
    print_check "error" "应用进程未运行"
fi

# 6. 连接测试
print_section "连接测试"

# 本地连接测试
if command -v curl >/dev/null 2>&1; then
    if curl -s http://localhost:3001/health >/dev/null 2>&1; then
        print_check "ok" "本地连接测试成功"
    else
        print_check "error" "本地连接测试失败"
    fi
else
    print_check "warning" "curl 未安装，无法测试连接"
fi

# 7. 日志检查
print_section "最近日志"

if systemctl list-unit-files | grep -q "cf-dns-manager.service"; then
    echo "最近 5 条服务日志："
    sudo journalctl -u cf-dns-manager.service --no-pager -l | tail -5 || echo "无日志"
fi

echo ""

# 8. 修复建议
print_section "修复建议"

echo "根据诊断结果，建议采取以下措施："
echo ""

# 基于诊断结果给出建议
if ! command -v node >/dev/null 2>&1; then
    echo "1. 安装 Node.js:"
    echo "   curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
    echo "   sudo apt install -y nodejs"
    echo ""
fi

if [ ! -d "$APP_DIR/node_modules" ]; then
    echo "2. 安装依赖:"
    echo "   cd $APP_DIR"
    echo "   sudo npm install --unsafe-perm=true --allow-root"
    echo ""
fi

if ! sudo systemctl is-active --quiet cf-dns-manager.service 2>/dev/null; then
    echo "3. 手动启动测试:"
    echo "   cd $APP_DIR"
    echo "   node cf-dns-proxy-server.js"
    echo ""
    
    echo "4. 查看详细错误:"
    echo "   sudo journalctl -u cf-dns-manager -f"
    echo ""
fi

if netstat -tuln 2>/dev/null | grep -q ":3001 "; then
    echo "5. 释放端口:"
    echo "   sudo lsof -t -i:3001 | xargs sudo kill -9"
    echo ""
fi

echo "6. 重新运行安装:"
echo "   ./one-click-install.sh"
echo ""

echo "如需更多帮助，请查看 INSTALL-DEBIAN.md 文档"
