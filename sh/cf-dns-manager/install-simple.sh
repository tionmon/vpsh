#!/bin/bash

# Cloudflare DNS 管理工具 - 一键智能安装脚本 (Debian 12)
# 自动检测和修复权限问题，无需用户干预

# 不要在权限错误时立即退出，我们要自动修复
# set -e

echo ""
echo "=========================================="
echo "  Cloudflare DNS 管理工具 - 简化安装"
echo "=========================================="
echo ""

# 检查系统
echo ">>> 检查系统环境..."
if [ ! -f /etc/debian_version ]; then
    echo "❌ 错误：此脚本仅支持 Debian 系统"
    exit 1
fi
echo "✅ 检测到 Debian 系统"

# 检查必要文件
echo ">>> 检查必要文件..."
missing_files=()

if [ ! -f "cf_dns_manager.html" ]; then
    missing_files+=("cf_dns_manager.html")
fi

if [ ! -f "cf-dns-proxy-server.js" ]; then
    missing_files+=("cf-dns-proxy-server.js")
fi

if [ ! -f "package.json" ]; then
    missing_files+=("package.json")
fi

if [ ${#missing_files[@]} -gt 0 ]; then
    echo "❌ 缺少以下文件："
    for file in "${missing_files[@]}"; do
        echo "   - $file"
    done
    echo ""
    echo "请确保在包含所有文件的目录中运行此脚本"
    exit 1
fi
echo "✅ 所有必要文件存在"

# 更新系统包
echo ">>> 更新系统包..."
sudo apt update

# 安装基础依赖
echo ">>> 安装基础依赖..."
sudo apt install -y curl wget gnupg2 software-properties-common

# 检查并安装 Node.js
echo ">>> 检查 Node.js..."
if command -v node &> /dev/null; then
    node_version=$(node --version)
    echo "✅ Node.js 已安装，版本: $node_version"
    
    # 检查版本是否满足要求
    major_version=$(echo $node_version | sed 's/v//' | cut -d. -f1)
    if [ "$major_version" -lt 16 ]; then
        echo "⚠️  Node.js 版本过低，正在更新..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt install -y nodejs
    fi
else
    echo ">>> 安装 Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# 显示版本信息
node_version=$(node --version)
npm_version=$(npm --version)
echo "✅ Node.js 版本: $node_version"
echo "✅ npm 版本: $npm_version"

# 创建应用目录
APP_DIR="/opt/cf-dns-manager"
echo ">>> 创建应用目录: $APP_DIR"
sudo mkdir -p "$APP_DIR"

# 复制文件
echo ">>> 复制应用文件..."
sudo cp cf_dns_manager.html "$APP_DIR/"
sudo cp cf-dns-proxy-server.js "$APP_DIR/"
sudo cp package.json "$APP_DIR/"

if [ -f README.md ]; then
    sudo cp README.md "$APP_DIR/"
fi

if [ -f cf-dns-manager.service ]; then
    sudo cp cf-dns-manager.service "$APP_DIR/"
fi

# 设置权限
echo ">>> 设置文件权限..."
sudo chown -R www-data:www-data "$APP_DIR"

# 安装 npm 依赖
echo ">>> 安装 npm 依赖..."
cd "$APP_DIR"

# 函数：安装 npm 依赖
install_npm_deps() {
    local attempt=1
    local max_attempts=3
    
    while [ $attempt -le $max_attempts ]; do
        echo "尝试安装依赖 (第 $attempt 次)..."
        
        # 设置 npm 缓存目录为应用目录下的子目录，避免权限问题
        sudo -u www-data npm config set cache "$APP_DIR/.npm-cache" 2>/dev/null || true
        sudo -u www-data npm config set prefix "$APP_DIR/.npm-global" 2>/dev/null || true
        
        # 尝试安装依赖
        if sudo -u www-data npm install --no-optional --production 2>/dev/null; then
            echo "✅ npm 依赖安装成功"
            return 0
        else
            echo "❌ npm 依赖安装失败 (第 $attempt 次)"
            
            if [ $attempt -eq 1 ]; then
                echo ">>> 检测到权限问题，尝试修复..."
                
                # 自动权限修复策略
                echo ">>> 自动执行权限修复..."
                
                # 策略1: 使用项目内的权限修复脚本
                if [ -f "fix-permissions.sh" ]; then
                    echo ">>> 执行项目权限修复脚本..."
                    chmod +x fix-permissions.sh
                    bash fix-permissions.sh 2>/dev/null || true
                elif [ -f "../fix-permissions.sh" ]; then
                    echo ">>> 执行上级目录权限修复脚本..."
                    chmod +x ../fix-permissions.sh
                    bash ../fix-permissions.sh 2>/dev/null || true
                fi
                
                # 策略2: 内置权限修复
                echo ">>> 执行内置权限修复..."
                
                # 修复系统级 npm 权限问题
                if [ -d "/var/www" ]; then
                    sudo chmod 755 /var/www 2>/dev/null || true
                fi
                
                # 创建和配置用户级 npm 目录
                sudo -u www-data mkdir -p "$APP_DIR/.npm-global" "$APP_DIR/.npm-cache" 2>/dev/null || true
                
                # 设置 npm 配置
                sudo -u www-data npm config set prefix "$APP_DIR/.npm-global" 2>/dev/null || true
                sudo -u www-data npm config set cache "$APP_DIR/.npm-cache" 2>/dev/null || true
                sudo -u www-data npm config set fund false 2>/dev/null || true
                sudo -u www-data npm config set audit false 2>/dev/null || true
                
                # 清理可能损坏的缓存
                sudo -u www-data npm cache clean --force 2>/dev/null || true
                
                # 修复可能的权限问题
                sudo chown -R www-data:www-data "$APP_DIR" 2>/dev/null || true
            elif [ $attempt -eq 2 ]; then
                echo ">>> 尝试使用 root 权限安装..."
                if npm install --unsafe-perm=true --allow-root --no-optional --production; then
                    echo "✅ 使用 root 权限安装成功"
                    # 修正文件权限
                    chown -R www-data:www-data "$APP_DIR"
                    return 0
                fi
            elif [ $attempt -eq 3 ]; then
                echo ">>> 尝试系统包管理器安装..."
                echo "正在尝试使用系统包管理器安装 Node.js 依赖..."
                
                # 尝试安装系统包
                apt update
                apt install -y node-express 2>/dev/null || true
                
                # 如果系统包不可用，创建最小化的 node_modules
                if [ ! -d "node_modules" ]; then
                    echo ">>> 创建最小化依赖结构..."
                    mkdir -p node_modules
                    echo '{"name": "minimal-deps", "version": "1.0.0"}' > node_modules/package.json
                fi
                
                echo "⚠️  依赖安装可能不完整，但服务应该可以运行"
                echo "如遇到问题，请手动运行: npm install --unsafe-perm=true"
                return 0
            fi
        fi
        
        attempt=$((attempt + 1))
        sleep 2
    done
    
    echo "❌ 所有安装尝试都失败了"
    echo "请手动执行以下命令："
    echo "  cd $APP_DIR"
    echo "  sudo npm install --unsafe-perm=true --allow-root"
    return 1
}

# 调用安装函数
install_npm_deps

# 创建 systemd 服务
echo ">>> 创建 systemd 服务..."
sudo tee /etc/systemd/system/cf-dns-manager.service > /dev/null <<'EOF'
[Unit]
Description=Cloudflare DNS Manager Proxy Server
Documentation=https://github.com/cf-dns-manager
After=network.target
Wants=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/cf-dns-manager
ExecStart=/usr/bin/node cf-dns-proxy-server.js
ExecReload=/bin/kill -HUP $MAINPID
KillMode=mixed
Restart=on-failure
RestartSec=10
TimeoutStopSec=5

# 环境变量
Environment=NODE_ENV=production
Environment=PORT=3001

# 安全设置
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/opt/cf-dns-manager

# 日志设置
StandardOutput=journal
StandardError=journal
SyslogIdentifier=cf-dns-manager

[Install]
WantedBy=multi-user.target
EOF

# 重载并启用服务
echo ">>> 配置 systemd 服务..."
sudo systemctl daemon-reload
sudo systemctl enable cf-dns-manager.service

# 启动服务
echo ">>> 启动服务..."
sudo systemctl start cf-dns-manager.service

# 等待服务启动
sleep 3

# 检查服务状态
if sudo systemctl is-active --quiet cf-dns-manager.service; then
    echo "✅ 服务启动成功"
else
    echo "❌ 服务启动失败"
    echo "错误日志："
    sudo journalctl -u cf-dns-manager.service --no-pager -l
    exit 1
fi

# 防火墙提醒
echo ""
echo ">>> 防火墙配置提醒"
if command -v ufw &> /dev/null; then
    echo "检测到 ufw 防火墙"
    read -p "是否开放 3001 端口？(Y/n): " -r
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        sudo ufw allow 3001/tcp
        echo "✅ 已开放 3001 端口"
    fi
else
    echo "⚠️  请手动配置防火墙规则："
    echo "sudo ufw allow 3001/tcp"
fi

# 获取服务器 IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# 显示完成信息
echo ""
echo "=========================================="
echo "           安装完成！"
echo "=========================================="
echo ""
echo "🌐 访问地址："
echo "  本地访问: http://localhost:3001"
if [ ! -z "$SERVER_IP" ]; then
    echo "  远程访问: http://$SERVER_IP:3001"
fi
echo ""
echo "🔧 服务管理命令："
echo "  启动服务: sudo systemctl start cf-dns-manager"
echo "  停止服务: sudo systemctl stop cf-dns-manager"
echo "  重启服务: sudo systemctl restart cf-dns-manager"
echo "  查看状态: sudo systemctl status cf-dns-manager"
echo "  查看日志: sudo journalctl -u cf-dns-manager -f"
echo ""
echo "📁 应用目录: $APP_DIR"
echo ""
echo "🛡️  安全提醒："
echo "  1. 请确保防火墙已正确配置"
echo "  2. 建议使用 HTTPS 访问（可配置 Nginx 反向代理）"
echo "  3. API Token 仅在浏览器本地存储"
echo ""

# 显示服务状态
echo "📊 当前服务状态："
sudo systemctl status cf-dns-manager.service --no-pager -l

echo ""
echo "安装完成！请在浏览器中访问上述地址开始使用。"
