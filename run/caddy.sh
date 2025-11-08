#!/bin/sh

# 一键安装 Caddy（stable 版）的完整 Shell 脚本
# 包含：系统更新 + 必要工具 + 检测是否已安装 Caddy（跳过安装）
# 适用于 Debian / Ubuntu 系统

set -e  # 遇到错误立即退出

echo "=========================================="
echo "   Caddy 一键安装脚本（智能跳过已安装）"
echo "=========================================="

# 检查是否已安装 Caddy
if command -v caddy >/dev/null 2>&1; then
    echo "检测到 Caddy 已经安装，跳过安装步骤。"
    echo "当前版本：$(caddy version 2>/dev/null || echo '未知（可能无权限）')"
    echo "配置文件：/etc/caddy/Caddyfile"
    echo "服务状态："
    systemctl is-active --quiet caddy && echo "  caddy 服务正在运行" || echo "  caddy 服务未运行"
    echo "=========================================="
    exit 0
fi

echo "[1/5] 正在更新系统并安装必要工具..."
sudo apt update -y
sudo apt full-upgrade -y
sudo apt install -y curl wget sudo unzip

echo "[2/5] 安装 Caddy 所需的依赖..."
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https ca-certificates gnupg

echo "[3/5] 添加 Caddy stable 版 GPG 密钥..."
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

echo "[4/5] 添加 Caddy stable 版 apt 源..."
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null

echo "[5/5] 再次更新软件包列表并安装 Caddy..."
sudo apt update
sudo apt install -y caddy

echo "=========================================="
echo "Caddy 安装完成！"
echo ""
echo "常用命令："
echo "  sudo systemctl start caddy     # 启动服务"
echo "  sudo systemctl enable caddy    # 开机自启"
echo "  sudo systemctl status caddy    # 查看状态"
echo "  sudo caddy reload              # 重载配置"
echo "  caddy version                  # 查看版本"
echo ""
echo "默认配置文件：/etc/caddy/Caddyfile"
echo "默认网站目录：/var/www/html"
echo "=========================================="
