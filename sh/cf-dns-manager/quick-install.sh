#!/bin/bash

# Cloudflare DNS 管理工具 - 快速安装脚本 (Debian 12)

set -e

echo "🌐 Cloudflare DNS 管理工具 - 快速安装"
echo "====================================="

# 检查是否为 Debian 系统
if [ ! -f /etc/debian_version ]; then
    echo "❌ 错误：此脚本仅支持 Debian 系统"
    exit 1
fi

echo "✅ 检测到 Debian 系统"

# 检查必要文件
echo ">>> 检查必要文件..."
if [ ! -f "cf-dns-proxy-server.js" ]; then
    echo "❌ 找不到 cf-dns-proxy-server.js 文件"
    echo "请确保在包含所有文件的目录中运行此脚本"
    exit 1
fi

if [ ! -f "package.json" ]; then
    echo "❌ 找不到 package.json 文件"
    echo "请确保在包含所有文件的目录中运行此脚本"
    exit 1
fi

# 更新包管理器
echo "📦 更新系统包..."
sudo apt update

# 安装基础依赖
sudo apt install -y curl wget

# 安装 Node.js 和 npm
echo "🔧 检查 Node.js..."
if ! command -v node &> /dev/null; then
    echo ">>> 安装 Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
else
    echo "✅ Node.js 已安装"
fi

# 显示版本信息
echo "Node.js 版本: $(node --version)"
echo "npm 版本: $(npm --version)"

# 安装项目依赖
echo "📦 安装项目依赖..."

# 创建本地 npm 配置目录，避免权限问题
mkdir -p ./.npm-cache
mkdir -p ./.npm-global

# 设置 npm 配置
npm config set cache "$(pwd)/.npm-cache"
npm config set prefix "$(pwd)/.npm-global"

# 安装依赖
npm install --no-optional

# 获取服务器 IP
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")

# 启动服务
echo ""
echo "🚀 启动代理服务器..."
echo "本地访问: http://localhost:3001"
if [ "$SERVER_IP" != "localhost" ]; then
    echo "远程访问: http://$SERVER_IP:3001"
fi
echo "按 Ctrl+C 停止服务"
echo ""

# 检查端口是否被占用
if netstat -tuln 2>/dev/null | grep -q ":3001 "; then
    echo "⚠️  端口 3001 已被占用，尝试使用端口 3002..."
    PORT=3002 node cf-dns-proxy-server.js
else
    node cf-dns-proxy-server.js
fi
