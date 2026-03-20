#!/bin/bash
#
# sing-box 一键部署脚本
# 用法: bash sing-box-deploy.sh <UUID> <PRIVATE_KEY> <PUBLIC_KEY>
# 示例: bash sing-box-deploy.sh "a1b2c3d4-xxxx-xxxx-xxxx-xxxxxxxxxxxx" "PrivateKeyHere" "PublicKeyHere"
#

set -e

# ==================== 参数检查 ====================
if [ $# -ne 3 ]; then
    echo "======================================"
    echo "  sing-box 一键部署脚本"
    echo "======================================"
    echo ""
    echo "用法: $0 <UUID> <PRIVATE_KEY> <PUBLIC_KEY>"
    echo ""
    echo "参数:"
    echo "  UUID         - 用于 SS 和 VLESS 的 UUID"
    echo "  PRIVATE_KEY  - Reality 私钥"
    echo "  PUBLIC_KEY   - Reality 公钥"
    echo ""
    echo "示例:"
    echo "  $0 \"a1b2c3d4-xxxx\" \"priv_key\" \"pub_key\""
    exit 1
fi

UUID="$1"
PRIVATE_KEY="$2"
PUBLIC_KEY="$3"

echo "======================================"
echo "  sing-box 一键部署"
echo "======================================"
echo "UUID:        ${UUID:0:8}..."
echo "Private Key: ${PRIVATE_KEY:0:8}..."
echo "Public Key:  ${PUBLIC_KEY:0:8}..."
echo "======================================"
echo ""

# ==================== Step 1: 安装 sing-box ====================
echo "[1/4] 正在安装 sing-box ..."

# 下载安装脚本
TMP_INSTALL=$(mktemp /tmp/sb_install_XXXXXX.sh)
wget -qO "$TMP_INSTALL" https://github.com/233boy/sing-box/raw/main/install.sh

if [ ! -s "$TMP_INSTALL" ]; then
    echo "错误: 安装脚本下载失败"
    exit 1
fi

# 使用 yes 自动确认安装过程中的交互提示
# 如果安装脚本需要按回车确认，yes 会自动输入 y
yes "" | bash "$TMP_INSTALL" 2>&1 || true

rm -f "$TMP_INSTALL"

# 等待并验证安装
sleep 2
if ! command -v sb &>/dev/null; then
    echo "错误: sing-box (sb) 安装失败，请检查网络或手动安装后重试"
    exit 1
fi

echo "[1/4] ✅ sing-box 安装完成"
echo ""

# ==================== Step 2: 添加 Shadowsocks ====================
echo "[2/4] 正在添加 Shadowsocks (端口 19015, aes-128-gcm) ..."

sb a ss 19015 "$UUID" aes-128-gcm
sleep 1

echo "[2/4] ✅ Shadowsocks 添加完成"
echo ""

# ==================== Step 3: 添加 VLESS Reality ====================
echo "[3/4] 正在添加 VLESS Reality (端口 19013, SNI: www.tesla.com) ..."

sb a r 19013 "$UUID" www.tesla.com
sleep 1

echo "[3/4] ✅ VLESS Reality 添加完成"
echo ""

# ==================== Step 4: 更换 Reality 密钥 ====================
echo "[4/4] 正在更换 VLESS-REALITY-19013 密钥 ..."

sb change VLESS-REALITY-19013 key "$PRIVATE_KEY" "$PUBLIC_KEY"
sleep 1

echo "[4/4] ✅ 密钥更换完成"
echo ""

# ==================== 完成 ====================
echo "======================================"
echo "  🎉 全部部署完成！"
echo "======================================"
echo ""
echo "已配置的服务:"
echo "  • Shadowsocks    - 端口 19015 (aes-128-gcm)"
echo "  • VLESS Reality  - 端口 19013 (www.tesla.com)"
echo ""
echo "管理命令:"
echo "  sb         - 查看管理菜单"
echo "  sb info    - 查看节点信息"
echo "  sb status  - 查看运行状态"
echo ""
