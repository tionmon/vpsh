#!/bin/bash

# 查找占用 80 端口的服务并结束进程
PID80=$(sudo lsof -t -i :80)
if [ -n "$PID80" ]; then
  sudo kill -9 $PID80
  echo "停止占用 80 端口的进程"
fi

# 查找占用 443 端口的服务并结束进程
PID443=$(sudo lsof -t -i :443)
if [ -n "$PID443" ]; then
  sudo kill -9 $PID443
  echo "停止占用 443 端口的进程"
fi

# 卸载 Apache 或 Nginx
if dpkg -l | grep -q apache2; then
  sudo apt-get purge apache2 -y
  echo "卸载 Apache"
elif dpkg -l | grep -q nginx; then
  sudo apt-get purge nginx -y
  echo "卸载 Nginx"
fi