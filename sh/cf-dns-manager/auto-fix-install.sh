#!/bin/bash

# Cloudflare DNS 管理工具 - 自动错误修复安装脚本
# 专门处理各种安装问题和权限错误

set -e

echo "🔧 Cloudflare DNS 管理工具 - 自动修复安装"
echo "============================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# 检测并修复 npm 权限问题
fix_npm_permissions() {
    print_info "检测 npm 权限问题..."
    
    # 测试 npm 权限
    if npm config get prefix 2>/dev/null | grep -q "/usr"; then
        print_warning "检测到 npm 使用系统目录，可能导致权限问题"
        
        print_info "正在修复 npm 权限配置..."
        
        # 创建用户级 npm 目录
        NPM_GLOBAL_DIR="$HOME/.npm-global"
        NPM_CACHE_DIR="$HOME/.npm-cache"
        
        mkdir -p "$NPM_GLOBAL_DIR" "$NPM_CACHE_DIR"
        
        # 配置 npm
        npm config set prefix "$NPM_GLOBAL_DIR"
        npm config set cache "$NPM_CACHE_DIR"
        
        # 添加到 PATH
        if ! echo "$PATH" | grep -q "$NPM_GLOBAL_DIR/bin"; then
            echo "export PATH=$NPM_GLOBAL_DIR/bin:\$PATH" >> ~/.bashrc
            echo "export PATH=$NPM_GLOBAL_DIR/bin:\$PATH" >> ~/.profile
            export PATH="$NPM_GLOBAL_DIR/bin:$PATH"
        fi
        
        # 清理缓存
        npm cache clean --force 2>/dev/null || true
        
        print_success "npm 权限配置已修复"
        return 0
    else
        print_success "npm 权限配置正常"
        return 0
    fi
}

# 智能安装依赖
smart_install_deps() {
    local attempt=1
    local max_attempts=4
    
    while [ $attempt -le $max_attempts ]; do
        print_info "尝试安装依赖 (第 $attempt/$max_attempts 次)..."
        
        case $attempt in
            1)
                print_info "方法1: 标准安装"
                if npm install --no-optional --production >/dev/null 2>&1; then
                    print_success "标准安装成功"
                    return 0
                fi
                ;;
            2)
                print_info "方法2: 权限修复后安装"
                fix_npm_permissions
                if npm install --no-optional --production >/dev/null 2>&1; then
                    print_success "权限修复后安装成功"
                    return 0
                fi
                ;;
            3)
                print_info "方法3: 本地目录安装"
                # 强制使用当前目录
                mkdir -p ./.npm-cache ./.npm-global
                export NPM_CONFIG_CACHE="$(pwd)/.npm-cache"
                export NPM_CONFIG_PREFIX="$(pwd)/.npm-global"
                
                if npm install --no-optional --production >/dev/null 2>&1; then
                    print_success "本地目录安装成功"
                    return 0
                fi
                ;;
            4)
                print_info "方法4: sudo 强制安装"
                print_warning "使用管理员权限安装（仅限测试环境）"
                
                if sudo npm install --unsafe-perm=true --allow-root --no-optional --production >/dev/null 2>&1; then
                    print_success "sudo 强制安装成功"
                    return 0
                fi
                ;;
        esac
        
        print_error "第 $attempt 次安装失败"
        attempt=$((attempt + 1))
        sleep 1
    done
    
    return 1
}

# 主安装流程
main() {
    # 检查必要文件
    print_info "检查必要文件..."
    if [ ! -f "package.json" ] || [ ! -f "cf-dns-proxy-server.js" ]; then
        print_error "缺少必要文件，请确保在正确目录运行脚本"
        exit 1
    fi
    print_success "必要文件检查通过"
    
    # 检查 Node.js
    print_info "检查 Node.js..."
    if ! command -v node >/dev/null 2>&1; then
        print_error "未找到 Node.js，请先安装 Node.js"
        echo "安装命令："
        echo "curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
        echo "sudo apt install -y nodejs"
        exit 1
    fi
    print_success "Node.js 版本: $(node --version)"
    
    # 智能安装依赖
    print_info "开始安装依赖..."
    if smart_install_deps; then
        print_success "所有依赖安装完成"
        
        # 获取服务器信息
        SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
        
        echo ""
        echo "=========================================="
        print_success "安装完成！"
        echo "=========================================="
        echo ""
        echo "🌐 访问地址："
        echo "  本地访问: http://localhost:3001"
        if [ "$SERVER_IP" != "localhost" ]; then
            echo "  远程访问: http://$SERVER_IP:3001"
        fi
        echo ""
        print_info "启动代理服务器..."
        echo "按 Ctrl+C 停止服务"
        echo ""
        
        # 启动服务
        node cf-dns-proxy-server.js
    else
        print_error "所有安装方法都失败了"
        echo ""
        echo "🔧 手动解决方案："
        echo ""
        echo "1. 修复 npm 权限："
        echo "   sudo chown -R \$USER:\$USER ~/.npm"
        echo "   npm config set prefix ~/.npm-global"
        echo "   echo 'export PATH=~/.npm-global/bin:\$PATH' >> ~/.bashrc"
        echo "   source ~/.bashrc"
        echo ""
        echo "2. 清理并重装："
        echo "   rm -rf node_modules package-lock.json"
        echo "   npm cache clean --force"
        echo "   npm install"
        echo ""
        echo "3. 使用系统包："
        echo "   sudo apt install nodejs npm"
        echo "   sudo npm install -g express http-proxy-middleware cors"
        echo ""
        echo "4. 使用 Docker："
        echo "   docker-compose up -d"
        
        exit 1
    fi
}

# 捕获错误
trap 'print_error "安装过程中发生错误"; exit 1' ERR

# 执行主函数
main "$@"
