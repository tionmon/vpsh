#!/bin/bash

# ==========================================
# VpsValue 一键部署/更新脚本 (安全追加配置版)
# 适用系统: Ubuntu / Debian
# ==========================================

# 确保脚本以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本 (例如: sudo bash install.sh)"
  exit 1
fi

INSTALL_DIR="/opt/VpsValue"
PORT=4173

echo "=========================================="
echo "欢迎使用 VpsValue 一键部署/更新脚本"
echo "=========================================="

# 询问是否安装/配置 Caddy
read -p "是否需要配置 Caddy 反向代理 (自动配置 HTTPS)? [y/n]: " INSTALL_CADDY
if [[ "$INSTALL_CADDY" =~ ^[Yy]$ ]]; then
    read -p "请输入你的域名 (例如: vps.example.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        echo "域名不能为空，退出安装。"
        exit 1
    fi
    PUBLIC_URL="https://$DOMAIN"
else
    PUBLIC_URL="http://127.0.0.1:$PORT"
    DOMAIN=""
    echo "跳过 Caddy 配置，稍后你可以使用自己的反向代理。"
fi

echo "开始更新系统软件包..."
apt-get update -y

# 1. 检查并安装 git 和 curl
if ! command -v git &> /dev/null; then
    apt-get install -y git
fi
if ! command -v curl &> /dev/null; then
    apt-get install -y curl
fi

# 2. 检查并安装 Node.js (v20)
if ! command -v node &> /dev/null; then
    echo "未检测到 Node.js，正在安装 Node.js 20.x..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi

# 3. 检查并安装 PM2
if ! command -v pm2 &> /dev/null; then
    echo "正在安装 PM2..."
    npm install -g pm2
fi

# 4. 下载或更新项目
if [ -d "$INSTALL_DIR" ]; then
    echo "目录 $INSTALL_DIR 已存在，正在拉取最新代码..."
    cd "$INSTALL_DIR"
    git pull
else
    echo "正在克隆项目到 $INSTALL_DIR..."
    git clone https://github.com/tionmon/VpsValue.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# 5. 使用 PM2 启动项目
echo "正在配置 PM2 后台运行..."
pm2 delete vpsvalue 2>/dev/null || true
PUBLIC_BASE_URL="$PUBLIC_URL" pm2 start scripts/serve.mjs --name "vpsvalue"
pm2 save
env PATH=$PATH:/usr/bin pm2 startup systemd -u root --hp /root | grep -v '\[PM2\]' | bash 2>/dev/null || true


# 6. 安装并配置 Caddy (如果用户选择)
if [[ "$INSTALL_CADDY" =~ ^[Yy]$ ]]; then
    if ! command -v caddy &> /dev/null; then
        echo "正在安装 Caddy..."
        apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
        apt-get update -y
        apt-get install -y caddy
    fi

    # 更加安全的追加配置方式
    echo "正在配置 Caddy 反向代理..."
    CADDY_FILE="/etc/caddy/Caddyfile"
    
    if [ -f "$CADDY_FILE" ]; then
        if grep -q "$DOMAIN" "$CADDY_FILE"; then
            echo "Caddyfile 中已存在域名 $DOMAIN 的配置，跳过修改。"
        else
            echo "向现有的 Caddyfile 中追加 $DOMAIN 的配置..."
            # 使用 >> 追加而不是 > 覆盖
            cat <<EOF >> "$CADDY_FILE"

$DOMAIN {
    reverse_proxy 127.0.0.1:$PORT
}
EOF
        fi
    else
        echo "正在创建新的 Caddyfile..."
        cat <<EOF > "$CADDY_FILE"
$DOMAIN {
    reverse_proxy 127.0.0.1:$PORT
}
EOF
    fi
    
    systemctl enable caddy
    systemctl restart caddy
fi

echo "=========================================="
echo "🎉 部署完成！"
echo "项目运行目录: $INSTALL_DIR"
if [[ "$INSTALL_CADDY" =~ ^[Yy]$ ]]; then
    echo "访问地址: https://$DOMAIN"
else
    echo "项目已在后台监听端口: $PORT"
fi
echo "=========================================="