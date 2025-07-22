#!/bin/bash

# 检查 Caddy 是否已安装
if ! command -v caddy &> /dev/null
then
    # 如果没有安装，执行安装步骤
    echo "Caddy 未安装，正在安装必要的软件包..."
    sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl

    # 下载并导入 Caddy 的 GPG 密钥
    echo "正在导入 Caddy 的 GPG 密钥..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

    # 添加 Caddy 的软件源
    echo "正在添加 Caddy 的软件源..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list

    # 修改文件权限，允许其他用户读取
    echo "正在修改文件权限..."
    chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    chmod o+r /etc/apt/sources.list.d/caddy-stable.list

    # 更新 apt 包索引
    echo "正在更新 apt 包索引..."
    sudo apt update

    # 安装 Caddy
    echo "正在安装 Caddy..."
    sudo apt install -y caddy
    systemctl enable caddy
fi