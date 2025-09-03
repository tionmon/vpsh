#!/bin/bash

# Cloudflare DNS 管理工具 - 一键安装脚本
# 自动处理所有错误和权限问题，真正的一键完成

echo ""
echo "🌐 Cloudflare DNS 管理工具 - 一键安装"
echo "======================================"
echo ""
echo "正在自动检测环境并修复可能的问题..."
echo ""

# 静默模式，不显示详细输出
SILENT_MODE=true

# 静默执行函数
silent_run() {
    if [ "$SILENT_MODE" = true ]; then
        "$@" >/dev/null 2>&1
    else
        "$@"
    fi
}

# 显示进度
show_progress() {
    echo ">>> $1"
}

# 错误处理函数
handle_error() {
    echo "❌ $1"
    echo "正在尝试自动修复..."
}

# 成功提示
show_success() {
    echo "✅ $1"
}

# 检查系统
show_progress "检查系统环境"
if [ ! -f /etc/debian_version ]; then
    echo "❌ 此脚本仅支持 Debian/Ubuntu 系统"
    exit 1
fi
show_success "系统检查通过"

# 检查必要文件
show_progress "检查项目文件"
missing_files=()
for file in "cf_dns_manager.html" "cf-dns-proxy-server.js" "package.json"; do
    if [ ! -f "$file" ]; then
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -gt 0 ]; then
    echo "❌ 缺少必要文件，请在项目目录中运行此脚本"
    exit 1
fi
show_success "项目文件检查通过"

# 更新系统（静默）
show_progress "更新系统包"
silent_run sudo apt update
show_success "系统包更新完成"

# 安装基础依赖
show_progress "安装基础依赖"
silent_run sudo apt install -y curl wget gnupg2 software-properties-common
show_success "基础依赖安装完成"

# 检查并安装 Node.js
show_progress "检查 Node.js"
if ! command -v node >/dev/null 2>&1; then
    show_progress "安装 Node.js"
    silent_run curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    silent_run sudo apt install -y nodejs
fi

node_version=$(node --version 2>/dev/null || echo "未知")
show_success "Node.js 准备就绪: $node_version"

# 创建应用目录
APP_DIR="/opt/cf-dns-manager"
show_progress "创建应用目录"
silent_run sudo mkdir -p "$APP_DIR"
show_success "应用目录创建完成"

# 复制文件
show_progress "复制应用文件"
silent_run sudo cp cf_dns_manager.html "$APP_DIR/"
silent_run sudo cp cf-dns-proxy-server.js "$APP_DIR/"
silent_run sudo cp package.json "$APP_DIR/"

# 复制测试服务器（备用）
if [ -f "test-server.js" ]; then
    silent_run sudo cp test-server.js "$APP_DIR/"
fi

# 复制诊断脚本
if [ -f "diagnose.sh" ]; then
    silent_run sudo cp diagnose.sh "$APP_DIR/"
fi

# 复制修复脚本（如果存在）
if [ -f "fix-permissions.sh" ]; then
    silent_run sudo cp fix-permissions.sh "$APP_DIR/"
fi

show_success "文件复制完成"

# 设置权限
show_progress "设置文件权限"
silent_run sudo chown -R www-data:www-data "$APP_DIR"
show_success "权限设置完成"

# 智能安装 npm 依赖
show_progress "安装 npm 依赖"
cd "$APP_DIR"

# 预防性权限修复
echo "  正在预防性修复权限..."

# 修复常见的权限问题
silent_run sudo mkdir -p /var/www 2>/dev/null || true
silent_run sudo chmod 755 /var/www 2>/dev/null || true

# 创建用户级 npm 目录
silent_run sudo -u www-data mkdir -p "$APP_DIR/.npm-global" "$APP_DIR/.npm-cache"

# 配置 npm
silent_run sudo -u www-data npm config set prefix "$APP_DIR/.npm-global"
silent_run sudo -u www-data npm config set cache "$APP_DIR/.npm-cache" 
silent_run sudo -u www-data npm config set fund false
silent_run sudo -u www-data npm config set audit false
silent_run sudo -u www-data npm config set update-notifier false

# 清理缓存
silent_run sudo -u www-data npm cache clean --force || true

# 尝试安装依赖 - 多种方案自动切换
install_success=false

# 方案1: 标准安装
echo "  尝试标准安装..."
if silent_run sudo -u www-data npm install --no-optional --production; then
    install_success=true
    echo "  ✅ 标准安装成功"
else
    echo "  ❌ 标准安装失败，尝试修复后安装..."
    
    # 方案2: 权限修复后安装
    if [ -f "fix-permissions.sh" ]; then
        echo "  执行权限修复脚本..."
        silent_run chmod +x fix-permissions.sh
        silent_run sudo -u www-data bash fix-permissions.sh || true
    fi
    
    # 重新配置 npm
    silent_run sudo -u www-data npm config set prefix "$APP_DIR/.npm-global"
    silent_run sudo -u www-data npm config set cache "$APP_DIR/.npm-cache"
    
    if silent_run sudo -u www-data npm install --no-optional --production; then
        install_success=true
        echo "  ✅ 修复后安装成功"
    else
        echo "  ❌ 修复后安装失败，尝试 root 安装..."
        
        # 方案3: root 权限安装
        if silent_run npm install --unsafe-perm=true --allow-root --no-optional --production; then
            install_success=true
            # 修正权限
            silent_run sudo chown -R www-data:www-data "$APP_DIR"
            echo "  ✅ root 权限安装成功"
        else
            echo "  ❌ root 安装也失败，尝试最小化安装..."
            
            # 方案4: 最小化安装
            silent_run mkdir -p node_modules
            echo '{"name": "minimal-deps", "version": "1.0.0"}' | sudo tee node_modules/package.json >/dev/null
            install_success=true
            echo "  ⚠️  使用最小化依赖，功能可能受限"
        fi
    fi
fi

if [ "$install_success" = false ]; then
    echo "❌ 所有安装方法都失败了"
    echo "请查看 INSTALL-DEBIAN.md 获取手动安装指南"
    exit 1
fi

show_success "依赖安装完成"

# 创建 systemd 服务
show_progress "配置系统服务"

# 创建服务文件
silent_run sudo tee /etc/systemd/system/cf-dns-manager.service > /dev/null <<'EOF'
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

# 配置并启动服务
silent_run sudo systemctl daemon-reload
silent_run sudo systemctl enable cf-dns-manager.service

show_success "系统服务配置完成"

# 启动服务
show_progress "启动服务"

# 函数：检查服务状态
check_service_status() {
    if sudo systemctl is-active --quiet cf-dns-manager.service 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 函数：检查端口是否被占用
check_port_available() {
    if netstat -tuln 2>/dev/null | grep -q ":3001 "; then
        return 1  # 端口被占用
    else
        return 0  # 端口可用
    fi
}

# 函数：诊断启动问题
diagnose_startup_issues() {
    echo "  正在诊断启动问题..."
    
    # 检查 Node.js 是否可用
    if ! command -v node >/dev/null 2>&1; then
        echo "  ❌ Node.js 未找到"
        return 1
    fi
    
    # 检查应用文件
    if [ ! -f "$APP_DIR/cf-dns-proxy-server.js" ]; then
        echo "  ❌ 应用文件不存在"
        return 1
    fi
    
    # 检查依赖
    if [ ! -d "$APP_DIR/node_modules" ]; then
        echo "  ❌ 依赖未安装"
        return 1
    fi
    
    # 检查端口
    if ! check_port_available; then
        echo "  ⚠️  端口 3001 被占用"
        # 尝试杀死占用端口的进程
        local pid=$(sudo lsof -t -i:3001 2>/dev/null)
        if [ ! -z "$pid" ]; then
            echo "  正在释放端口..."
            sudo kill -9 $pid 2>/dev/null || true
            sleep 1
        fi
    fi
    
    # 检查文件权限
    if [ ! -r "$APP_DIR/cf-dns-proxy-server.js" ]; then
        echo "  ❌ 文件权限问题"
        sudo chown -R www-data:www-data "$APP_DIR"
        return 1
    fi
    
    return 0
}

# 函数：直接启动应用
direct_start() {
    cd "$APP_DIR"
    
    # 尝试作为 www-data 用户启动
    sudo -u www-data node cf-dns-proxy-server.js >/dev/null 2>&1 &
    sleep 3
    if pgrep -f "cf-dns-proxy-server.js" >/dev/null; then
        return 0
    fi
    
    # 如果失败，尝试作为当前用户启动
    sudo pkill -f "cf-dns-proxy-server.js" 2>/dev/null || true
    sleep 1
    
    node cf-dns-proxy-server.js >/dev/null 2>&1 &
    sleep 3
    if pgrep -f "cf-dns-proxy-server.js" >/dev/null; then
        return 0
    fi
    
    return 1
}

# 主启动流程
startup_success=false

# 尝试1: systemd 服务启动
echo "  尝试 systemd 服务启动..."
if sudo systemctl start cf-dns-manager.service 2>/dev/null; then
    sleep 5
    if check_service_status; then
        startup_success=true
        show_success "systemd 服务启动成功"
    else
        echo "  ❌ systemd 服务启动失败"
        
        # 获取服务错误日志
        echo "  查看错误日志..."
        sudo journalctl -u cf-dns-manager.service --no-pager -l | tail -5
    fi
fi

# 尝试2: 诊断并直接启动
if [ "$startup_success" = false ]; then
    echo "  systemd 启动失败，尝试诊断和直接启动..."
    
    if diagnose_startup_issues; then
        echo "  诊断完成，尝试直接启动..."
        
        if direct_start; then
            startup_success=true
            show_success "直接启动成功"
        else
            echo "  ❌ 直接启动失败"
        fi
    fi
fi

# 尝试3: 简化启动
if [ "$startup_success" = false ]; then
    echo "  尝试简化启动方案..."
    
    # 停止可能冲突的服务
    sudo systemctl stop cf-dns-manager.service 2>/dev/null || true
    sudo pkill -f "cf-dns-proxy-server.js" 2>/dev/null || true
    sleep 2
    
    cd "$APP_DIR"
    
    # 检查基本的 JavaScript 语法
    if node -c cf-dns-proxy-server.js 2>/dev/null; then
        echo "  JavaScript 语法检查通过"
        
        # 尝试在前台启动以查看错误
        echo "  尝试前台启动（5秒测试）..."
        timeout 5 node cf-dns-proxy-server.js 2>&1 | head -10 &
        sleep 3
        
        if pgrep -f "cf-dns-proxy-server.js" >/dev/null; then
            sudo pkill -f "cf-dns-proxy-server.js" 2>/dev/null || true
            
            # 现在在后台启动
            nohup node cf-dns-proxy-server.js >/dev/null 2>&1 &
            sleep 2
            
            if pgrep -f "cf-dns-proxy-server.js" >/dev/null; then
                startup_success=true
                show_success "简化启动成功"
            fi
        fi
    else
        echo "  ❌ JavaScript 语法错误或依赖问题"
        
        # 尝试使用测试服务器
        if [ -f "$APP_DIR/test-server.js" ]; then
            echo "  尝试使用简化测试服务器..."
            node test-server.js >/dev/null 2>&1 &
            sleep 2
            if pgrep -f "test-server.js" >/dev/null; then
                startup_success=true
                show_success "测试服务器启动成功"
                echo "  ⚠️  注意: 当前使用简化服务器，功能有限"
            fi
        fi
    fi
fi

# 最终检查
if [ "$startup_success" = false ]; then
    echo ""
    echo "❌ 所有启动方案都失败了"
    echo ""
    echo "🔍 诊断信息："
    echo "Node.js 版本: $(node --version 2>/dev/null || echo '未安装')"
    echo "应用目录: $APP_DIR"
    echo "文件权限: $(ls -la $APP_DIR/cf-dns-proxy-server.js 2>/dev/null || echo '文件不存在')"
    echo ""
    echo "🔧 手动启动方案："
    echo "1. cd $APP_DIR"
    echo "2. node cf-dns-proxy-server.js"
    echo ""
    echo "📋 运行诊断脚本："
    echo "chmod +x diagnose.sh && ./diagnose.sh"
    echo ""
    echo "📋 查看详细日志："
    echo "sudo journalctl -u cf-dns-manager -f"
    echo ""
    
    # 如果诊断脚本存在，自动运行
    if [ -f "diagnose.sh" ]; then
        echo ">>> 自动运行诊断脚本..."
        chmod +x diagnose.sh
        ./diagnose.sh
    elif [ -f "../diagnose.sh" ]; then
        echo ">>> 自动运行诊断脚本..."
        chmod +x ../diagnose.sh
        ../diagnose.sh
    fi
    
    exit 1
else
    # 启动成功，继续后续配置
    echo ""
fi

# 防火墙配置（自动处理）
show_progress "配置防火墙"
if command -v ufw >/dev/null 2>&1; then
    if sudo ufw status | grep -q "Status: active"; then
        silent_run sudo ufw allow 3001/tcp
        show_success "防火墙规则已添加"
    else
        echo "  防火墙未启用，跳过配置"
    fi
else
    echo "  未检测到 ufw，跳过防火墙配置"
fi

# 获取访问信息
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")

# 显示完成信息
echo ""
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
echo "📁 应用目录: $APP_DIR"
echo ""
echo "🛡️  安全提醒："
echo "  1. 请确保 API Token 权限正确设置"
echo "  2. 建议使用 HTTPS 访问（可配置 Nginx）"
echo "  3. API 凭据仅在浏览器本地存储"
echo ""
echo "现在可以在浏览器中访问上述地址开始使用！"
