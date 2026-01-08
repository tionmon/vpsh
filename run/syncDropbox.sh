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

cat > "$SCRIPT_NAME" << EOF
#!/bin/bash

# ==========================================
# 自动生成的 Dropbox 同步配置
# ==========================================
TARGET_DIR="$TARGET_DIR"
URL="$FINAL_LINK"

echo "---------------------------------------------"
echo "开始同步任务"
echo "本地目录: \$TARGET_DIR"
echo "---------------------------------------------"

# 1. 确保目录存在
if [ ! -d "\$TARGET_DIR" ]; then
    mkdir -p "\$TARGET_DIR"
fi

# 2. 清空目录 (确保完全同步)
# 安全检查: 防止变量为空导致删除根目录
if [[ -n "\$TARGET_DIR" && "\$TARGET_DIR" != "/" ]]; then
    echo "正在清理旧文件..."
    rm -rf "\$TARGET_DIR"/*
else
    echo "错误：目标目录路径不安全，停止执行以保护系统。"
    exit 1
fi

# 3. 下载文件
echo "正在从 Dropbox 下载..."
# -O 指定输出文件名, -q 减少杂乱输出但保留进度条
wget -q --show-progress -O /tmp/dropbox_pkg.zip "\$URL"

# 检查下载是否成功（判断文件大小是否大于0）
if [ ! -s /tmp/dropbox_pkg.zip ]; then
    echo "下载失败！文件为空。请检查 Dropbox 链接是否已失效。"
    rm -f /tmp/dropbox_pkg.zip
    exit 1
fi

# 4. 解压
echo "正在解压..."
unzip -q -o /tmp/dropbox_pkg.zip -d "\$TARGET_DIR"

# 5. 清理压缩包
rm -f /tmp/dropbox_pkg.zip

echo "---------------------------------------------"
echo "✅ 同步完成！"
echo "文件已更新至: \$TARGET_DIR"
echo "---------------------------------------------"
EOF

# 赋予执行权限
chmod +x "$SCRIPT_NAME"

echo -e "${GREEN}[4/4] 部署完成！${NC}"
echo ""
echo -e "以后需要同步时，只需运行："
echo -e "${GREEN}./$SCRIPT_NAME${NC}"
