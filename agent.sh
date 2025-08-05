#!/bin/bash
#颜色
blue="\033[34m"
reset="\033[0m"
#输出
echo -e "${blue}欢迎使用Leu nezha-agent一键卸载脚本${reset}"
echo -e "${blue}更多一键脚本GitHub：https://github.com/leuxinovo/clearvps${reset}"
echo -e "${blue}我的博客：https://blog.techleu.de${reset}"
echo -e "${blue}-------------------------------------${reset}"

# 停止 Nezha Agent 服务
echo "正在停止 nezha-agent服务..."
systemctl stop nezha-agent 2>/dev/null || echo "nezha-agent服务未运行。"

# 禁用开机自动启动
echo "正在禁用 nezha-agent开机自动启动..."
systemctl disable nezha-agent 2>/dev/null || echo "nezha-agent未设置为开机启动。"

# 删除 Nezha Agent 二进制文件
if [ -d "/opt/nezha/agent" ]; then
    echo "正在删除 nezha-agent二进制文件..."
    rm -rf /opt/nezha/agent
    echo "二进制文件已删除。"
else
    echo "未在 /opt/nezha/agent 目录中找到 nezha-agent二进制文件。"
fi

# 删除 Nezha Agent 服务文件
if [ -f "/etc/systemd/system/nezha-agent.service" ]; then
    echo "正在删除 nezha-agent服务文件..."
    rm /etc/systemd/system/nezha-agent.service
    echo "服务文件已删除。"
else
    echo "未在 /etc/systemd/system 中找到 Nezha Agent 服务文件。"
fi

# 重新加载 systemd 配置
echo "正在重新加载 systemd 守护进程配置..."
systemctl daemon-reload

echo "nezha-agent 已成功移除。"