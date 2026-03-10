#!/bin/bash
# ═══════════════════════════════════════════════════════
# 停止 Sehuatang 磁力爬虫服务
# ═══════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$SCRIPT_DIR/app.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "ℹ️  没有找到运行中的服务"
    exit 0
fi

PID=$(cat "$PID_FILE")
if kill -0 "$PID" 2>/dev/null; then
    echo "⏹  正在停止服务 (PID: $PID)..."
    kill "$PID"
    # 等待进程退出
    for i in $(seq 1 10); do
        if ! kill -0 "$PID" 2>/dev/null; then
            break
        fi
        sleep 1
    done
    # 强杀
    if kill -0 "$PID" 2>/dev/null; then
        echo "⚠️  进程未退出，强制终止..."
        kill -9 "$PID" 2>/dev/null || true
    fi
    echo "✅ 服务已停止"
else
    echo "ℹ️  进程已不存在"
fi

rm -f "$PID_FILE"
