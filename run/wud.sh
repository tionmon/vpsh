#!/bin/bash

# ============================================
# WUD (What's Up Docker) 一键安装脚本
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印信息函数
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================
# 0. 预输入 - 安装目录
# ============================================
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  WUD (What's Up Docker) 一键安装${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

read -p "请输入安装目录 [默认: /home/docker/wud]: " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-/home/docker/wud}

# 检测目录是否存在且不为空
if [ -d "$INSTALL_DIR" ] && [ "$(ls -A $INSTALL_DIR)" ]; then
    print_warn "目录 $INSTALL_DIR 已存在且不为空!"
    ls -lh "$INSTALL_DIR"
    echo ""
    read -p "是否继续安装? (y/N): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        print_info "安装已取消"
        exit 0
    fi
fi

print_info "安装目录: $INSTALL_DIR"
echo ""

# ============================================
# 1. 安装必要工具
# ============================================
print_info "正在更新系统并安装必要工具..."
apt update -y && apt full-upgrade -y && apt install -y curl wget sudo unzip tar
print_info "必要工具安装完成"
echo ""

# ============================================
# 2. 检测并安装 Docker
# ============================================
if command -v docker &> /dev/null; then
    print_info "检测到 Docker 已安装"
    docker --version
else
    print_warn "未检测到 Docker,开始安装..."
    
    # 检测是否为中国大陆
    print_info "正在检测网络位置..."
    if curl -s --connect-timeout 3 https://www.google.com > /dev/null 2>&1; then
        print_info "检测到非中国大陆网络,使用官方源安装 Docker..."
        curl -fsSL https://get.docker.com | bash -s docker
    else
        print_info "检测到中国大陆网络,使用阿里云镜像安装 Docker..."
        curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
    fi
    
    # 启用 Docker 服务
    sudo systemctl enable docker
    sudo systemctl start docker
    
    print_info "Docker 安装完成"
    docker --version
fi

# 检测 Docker Compose
if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
    print_warn "未检测到 Docker Compose,请确保 Docker 版本包含 Compose 插件"
fi

echo ""

# ============================================
# 3. 创建安装目录和 compose 文件
# ============================================
print_info "创建安装目录: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

print_info "创建 docker-compose.yaml 文件..."
cat > docker-compose.yaml <<'EOF'
# version: "3.8"

services:
  wud:
    image: getwud/wud:latest
    container_name: wud
    restart: unless-stopped
#    ports:
#      - "3000:3000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./store:/store
    environment:
      - TZ=Asia/Shanghai

      # 本机 Docker watcher
      - WUD_WATCHER_LOCAL_SOCKET=/var/run/docker.sock

      # 关键: 默认不监控任何容器
      - WUD_WATCHER_LOCAL_WATCHBYDEFAULT=false

      # 每 12 小时扫描一次
      - WUD_WATCHER_LOCAL_CRON=0 */12 * * *

      # 自动更新 + 更新后清理旧镜像
      - WUD_TRIGGER_DOCKER_AUTO_PRUNE=true
EOF

print_info "docker-compose.yaml 文件创建成功"
echo ""

# ============================================
# 4. 启动 WUD
# ============================================
print_info "正在启动 WUD 容器..."

# 尝试使用 docker compose 或 docker-compose
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    docker compose up -d
elif command -v docker-compose &> /dev/null; then
    docker-compose up -d
else
    print_error "无法找到 docker compose 或 docker-compose 命令"
    exit 1
fi

echo ""
print_info "WUD 容器启动成功!"

# 检查容器状态
sleep 2
docker ps -a | grep wud

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  WUD 安装完成!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "安装目录: ${YELLOW}$INSTALL_DIR${NC}"
echo -e "配置文件: ${YELLOW}$INSTALL_DIR/docker-compose.yaml${NC}"
echo ""
echo -e "${YELLOW}使用说明:${NC}"
echo ""
echo -e "1️⃣  ${GREEN}只监控 (不自动更新)${NC}"
echo -e "   在容器的 docker-compose.yaml 中添加:"
echo -e "   ${YELLOW}labels:${NC}"
echo -e "   ${YELLOW}  - \"wud.watch=true\"${NC}"
echo ""
echo -e "2️⃣  ${GREEN}监控 + 自动更新${NC}"
echo -e "   在容器的 docker-compose.yaml 中添加:"
echo -e "   ${YELLOW}labels:${NC}"
echo -e "   ${YELLOW}  - \"wud.watch=true\"${NC}"
echo -e "   ${YELLOW}  - \"wud.trigger.include=docker.auto\"${NC}"
echo ""
echo -e "${YELLOW}常用命令:${NC}"
echo -e "  查看日志: ${GREEN}docker logs -f wud${NC}"
echo -e "  重启容器: ${GREEN}docker restart wud${NC}"
echo -e "  停止容器: ${GREEN}docker stop wud${NC}"
echo -e "  启动容器: ${GREEN}docker start wud${NC}"
echo ""
echo -e "${GREEN}========================================${NC}"

