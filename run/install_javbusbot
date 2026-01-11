#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 打印标题
print_header() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   JavBus Telegram Bot 一键部署脚本${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
}

# 检查 Docker 和 Docker Compose
check_docker() {
    print_info "检查 Docker 环境..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    print_success "Docker 环境检查通过"
    echo ""
}

# 获取用户输入
get_user_input() {
    # 获取 docker-compose 文件位置
    print_info "请输入 docker-compose 文件存放位置"
    read -p "$(echo -e ${BLUE}路径 [默认: /home/docker/javbus-tgbot]:${NC} )" COMPOSE_DIR
    COMPOSE_DIR=${COMPOSE_DIR:-/home/docker/javbus-tgbot}
    
    echo ""
    
    # 获取 Telegram Bot Token
    while true; do
        print_info "请输入 Telegram Bot Token (必填)"
        read -p "$(echo -e ${BLUE}Bot Token:${NC} )" BOT_TOKEN
        
        if [ -z "$BOT_TOKEN" ]; then
            print_error "Bot Token 不能为空，请重新输入"
            echo ""
        else
            break
        fi
    done
    
    echo ""
    
    # 获取 API Auth Token (可选)
    print_info "请输入 JavBus API 认证 Token (可选，不明白直接回车跳过)"
    read -p "$(echo -e ${BLUE}API Auth Token:${NC} )" API_AUTH_TOKEN
    
    echo ""
}

# 检查目录并创建
prepare_directory() {
    print_info "准备目录: $COMPOSE_DIR"
    
    # 检查目录是否存在
    if [ -d "$COMPOSE_DIR" ]; then
        # 检查目录是否为空
        if [ "$(ls -A $COMPOSE_DIR 2>/dev/null)" ]; then
            print_warning "目录 $COMPOSE_DIR 不为空"
            echo "当前目录内容:"
            ls -la "$COMPOSE_DIR"
            echo ""
            
            while true; do
                read -p "$(echo -e ${YELLOW}是否仍然选择此目录? [y/N]:${NC} )" choice
                case "$choice" in
                    y|Y)
                        print_info "继续使用目录: $COMPOSE_DIR"
                        break
                        ;;
                    n|N|"")
                        print_info "请重新运行脚本并选择其他目录"
                        exit 0
                        ;;
                    *)
                        print_error "无效输入，请输入 y 或 n"
                        ;;
                esac
            done
        else
            print_info "目录已存在且为空"
        fi
    else
        print_info "创建目录: $COMPOSE_DIR"
        mkdir -p "$COMPOSE_DIR"
        if [ $? -ne 0 ]; then
            print_error "创建目录失败"
            exit 1
        fi
        print_success "目录创建成功"
    fi
    
    echo ""
}

# 创建 docker-compose.yml 文件
create_compose_file() {
    local COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"
    
    print_info "创建 docker-compose.yml 文件..."
    
    cat > "$COMPOSE_FILE" <<EOF
version: '3.8'

services:
  # JavBus API 服务
  javbusapi:
    image: ovnrain/javbus-api
    container_name: javbusapi
    restart: unless-stopped
  # 可不对外访问
#    ports:
#      - '3030:3000'

  # Telegram Bot 服务
  javbusbot:
    image: hilog/javbusbot:latest
    container_name: javbusbot
    restart: unless-stopped
    depends_on:
      - javbusapi
    environment:
      # Telegram Bot Token (必填)
      - BOT_TOKEN=${BOT_TOKEN}
      # 默认 API 地址 (内部网络使用容器名)
      - DEFAULT_API_URL=http://javbusapi:3000
      # API 认证 Token (可选)
      - API_AUTH_TOKEN=${API_AUTH_TOKEN}
EOF

    if [ $? -ne 0 ]; then
        print_error "创建 docker-compose.yml 文件失败"
        exit 1
    fi
    
    print_success "docker-compose.yml 文件创建成功"
    echo ""
}

# 部署服务
deploy_services() {
    print_info "开始部署服务..."
    echo ""
    
    cd "$COMPOSE_DIR" || exit 1
    
    # 检查使用 docker compose 还是 docker-compose
    if command -v docker compose &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
    
    print_info "拉取镜像..."
    $COMPOSE_CMD pull
    
    echo ""
    print_info "启动容器..."
    $COMPOSE_CMD up -d
    
    if [ $? -ne 0 ]; then
        print_error "部署失败"
        exit 1
    fi
    
    echo ""
    print_success "服务部署成功！"
}

# 显示部署信息
show_deployment_info() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}          部署完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}部署信息:${NC}"
    echo -e "  • 部署目录: ${YELLOW}$COMPOSE_DIR${NC}"
    echo -e "  • JavBus API: ${YELLOW}http://localhost:3030${NC}"
    echo -e "  • Bot Token: ${YELLOW}${BOT_TOKEN:0:10}...${NC}"
    echo ""
    echo -e "${BLUE}常用命令:${NC}"
    echo -e "  • 查看日志: ${YELLOW}cd $COMPOSE_DIR && docker compose logs -f${NC}"
    echo -e "  • 停止服务: ${YELLOW}cd $COMPOSE_DIR && docker compose down${NC}"
    echo -e "  • 重启服务: ${YELLOW}cd $COMPOSE_DIR && docker compose restart${NC}"
    echo -e "  • 查看状态: ${YELLOW}cd $COMPOSE_DIR && docker compose ps${NC}"
    echo ""
    
    # 显示容器状态
    print_info "当前容器状态:"
    cd "$COMPOSE_DIR"
    if command -v docker compose &> /dev/null; then
        docker compose ps
    else
        docker-compose ps
    fi
    echo ""
}

# 主函数
main() {
    print_header
    check_docker
    get_user_input
    prepare_directory
    create_compose_file
    deploy_services
    show_deployment_info
    
    print_success "部署脚本执行完成！"
}

# 运行主函数
main

