#!/bin/bash

# Hugo 博客一键安装脚本 for Debian 12
# 使用 Hugo Extended + Caddy Docker 部署

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
   echo_error "此脚本需要 root 权限运行"
   echo "请使用 sudo 运行: sudo bash $0"
   exit 1
fi

# ========== 步骤 0: 获取用户输入域名 ==========
echo ""
echo "=========================================="
echo "  Hugo 博客一键安装脚本"
echo "=========================================="
echo ""

read -p "请输入你的域名 (例如: blog.example.com): " DOMAIN

if [ -z "$DOMAIN" ]; then
    echo_error "域名不能为空！"
    exit 1
fi

echo_info "你输入的域名是: $DOMAIN"
read -p "确认无误？(y/n): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo_error "已取消安装"
    exit 1
fi

# 选择 Caddy 安装方式
echo ""
echo "请选择 Caddy 安装方式:"
echo "  1. 独立安装（APT 安装，系统服务）"
echo "  2. Docker 安装（容器化部署）"
read -p "请输入选项 (1 或 2) [默认: 2]: " CADDY_INSTALL_METHOD

# 设置默认值
CADDY_INSTALL_METHOD=${CADDY_INSTALL_METHOD:-2}

if [ "$CADDY_INSTALL_METHOD" != "1" ] && [ "$CADDY_INSTALL_METHOD" != "2" ]; then
    echo_error "无效的选项，请输入 1 或 2"
    exit 1
fi

if [ "$CADDY_INSTALL_METHOD" = "1" ]; then
    echo_info "已选择: 独立安装"
    CADDY_DIR="/etc/caddy"
else
    echo_info "已选择: Docker 安装"
    CADDY_DIR="/home/docker/caddy"
fi

# 配置变量
INSTALL_DIR="/home/web/hugo"
SITE_NAME="myblog"

# ========== 步骤 1: 准备环境 ==========
echo ""
echo_info "步骤 1/8: 更新系统并安装必要工具..."
apt update -y
apt full-upgrade -y
apt install -y curl wget sudo unzip git jq

# ========== 步骤 2: 检测系统架构并安装 Hugo Extended 版本 ==========
echo ""
echo_info "步骤 2/8: 检测系统架构并获取最新版 Hugo Extended..."

# 检测系统架构
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        HUGO_ARCH="amd64"
        ;;
    aarch64|arm64)
        HUGO_ARCH="arm64"
        ;;
    *)
        echo_error "不支持的系统架构: $ARCH"
        echo "支持的架构: x86_64 (amd64), aarch64/arm64"
        exit 1
        ;;
esac

echo_info "检测到系统架构: $ARCH (使用 Hugo ${HUGO_ARCH} 版本)"

# 获取最新版本号
echo_info "正在获取最新的 Hugo 版本信息..."
HUGO_VERSION=$(curl -fsSL https://api.github.com/repos/gohugoio/hugo/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')

if [ -z "$HUGO_VERSION" ]; then
    echo_error "无法获取最新版本号，请检查网络连接"
    exit 1
fi

echo_info "最新版本: v${HUGO_VERSION}"

# 检查是否已安装
if command -v hugo &> /dev/null; then
    current_version=$(hugo version | grep -oP 'v\d+\.\d+\.\d+' | head -1 | sed 's/v//')
    echo_warning "检测到已安装 Hugo v${current_version}"

    if [ "$current_version" = "$HUGO_VERSION" ]; then
        echo_info "已是最新版本，跳过安装"
    else
        read -p "是否升级到 v${HUGO_VERSION}？(y/n): " overwrite
        if [ "$overwrite" = "y" ] || [ "$overwrite" = "Y" ]; then
            cd /tmp
            echo_info "正在下载 Hugo Extended v${HUGO_VERSION} (${HUGO_ARCH})..."
            wget -q --show-progress https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-${HUGO_ARCH}.tar.gz
            tar -xzf hugo_extended_${HUGO_VERSION}_linux-${HUGO_ARCH}.tar.gz
            mv hugo /usr/local/bin/hugo
            chmod +x /usr/local/bin/hugo
            rm -f hugo_extended_${HUGO_VERSION}_linux-${HUGO_ARCH}.tar.gz LICENSE README.md
            echo_info "Hugo Extended 升级完成"
        else
            echo_info "跳过 Hugo 安装"
        fi
    fi
else
    cd /tmp
    echo_info "正在下载 Hugo Extended v${HUGO_VERSION} (${HUGO_ARCH})..."
    wget -q --show-progress https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-${HUGO_ARCH}.tar.gz

    if [ ! -f "hugo_extended_${HUGO_VERSION}_linux-${HUGO_ARCH}.tar.gz" ]; then
        echo_error "下载失败，请检查网络连接或版本号"
        exit 1
    fi

    tar -xzf hugo_extended_${HUGO_VERSION}_linux-${HUGO_ARCH}.tar.gz
    mv hugo /usr/local/bin/hugo
    chmod +x /usr/local/bin/hugo
    rm -f hugo_extended_${HUGO_VERSION}_linux-${HUGO_ARCH}.tar.gz LICENSE README.md
    echo_info "Hugo Extended 安装完成"
fi

echo ""
hugo version

# ========== 步骤 3: 创建 Hugo 站点 ==========
echo ""
echo_info "步骤 3/8: 创建 Hugo 站点..."

mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

if [ -d "$SITE_NAME" ]; then
    echo_warning "检测到已存在 $SITE_NAME 目录"
    read -p "是否删除并重新创建？(y/n): " recreate
    if [ "$recreate" = "y" ] || [ "$recreate" = "Y" ]; then
        rm -rf $SITE_NAME
        hugo new site $SITE_NAME
        cd $SITE_NAME
        git init
    else
        cd $SITE_NAME
    fi
else
    hugo new site $SITE_NAME
    cd $SITE_NAME
    git init
fi

# ========== 步骤 4: 添加主题（使用 Git 子模块）==========
echo ""
echo_info "步骤 4/8: 添加 hugo-narrow 主题..."

if [ -d "themes/hugo-narrow" ]; then
    echo_warning "主题目录已存在，正在更新..."
    git submodule update --init --recursive --remote
else
    git submodule add https://github.com/tom2almighty/hugo-narrow.git themes/hugo-narrow
    git submodule update --init --recursive --remote
fi

# ========== 步骤 5: 配置主题 ==========
echo ""
echo_info "步骤 5/8: 配置主题和站点..."

# 复制示例配置
cp -r themes/hugo-narrow/exampleSite/* .

# 删除 hugo.toml（如果存在）
[ -f "hugo.toml" ] && rm -f hugo.toml

# 修改 hugo.yaml 配置
if [ -f "hugo.yaml" ]; then
    # 备份原配置
    cp hugo.yaml hugo.yaml.bak

    # 使用 sed 修改 baseURL
    sed -i "s|baseURL:.*|baseURL: 'https://${DOMAIN}'|g" hugo.yaml

    echo_info "已配置 baseURL 为: https://${DOMAIN}"
else
    echo_error "hugo.yaml 文件不存在，请手动配置"
fi

# 创建第一篇文章
echo ""
echo_info "创建示例文章..."
hugo new posts/hello-world.md

# 修改示例文章的 draft 状态
cat > content/posts/hello-world.md <<EOF
---
title: "欢迎来到我的博客"
date: $(date +%Y-%m-%d)
draft: false
categories: ["博客"]
tags: ["Hugo", "开始"]
---

这是我的第一篇博客文章！

## 关于本站

本站使用 Hugo 静态博客生成器搭建，主题为 hugo-narrow。

## 快速开始

你可以通过编辑 \`content/posts/\` 目录下的 Markdown 文件来创建新文章。

EOF

# ========== 步骤 6: 安装 Caddy ==========
echo ""
if [ "$CADDY_INSTALL_METHOD" = "1" ]; then
    # 独立安装 Caddy
    echo_info "步骤 6/8: 安装 Caddy (APT 方式)..."

    if command -v caddy &> /dev/null; then
        caddy_version=$(caddy version)
        echo_info "检测到已安装 Caddy: $caddy_version"
    else
        echo_info "正在安装 Caddy..."
        apt update
        apt install -y debian-keyring debian-archive-keyring apt-transport-https ca-certificates curl gnupg
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null
        apt update
        apt install -y caddy
        echo_info "Caddy 安装完成"
    fi
else
    # Docker 安装 Caddy
    echo_info "步骤 6/8: 检查并安装 Docker..."

    if command -v docker &> /dev/null; then
        docker_version=$(docker --version)
        echo_info "检测到已安装 Docker: $docker_version"
    else
        echo_warning "未检测到 Docker，正在安装..."
        curl -fsSL https://get.docker.com | bash -s docker
        systemctl enable docker
        systemctl start docker
        echo_info "Docker 安装完成"
    fi

    # 检查 docker-compose
    if ! command -v docker-compose &> /dev/null; then
        echo_info "正在安装 docker-compose..."
        apt install -y docker-compose
    fi
fi

# ========== 步骤 7: 配置 Caddy ==========
echo ""
echo_info "步骤 7/8: 配置 Caddy..."

mkdir -p $CADDY_DIR

if [ "$CADDY_INSTALL_METHOD" = "2" ]; then
    # Docker 方式：创建 docker-compose.yml
    cd $CADDY_DIR

    cat > docker-compose.yml <<EOF
version: '3'

services:
  caddy:
    image: caddy:latest
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - /home/web:/home/web
      - ./site:/usr/share/caddy
      - caddy_data:/data
      - caddy_config:/config

volumes:
  caddy_data:
  caddy_config:
EOF
    echo_info "Docker Compose 配置文件已创建"
fi

# 创建 Caddyfile
cat > ${CADDY_DIR}/Caddyfile <<EOF
${DOMAIN} {
  # 指向 Hugo 输出目录
  root * ${INSTALL_DIR}/${SITE_NAME}/public

  # 启用压缩
  encode zstd gzip

  # 单页应用或前端路由回退
  try_files {path} {path}/ /index.html

  # 静态资源长缓存
  @assets {
    path /assets/* *.css *.js *.png *.jpg *.jpeg *.gif *.svg *.webp *.ico
  }
  header @assets Cache-Control "public, max-age=31536000, immutable"

  # 文件服务
  file_server
}
EOF

echo_info "Caddyfile 配置文件已创建"

# ========== 步骤 8: 生成静态文件并启动服务 ==========
echo ""
echo_info "步骤 8/8: 生成静态文件并启动 Caddy..."

cd $INSTALL_DIR/$SITE_NAME
hugo

echo_info "静态文件已生成到 public/ 目录"

# 设置权限
chmod -R 755 ${INSTALL_DIR}/${SITE_NAME}/public

# 启动 Caddy
if [ "$CADDY_INSTALL_METHOD" = "1" ]; then
    # 独立安装方式：使用 systemctl
    if command -v caddy &> /dev/null; then
        # 设置 Caddy 用户权限
        if id "caddy" &>/dev/null; then
            chgrp -R caddy ${INSTALL_DIR}/${SITE_NAME}/public 2>/dev/null || true
        fi

        systemctl enable caddy > /dev/null 2>&1
        systemctl restart caddy
        sleep 2

        if systemctl is-active --quiet caddy; then
            echo_info "Caddy 服务已成功启动"
        else
            echo_error "Caddy 服务启动失败，请检查日志: journalctl -u caddy -n 50"
        fi
    fi
else
    # Docker 安装方式：使用 docker-compose
    cd $CADDY_DIR

    # 如果容器已存在，先停止并删除
    if [ "$(docker ps -aq -f name=caddy)" ]; then
        echo_info "停止现有的 Caddy 容器..."
        docker-compose down > /dev/null 2>&1
    fi

    echo_info "启动 Caddy 容器..."
    docker-compose up -d
    sleep 2

    if docker ps | grep -q caddy; then
        echo_info "Caddy 容器已成功启动"
    else
        echo_error "Caddy 容器启动失败，请检查日志: docker logs caddy"
    fi
fi

# ========== 完成 ==========
echo ""
echo "=========================================="
echo_info "安装完成！"
echo "=========================================="
echo ""
echo "📝 站点信息:"
echo "   - 域名: https://${DOMAIN}"
echo "   - Hugo 目录: ${INSTALL_DIR}/${SITE_NAME}"
echo "   - Caddy 配置: ${CADDY_DIR}"
echo ""
echo "🚀 后续操作:"
echo "   1. 确保域名 ${DOMAIN} 已解析到本服务器"
echo "   2. 确保防火墙开放 80 和 443 端口"
echo "   3. 等待 Caddy 自动申请 SSL 证书（约 1-2 分钟）"
echo ""
echo "✍️  创建新文章:"
echo "   cd ${INSTALL_DIR}/${SITE_NAME}"
echo "   hugo new posts/my-post.md"
echo "   # 编辑文章后运行:"
echo "   hugo"

if [ "$CADDY_INSTALL_METHOD" = "1" ]; then
    echo "   systemctl reload caddy"
    echo ""
    echo "🔧 常用命令:"
    echo "   - 查看 Caddy 日志: journalctl -u caddy -f"
    echo "   - 重启 Caddy: systemctl restart caddy"
    echo "   - 停止 Caddy: systemctl stop caddy"
    echo "   - 重载配置: systemctl reload caddy"
else
    echo "   docker restart caddy"
    echo ""
    echo "🔧 常用命令:"
    echo "   - 查看 Caddy 日志: docker logs -f caddy"
    echo "   - 重启 Caddy: docker restart caddy"
    echo "   - 停止 Caddy: cd ${CADDY_DIR} && docker-compose down"
fi

echo "   - 本地预览: cd ${INSTALL_DIR}/${SITE_NAME} && hugo server --bind=0.0.0.0"
echo ""
echo "=========================================="
echo ""
echo_info "安装脚本执行完毕！"
