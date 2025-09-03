#!/bin/bash

# Cloudflare DNS 管理工具 - Docker 一键部署脚本

echo "🐳 Cloudflare DNS 管理工具 - Docker 部署"
echo "========================================"
echo ""

# 检查 Docker
echo ">>> 检查 Docker 环境..."
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker 未安装"
    echo ""
    echo "请先安装 Docker："
    echo "curl -fsSL https://get.docker.com | sh"
    echo "sudo usermod -aG docker \$USER"
    echo "newgrp docker"
    exit 1
fi

if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
    echo "❌ Docker Compose 未安装"
    echo ""
    echo "请安装 Docker Compose："
    echo "sudo apt install docker-compose-plugin"
    exit 1
fi

echo "✅ Docker 环境检查通过"
echo "  Docker 版本: $(docker --version)"
if command -v docker-compose >/dev/null 2>&1; then
    echo "  Docker Compose 版本: $(docker-compose --version)"
else
    echo "  Docker Compose 版本: $(docker compose version)"
fi

# 检查必要文件
echo ">>> 检查项目文件..."
required_files=("Dockerfile" "docker-compose.yml" "cf-dns-proxy-server.js" "cf_dns_manager.html" "package.json")
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ 缺少文件: $file"
        exit 1
    fi
done
echo "✅ 项目文件检查通过"

# 停止现有容器
echo ">>> 停止现有容器..."
if command -v docker-compose >/dev/null 2>&1; then
    docker-compose down >/dev/null 2>&1 || true
else
    docker compose down >/dev/null 2>&1 || true
fi

# 清理旧镜像（可选）
echo ">>> 清理旧镜像..."
docker image prune -f >/dev/null 2>&1 || true

# 构建和启动
echo ">>> 构建并启动容器..."
if command -v docker-compose >/dev/null 2>&1; then
    docker-compose up -d --build
else
    docker compose up -d --build
fi

# 等待容器启动
echo ">>> 等待容器启动..."
sleep 10

# 检查容器状态
echo ">>> 检查容器状态..."
container_status=$(docker inspect --format='{{.State.Status}}' cf-dns-manager 2>/dev/null || echo "not_found")

if [ "$container_status" = "running" ]; then
    echo "✅ 容器运行正常"
    
    # 检查健康状态
    health_status=$(docker inspect --format='{{.State.Health.Status}}' cf-dns-manager 2>/dev/null || echo "unknown")
    echo "  健康状态: $health_status"
    
    # 测试连接
    echo ">>> 测试连接..."
    sleep 5
    if curl -s http://localhost:3001/health >/dev/null 2>&1; then
        echo "✅ 连接测试成功"
    else
        echo "⚠️  连接测试失败，但容器正在运行"
        echo "  可能需要更多时间启动，请稍后访问"
    fi
    
else
    echo "❌ 容器启动失败"
    echo ""
    echo "🔍 容器日志："
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose logs --tail=20 cf-dns-manager
    else
        docker compose logs --tail=20 cf-dns-manager
    fi
    echo ""
    echo "🔧 故障排除："
    echo "1. 查看完整日志: docker logs cf-dns-manager"
    echo "2. 进入容器调试: docker exec -it cf-dns-manager sh"
    echo "3. 重新构建: docker-compose up -d --build --force-recreate"
    exit 1
fi

# 获取访问信息
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")

echo ""
echo "🎉 Docker 部署完成！"
echo "=========================================="
echo ""
echo "🌐 访问地址："
echo "  本地访问: http://localhost:3001"
if [ "$SERVER_IP" != "localhost" ]; then
    echo "  远程访问: http://$SERVER_IP:3001"
fi
echo ""
echo "🐳 Docker 管理命令："
echo "  查看状态: docker ps"
echo "  查看日志: docker logs cf-dns-manager -f"
echo "  停止服务: docker-compose down"
echo "  重启服务: docker-compose restart"
echo "  进入容器: docker exec -it cf-dns-manager sh"
echo ""
echo "🔧 故障排除："
echo "  完整日志: docker-compose logs -f"
echo "  重新构建: docker-compose up -d --build --force-recreate"
echo "  清理重置: docker-compose down -v && docker-compose up -d --build"
echo ""
echo "现在可以在浏览器中访问上述地址开始使用！"
