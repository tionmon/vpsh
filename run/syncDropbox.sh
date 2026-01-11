#!/bin/bash

# 定义颜色，方便查看
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

clear
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}      Dropbox 同步脚本一键配置工具            ${NC}"
echo -e "${GREEN}==============================================${NC}"

# ----------------- 步骤 1: 检查环境 -----------------
echo -e "${YELLOW}[1/4] 正在检查系统环境...${NC}"
# 检查 unzip 和 wget 是否安装
if ! command -v unzip &> /dev/null || ! command -v wget &> /dev/null; then
    echo -e "发现缺少必要组件，正在尝试自动安装..."
    if [ -x "$(command -v apt-get)" ]; then
        apt-get update -y && apt-get install -y unzip wget
    elif [ -x "$(command -v yum)" ]; then
        yum install -y unzip wget
    else
        echo -e "${RED}无法自动安装依赖。请手动运行: apt install unzip wget${NC}"
        exit 1
    fi
else
    echo -e "环境检查通过。"
fi

echo ""

# ----------------- 步骤 2: 获取用户输入 -----------------
echo -e "${YELLOW}[2/4] 请输入配置信息${NC}"

# 获取目录
while [[ -z "$TARGET_DIR" ]]; do
    read -p "请输入 VPS 上的目标文件夹路径 (例如 /root/img): " TARGET_DIR
done

# 获取链接
while [[ -z "$DROPBOX_LINK" ]]; do
    read -p "请输入 Dropbox 共享链接: " DROPBOX_LINK
done

# ----------------- 步骤 3: 智能处理链接 (关键优化) -----------------
# 逻辑：使用 Bash 字符串替换功能，将 dl=0 替换为 dl=1
# 即使原本就是 dl=1 也没关系，脚本会保持不变
FINAL_LINK="${DROPBOX_LINK//dl=0/dl=1}"

# 如果链接里根本没有 dl= (比如用户复制错了)，我们尝试追加 (可选保险措施)
if [[ "$FINAL_LINK" != *"dl=1"* ]]; then
    # 简单的判断：如果链接包含 ? 则追加 &dl=1，否则追加 ?dl=1
    if [[ "$FINAL_LINK" == *"?"* ]]; then
        FINAL_LINK="${FINAL_LINK}&dl=1"
    else
        FINAL_LINK="${FINAL_LINK}?dl=1"
    fi
fi

echo -e "${BLUE}>>> 检测到链接，已自动优化下载模式 (dl=1)${NC}"

# ----------------- 步骤 4: 生成运行脚本 -----------------
SCRIPT_NAME="sync_dropbox.sh"
echo ""
echo -e "${YELLOW}[3/4] 正在生成脚本文件: $SCRIPT_NAME ...${NC}"

# 🆕 检查是否存在同名脚本，如果存在则自动覆盖
if [ -f "$SCRIPT_NAME" ]; then
    echo -e "${YELLOW}⚠ 检测到已存在的脚本文件，将自动覆盖...${NC}"
    rm -f "$SCRIPT_NAME"
fi

cat > "$SCRIPT_NAME" << 'EOF'
#!/bin/bash

# ==========================================
# 自动生成的 Dropbox 同步配置
# ==========================================
TARGET_DIR="TARGET_DIR_PLACEHOLDER"
URL="URL_PLACEHOLDER"

echo "---------------------------------------------"
echo "开始同步任务"
echo "本地目录: $TARGET_DIR"
echo "---------------------------------------------"

# 1. 确保目录存在
if [ ! -d "$TARGET_DIR" ]; then
    echo "目录不存在，正在创建..."
    mkdir -p "$TARGET_DIR"
else
    # 🆕 目录已存在，清空所有内容
    echo "⚠ 检测到目录已存在，正在清空旧文件..."
    
    # 安全检查: 防止变量为空或为根目录导致误删
    if [[ -z "$TARGET_DIR" || "$TARGET_DIR" == "/" || "$TARGET_DIR" == "/root" || "$TARGET_DIR" == "/home" ]]; then
        echo "❌ 错误：目标目录路径不安全（$TARGET_DIR），停止执行以保护系统。"
        exit 1
    fi
    
    # 删除目录下所有文件和子目录（但保留目录本身）
    rm -rf "${TARGET_DIR:?}"/*
    rm -rf "${TARGET_DIR:?}"/.[!.]*  # 删除隐藏文件（排除 . 和 ..）
    
    echo "✅ 旧文件已清空"
fi

# 2. 下载文件
echo "正在从 Dropbox 下载..."
# -O 指定输出文件名, -q 减少杂乱输出但保留进度条
wget -q --show-progress -O /tmp/dropbox_pkg.zip "$URL"

# 检查下载是否成功（判断文件大小是否大于0）
if [ ! -s /tmp/dropbox_pkg.zip ]; then
    echo "❌ 下载失败！文件为空。请检查 Dropbox 链接是否已失效。"
    rm -f /tmp/dropbox_pkg.zip
    exit 1
fi

# 3. 解压
echo "正在解压..."
unzip -q -o /tmp/dropbox_pkg.zip -d "$TARGET_DIR"

if [ $? -ne 0 ]; then
    echo "❌ 解压失败！请检查下载的文件是否完整。"
    rm -f /tmp/dropbox_pkg.zip
    exit 1
fi

# 4. 清理压缩包
rm -f /tmp/dropbox_pkg.zip

echo "---------------------------------------------"
echo "✅ 同步完成！"
echo "文件已更新至: $TARGET_DIR"
echo "文件数量: $(find "$TARGET_DIR" -type f | wc -l)"
echo "---------------------------------------------"
EOF

# 替换占位符为实际值
sed -i "s|TARGET_DIR_PLACEHOLDER|$TARGET_DIR|g" "$SCRIPT_NAME"
sed -i "s|URL_PLACEHOLDER|$FINAL_LINK|g" "$SCRIPT_NAME"

# 赋予执行权限
chmod +x "$SCRIPT_NAME"

echo -e "${GREEN}✅ [4/4] 部署完成！${NC}"
echo ""
echo -e "以后需要同步时，只需运行："
echo -e "${GREEN}    ./$SCRIPT_NAME${NC}"
echo ""
echo -e "${BLUE}💡 提示：${NC}"
echo -e "  • 每次运行同步脚本时，会自动删除目标目录下的所有文件"
echo -e "  • 重新运行本配置脚本会自动覆盖 $SCRIPT_NAME"
echo ""
