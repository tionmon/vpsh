#!/bin/bash
# SRT 字幕转语音 — Debian 12 一键安装脚本
set -e

echo "════════════════════════════════════════"
echo "  SRT 字幕转语音 — 环境安装"
echo "════════════════════════════════════════"

# 1. 系统依赖
echo ""
echo "[1/3] 安装系统依赖..."
sudo apt update
sudo apt install -y python3 python3-pip python3-venv ffmpeg

# 2. 虚拟环境
VENV_DIR="$HOME/srt_tts_venv"
echo ""
echo "[2/3] 创建虚拟环境: $VENV_DIR"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"

# 3. Python 依赖
echo ""
echo "[3/3] 安装 Python 依赖..."
pip install --upgrade pip
pip install edge-tts pysrt pydub flask

echo ""
echo "════════════════════════════════════════"
echo "  ✅ 安装完成！"
echo "════════════════════════════════════════"
echo ""
echo "启动方式:"
echo "  source $VENV_DIR/bin/activate"
echo "  python3 web_srt_tts.py --port 5000"
echo ""
