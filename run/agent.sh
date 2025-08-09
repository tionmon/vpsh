#!/bin/bash
#颜色
blue="\033[34m"
reset="\033[0m"

# 停止 Nezha Agent 服务
echo "停止 nezha-agent 服务..."
systemctl stop nezha-agent 2>/dev/null || echo "nezha-agent服务未运行。"

# 禁用开机自动启动
echo "禁用 nezha-agent 自启..."
systemctl disable nezha-agent 2>/dev/null || echo "nezha-agent未设置为开机启动。"

# 删除 Nezha Agent 二进制文件
if [ -d "/opt/nezha/agent" ]; then
    echo "删除 nezha-agent 二进制文件..."
    rm -rf /opt/nezha/agent
    echo "二进制文件已删除。"
else
    echo "未在 /opt/nezha/agent 目录中找到 nezha-agent二进制文件。"
fi

# 删除 Nezha Agent 服务文件
if [ -f "/etc/systemd/system/nezha-agent.service" ]; then
    echo "删除 nezha-agent 服务项文件..."
    rm /etc/systemd/system/nezha-agent.service
    echo "服务项文件已删除。"
else
    echo "未在 /etc/systemd/system 中找到 Nezha Agent 服务文件。"
fi

# 重新加载 systemd 配置
echo "重载 systemd 守护进程配置..."
systemctl daemon-reload

echo "nezha-agent 已移除。"
