#!/bin/bash
# ═══════════════════════════════════════════════════════
# Sehuatang 磁力爬虫 — 一键部署脚本
# 适用于 Debian / Ubuntu 系统
# ═══════════════════════════════════════════════════════
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

echo "═══════════════════════════════════════════════════"
echo "  🧲 Sehuatang 磁力爬虫 — 安装部署"
echo "═══════════════════════════════════════════════════"
echo ""

# 1. 系统依赖
echo "[1/4] 📦 安装系统依赖..."
sudo apt-get update -qq
sudo apt-get install -y -qq python3 python3-venv python3-pip \
    chromium chromium-driver \
    fonts-wqy-zenhei fonts-wqy-microhei \
    2>/dev/null || {
    echo "⚠️  chromium 安装失败，尝试 chromium-browser..."
    sudo apt-get install -y -qq chromium-browser 2>/dev/null || true
}
echo "✅ 系统依赖已安装"

# 2. Python 虚拟环境
echo ""
echo "[2/4] 🐍 创建 Python 虚拟环境..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    echo "✅ 虚拟环境已创建: $VENV_DIR"
else
    echo "✅ 虚拟环境已存在，跳过创建"
fi

# 3. 安装 Python 依赖
echo ""
echo "[3/4] 📥 安装 Python 依赖..."
"$VENV_DIR/bin/pip" install --upgrade pip -q
"$VENV_DIR/bin/pip" install -r "$SCRIPT_DIR/requirements.txt" -q
echo "✅ Python 依赖已安装"

# 4. 初始化目录
echo ""
echo "[4/4] 📁 初始化目录和配置..."
mkdir -p "$SCRIPT_DIR/results"

# 确保脚本可执行
chmod +x "$SCRIPT_DIR/start.sh" "$SCRIPT_DIR/stop.sh" 2>/dev/null || true

echo ""
echo "═══════════════════════════════════════════════════"
echo "  ✅ 部署完成！"
echo ""
echo "  启动服务:  bash start.sh"
echo "  停止服务:  bash stop.sh"
echo "  访问地址:  http://<服务器IP>:9898"
echo "  默认密码:  admin"
echo "═══════════════════════════════════════════════════"
