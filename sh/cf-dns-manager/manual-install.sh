#!/bin/bash

# 手动安装脚本 - 避免权限问题

set -e

echo "🔧 Cloudflare DNS 管理工具 - 手动安装"
echo "======================================="

# 检查文件
if [ ! -f "package.json" ] || [ ! -f "cf-dns-proxy-server.js" ]; then
    echo "❌ 缺少必要文件，请确保在正确目录运行脚本"
    exit 1
fi

# 检查 Node.js
if ! command -v node &> /dev/null; then
    echo "❌ 未找到 Node.js，请先安装 Node.js"
    echo "安装命令："
    echo "curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
    echo "sudo apt install -y nodejs"
    exit 1
fi

echo "✅ Node.js 版本: $(node --version)"
echo "✅ npm 版本: $(npm --version)"

# 方法1：使用当前用户目录
echo ""
echo ">>> 方法1：在当前目录安装（推荐）"
echo "这将在当前目录安装依赖，避免权限问题"

# 创建本地配置
mkdir -p .npm-cache .npm-global

# 设置临时 npm 配置
export NPM_CONFIG_CACHE="$(pwd)/.npm-cache"
export NPM_CONFIG_PREFIX="$(pwd)/.npm-global"

# 安装依赖
echo "📦 安装依赖包..."

# 函数：尝试安装依赖
try_install() {
    npm install --no-optional --production 2>/dev/null
}

# 第一次尝试安装
if try_install; then
    echo "✅ 依赖安装成功"
    
    # 获取服务器 IP
    SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    echo ""
    echo "🚀 启动服务..."
    echo "本地访问: http://localhost:3001"
    if [ "$SERVER_IP" != "localhost" ]; then
        echo "远程访问: http://$SERVER_IP:3001"
    fi
    echo ""
    echo "按 Ctrl+C 停止服务"
    echo "如需后台运行，请使用: nohup node cf-dns-proxy-server.js &"
    echo ""
    
    # 启动应用
    node cf-dns-proxy-server.js
else
    echo ""
    echo "❌ 依赖安装失败，自动尝试修复..."
    
    # 自动执行权限修复
    echo ">>> 执行权限修复..."
    if [ -f "fix-permissions.sh" ]; then
        chmod +x fix-permissions.sh
        bash fix-permissions.sh
        source ~/.bashrc 2>/dev/null || true
        
        echo ">>> 权限修复完成，重新尝试安装..."
        if try_install; then
            echo "✅ 权限修复后安装成功"
        else
            echo ">>> 尝试 sudo 强制安装..."
            if sudo npm install --unsafe-perm=true --allow-root --no-optional --production; then
                echo "✅ sudo 安装成功"
            else
                echo "❌ 所有安装方法都失败了"
                echo ""
                echo "手动解决方案："
                echo "1. sudo chown -R \$USER:\$USER ~/.npm"
                echo "2. npm config set prefix ~/.npm-global"
                echo "3. export PATH=~/.npm-global/bin:\$PATH"
                echo "4. npm install"
                exit 1
            fi
        fi
    else
        echo ">>> fix-permissions.sh 不存在，使用内置修复..."
        
        # 内置权限修复
        NPM_DIR="$HOME/.npm-global"
        mkdir -p "$NPM_DIR"
        npm config set prefix "$NPM_DIR"
        npm config set cache "$HOME/.npm-cache"
        export PATH="$NPM_DIR/bin:$PATH"
        npm cache clean --force 2>/dev/null || true
        
        echo ">>> 重新尝试安装..."
        if try_install; then
            echo "✅ 权限修复后安装成功"
        else
            echo ">>> 最后尝试 sudo 安装..."
            sudo npm install --unsafe-perm=true --allow-root --no-optional --production
        fi
    fi
fi

if [ $? -eq 0 ]; then
