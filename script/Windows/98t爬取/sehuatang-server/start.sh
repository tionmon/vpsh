#!/bin/bash
# ═══════════════════════════════════════════════════════
# 启动 Sehuatang 磁力爬虫服务（后台运行）
# ═══════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"
PID_FILE="$SCRIPT_DIR/app.pid"
LOG_FILE="$SCRIPT_DIR/app.log"

# 检查是否已在运行
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "⚠️  服务已在运行 (PID: $OLD_PID)"
        echo "   如需重启请先执行: bash stop.sh"
        exit 1
    else
        rm -f "$PID_FILE"
    fi
fi

# 检查虚拟环境
if [ ! -f "$VENV_DIR/bin/python" ]; then
    echo "❌ 虚拟环境不存在，请先运行: bash setup.sh"
    exit 1
fi

echo "🚀 启动 Sehuatang 磁力爬虫服务..."

# 后台启动
nohup "$VENV_DIR/bin/python" "$SCRIPT_DIR/app.py" >> "$LOG_FILE" 2>&1 &
APP_PID=$!
echo "$APP_PID" > "$PID_FILE"

# 等待 2 秒检查是否启动成功
sleep 2
if kill -0 "$APP_PID" 2>/dev/null; then
    echo "✅ 服务已启动 (PID: $APP_PID)"
    echo "   地址: http://0.0.0.0:9898"
    echo "   日志: tail -f $LOG_FILE"
else
    echo "❌ 启动失败，请查看日志: cat $LOG_FILE"
    rm -f "$PID_FILE"
    exit 1
fi
