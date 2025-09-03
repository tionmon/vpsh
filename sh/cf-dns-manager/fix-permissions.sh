#!/bin/bash

# 修复 npm 权限问题的脚本

echo "🔧 修复 npm 权限问题..."

# 检查当前用户
CURRENT_USER=$(whoami)
echo "当前用户: $CURRENT_USER"

# 创建用户级别的 npm 目录
NPM_DIR="$HOME/.npm-global"
mkdir -p "$NPM_DIR"

# 配置 npm 使用用户目录
npm config set prefix "$NPM_DIR"
npm config set cache "$HOME/.npm-cache"

# 添加到 PATH（如果还没有）
if ! echo "$PATH" | grep -q "$NPM_DIR/bin"; then
    echo "export PATH=$NPM_DIR/bin:\$PATH" >> ~/.bashrc
    echo "export PATH=$NPM_DIR/bin:\$PATH" >> ~/.profile
    export PATH="$NPM_DIR/bin:$PATH"
fi

# 清理 npm 缓存
npm cache clean --force

echo "✅ npm 权限配置完成"
echo "📝 请运行以下命令使配置生效："
echo "   source ~/.bashrc"
echo "   或者重新登录终端"

# 测试安装
echo "🧪 测试 npm 安装..."
if npm install --dry-run > /dev/null 2>&1; then
    echo "✅ npm 权限测试成功"
else
    echo "⚠️  权限问题可能仍然存在"
    echo "建议方案："
    echo "1. 重新登录终端"
    echo "2. 或者使用 sudo npm install --unsafe-perm=true --allow-root"
fi
