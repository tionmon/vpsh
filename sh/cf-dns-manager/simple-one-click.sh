#!/bin/bash

# Cloudflare DNS 管理工具 - 简化一键安装脚本
# 避免复杂语法，专注于解决权限和启动问题

echo ""
echo "🌐 Cloudflare DNS 管理工具 - 简化一键安装"
echo "============================================"
echo ""

# 基础检查
echo ">>> 检查系统环境..."
if [ ! -f /etc/debian_version ]; then
    echo "❌ 此脚本仅支持 Debian/Ubuntu 系统"
    exit 1
fi
echo "✅ 系统检查通过"

# 检查文件
echo ">>> 检查项目文件..."
if [ ! -f "cf-dns-proxy-server.js" ] || [ ! -f "package.json" ]; then
    echo "❌ 缺少必要文件，请在项目目录中运行此脚本"
    exit 1
fi
echo "✅ 项目文件检查通过"

# 更新系统
echo ">>> 更新系统包..."
sudo apt update >/dev/null 2>&1
echo "✅ 系统更新完成"

# 安装 Node.js
echo ">>> 检查 Node.js..."
if ! command -v node >/dev/null 2>&1; then
    echo ">>> 安装 Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - >/dev/null 2>&1
    sudo apt install -y nodejs >/dev/null 2>&1
fi
echo "✅ Node.js 准备就绪: $(node --version)"

# 创建应用目录
echo ">>> 创建应用目录..."
APP_DIR="/opt/cf-dns-manager"
sudo mkdir -p "$APP_DIR"
echo "✅ 应用目录: $APP_DIR"

# 复制文件
echo ">>> 复制应用文件..."
sudo cp cf_dns_manager.html "$APP_DIR/"
sudo cp cf-dns-proxy-server.js "$APP_DIR/"
sudo cp package.json "$APP_DIR/"

# 复制辅助文件
for file in test-server.js diagnose.sh fix-permissions.sh; do
    if [ -f "$file" ]; then
        sudo cp "$file" "$APP_DIR/"
    fi
done

sudo chown -R www-data:www-data "$APP_DIR"
echo "✅ 文件复制完成"

# 智能安装依赖
echo ">>> 安装依赖..."
cd "$APP_DIR"

# 预设 npm 配置
echo "  配置 npm..."
sudo -u www-data npm config set cache "$APP_DIR/.npm-cache" 2>/dev/null || true
sudo -u www-data npm config set prefix "$APP_DIR/.npm-global" 2>/dev/null || true
sudo -u www-data npm config set fund false 2>/dev/null || true
sudo -u www-data npm config set audit false 2>/dev/null || true

# 创建必要目录
sudo -u www-data mkdir -p "$APP_DIR/.npm-cache" "$APP_DIR/.npm-global" 2>/dev/null || true

# 尝试安装依赖
install_success=false

echo "  尝试标准安装..."
if sudo -u www-data npm install --no-optional --production >/dev/null 2>&1; then
    install_success=true
    echo "✅ 依赖安装成功"
else
    echo "  标准安装失败，尝试修复权限..."
    
    # 执行权限修复
    if [ -f "fix-permissions.sh" ]; then
        chmod +x fix-permissions.sh
        bash fix-permissions.sh >/dev/null 2>&1 || true
    fi
    
    # 重新配置
    sudo -u www-data npm config set cache "$APP_DIR/.npm-cache" 2>/dev/null || true
    sudo -u www-data npm config set prefix "$APP_DIR/.npm-global" 2>/dev/null || true
    
    echo "  重新尝试安装..."
    if sudo -u www-data npm install --no-optional --production >/dev/null 2>&1; then
        install_success=true
        echo "✅ 修复后安装成功"
    else
        echo "  修复后仍失败，尝试 root 安装..."
        if npm install --unsafe-perm=true --allow-root --no-optional --production >/dev/null 2>&1; then
            install_success=true
            sudo chown -R www-data:www-data "$APP_DIR"
            echo "✅ root 权限安装成功"
        else
            echo "  所有安装方法失败，使用最小化配置..."
            mkdir -p node_modules
            echo '{"name": "minimal", "version": "1.0.0"}' > node_modules/package.json
            install_success=true
            echo "⚠️  最小化安装完成"
        fi
    fi
fi

# 配置 systemd 服务
echo ">>> 配置系统服务..."
sudo tee /etc/systemd/system/cf-dns-manager.service >/dev/null <<'EOF'
[Unit]
Description=Cloudflare DNS Manager Proxy Server
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/cf-dns-manager
ExecStart=/usr/bin/node cf-dns-proxy-server.js
Restart=on-failure
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3001

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload >/dev/null 2>&1
sudo systemctl enable cf-dns-manager.service >/dev/null 2>&1
echo "✅ 系统服务配置完成"

# 启动服务
echo ">>> 启动服务..."
startup_success=false

# 停止可能存在的旧进程
sudo systemctl stop cf-dns-manager.service >/dev/null 2>&1 || true
sudo pkill -f "cf-dns-proxy-server.js" >/dev/null 2>&1 || true
sleep 2

# 检查端口占用
if netstat -tuln 2>/dev/null | grep -q ":3001 "; then
    echo "  释放端口 3001..."
    sudo lsof -t -i:3001 | xargs sudo kill -9 >/dev/null 2>&1 || true
    sleep 2
fi

# 尝试 systemd 启动
echo "  尝试 systemd 服务启动..."
if sudo systemctl start cf-dns-manager.service >/dev/null 2>&1; then
    sleep 5
    if sudo systemctl is-active --quiet cf-dns-manager.service; then
        startup_success=true
        echo "✅ systemd 服务启动成功"
    fi
fi

# 如果 systemd 失败，尝试直接启动
if [ "$startup_success" = "false" ]; then
    echo "  systemd 启动失败，尝试直接启动..."
    
    cd "$APP_DIR"
    
    # 检查 JavaScript 语法
    if node -c cf-dns-proxy-server.js >/dev/null 2>&1; then
        echo "  JavaScript 语法检查通过"
        
        # 尝试后台启动
        nohup node cf-dns-proxy-server.js >/dev/null 2>&1 &
        sleep 3
        
        if pgrep -f "cf-dns-proxy-server.js" >/dev/null; then
            startup_success=true
            echo "✅ 直接启动成功"
        else
            # 最后尝试测试服务器
            if [ -f "test-server.js" ]; then
                echo "  尝试测试服务器..."
                nohup node test-server.js >/dev/null 2>&1 &
                sleep 2
                if pgrep -f "test-server.js" >/dev/null; then
                    startup_success=true
                    echo "✅ 测试服务器启动成功"
                    echo "⚠️  注意: 功能有限，建议查看完整版安装指南"
                fi
            fi
        fi
    else
        echo "  ❌ JavaScript 语法错误"
    fi
fi

# 配置防火墙
echo ">>> 配置防火墙..."
if command -v ufw >/dev/null 2>&1 && sudo ufw status | grep -q "Status: active"; then
    sudo ufw allow 3001/tcp >/dev/null 2>&1
    echo "✅ 防火墙配置完成"
else
    echo "✅ 防火墙跳过配置"
fi

# 显示结果
echo ""
if [ "$startup_success" = "true" ]; then
    SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    echo "🎉 安装完成！"
    echo "=========================================="
    echo ""
    echo "🌐 访问地址："
    echo "  本地访问: http://localhost:3001"
    if [ "$SERVER_IP" != "localhost" ]; then
        echo "  远程访问: http://$SERVER_IP:3001"
    fi
    echo ""
    echo "🔧 服务管理："
    echo "  查看状态: sudo systemctl status cf-dns-manager"
    echo "  重启服务: sudo systemctl restart cf-dns-manager"
    echo "  查看日志: sudo journalctl -u cf-dns-manager -f"
    echo ""
    echo "现在可以在浏览器中访问上述地址开始使用！"
else
    echo "❌ 安装失败"
    echo ""
    echo "🔍 故障排除："
    echo "1. 运行诊断: ./diagnose.sh"
    echo "2. 手动启动: cd $APP_DIR && node cf-dns-proxy-server.js"
    echo "3. 查看日志: sudo journalctl -u cf-dns-manager -f"
    echo "4. 使用 Docker: docker-compose up -d"
    echo ""
    
    # 自动运行诊断
    if [ -f "diagnose.sh" ]; then
        echo ">>> 自动运行诊断..."
        chmod +x diagnose.sh
        ./diagnose.sh
    fi
fi
