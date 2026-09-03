#!/usr/bin/env bash
set -e

echo "======================================"
echo " Node.js + npm + npx + NVM 一键安装"
echo "======================================"

NVM_DIR="$HOME/.nvm"
export NVM_DIR

# ==============================
# 1. 安装基础依赖
# ==============================

echo "[1/5] 检查基础依赖..."

if ! command -v curl >/dev/null 2>&1; then
    echo "正在安装 curl..."

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y curl ca-certificates
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache curl bash ca-certificates
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl ca-certificates
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl ca-certificates
    else
        echo "❌ 无法识别当前 Linux 发行版"
        echo "请先手动安装 curl 和 ca-certificates"
        exit 1
    fi
fi


# ==============================
# 2. 安装 / 更新 NVM
# ==============================

echo "[2/5] 安装 / 更新 NVM..."

if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
else
    echo "NVM 已安装，跳过安装。"
fi

if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    echo "❌ NVM 安装失败"
    exit 1
fi

# 当前脚本立即加载 NVM
. "$NVM_DIR/nvm.sh"


# ==============================
# 3. 配置 Shell 自动加载 NVM
# ==============================

echo "[3/5] 配置 NVM 环境变量..."

NVM_CONFIG='
# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
'

# bashrc
if ! grep -q 'NVM_DIR="$HOME/.nvm"' "$HOME/.bashrc" 2>/dev/null; then
    printf "%s\n" "$NVM_CONFIG" >> "$HOME/.bashrc"
fi

# profile
if ! grep -q 'NVM_DIR="$HOME/.nvm"' "$HOME/.profile" 2>/dev/null; then
    printf "%s\n" "$NVM_CONFIG" >> "$HOME/.profile"
fi


# ==============================
# 4. 安装最新 Node.js LTS
# ==============================

echo "[4/5] 安装最新 Node.js LTS..."

nvm install --lts --latest-npm
nvm use --lts
nvm alias default 'lts/*'


# ==============================
# 5. 检查安装结果
# ==============================

echo "[5/5] 检查安装结果..."

echo
echo "======================================"
echo " 安装完成"
echo "======================================"
echo "Node.js : $(node -v)"
echo "npm     : $(npm -v)"
echo "npx     : $(npx -v)"
echo "nvm     : $(nvm --version)"
echo
echo "Node : $(command -v node)"
echo "npm  : $(command -v npm)"
echo "npx  : $(command -v npx)"
echo "======================================"
echo
echo "环境变量已经写入："
echo "  $HOME/.bashrc"
echo "  $HOME/.profile"
echo
echo "⚠️ 如果当前终端仍提示 npx 找不到，请执行："
echo
echo "    source ~/.bashrc"
echo
echo "或者重新连接 SSH。"
echo
echo "之后即可直接运行："
echo
echo "    npx @deepseek-ai/dsh web"
echo
