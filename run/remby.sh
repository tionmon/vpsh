#!/bin/bash

# 检查 Caddy 是否已安装
if ! command -v caddy &> /dev/null
then
    # 如果没有安装，执行安装步骤
    echo "Caddy 未安装，正在安装必要的软件包..."
    sudo apt update -y
    sudo apt full-upgrade -y
    sudo apt install -y curl wget sudo unzip

    echo "[2/5] 安装 Caddy 所需的依赖..."
    sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https ca-certificates gnupg

    echo "[3/5] 添加 Caddy stable 版 GPG 密钥..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

    echo "[4/5] 添加 Caddy stable 版 apt 源..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null

    echo "[5/5] 再次更新软件包列表并安装 Caddy..."
    sudo apt update
    sudo apt install -y caddy
    systemctl enable caddy
fi

# 询问用户的域名或本地端口号
read -p "请输入你的域名或本地端口号: " domain

# 处理数字输入，判断是否有端口
if [[ "$domain" =~ ^[0-9]+$ ]]; then
    domain=":$domain"
fi

# 询问用户的反代地址（ip:port 格式）
read -p "输入反代地址 ip:port: " redomain

# 构建新的反代配置块
new_config="$domain {
    reverse_proxy $redomain {
        header_up Host {upstream_hostport}
    }

    @cors_preflight {
        method OPTIONS
        header Origin *
    }

    handle @cors_preflight {
        respond 204
        header Access-Control-Allow-Origin \"*\"
        header Access-Control-Allow-Methods \"GET, POST, OPTIONS\"
        header Access-Control-Allow-Headers \"*\"
    }

    header {
        Access-Control-Allow-Origin *
        Access-Control-Allow-Methods \"GET, POST, OPTIONS\"
    }
}"

# 检查 Caddyfile 是否存在以及是否包含该域名配置
echo "正在更新 Caddy 配置..."
if [ -f "/etc/caddy/Caddyfile" ]; then
    # 检查是否已存在该域名的配置
    if grep -q "^$domain {" /etc/caddy/Caddyfile; then
        echo "域名 $domain 的配置已存在，正在更新..."
        # 使用 sed 替换现有配置块
        sed -i "/^$domain {/,/^}/c\\$new_config" /etc/caddy/Caddyfile
    else
        echo "正在添加新的反代配置..."
        # 追加新配置到文件末尾
        echo "" >> /etc/caddy/Caddyfile
        echo "$new_config" >> /etc/caddy/Caddyfile
    fi
else
    echo "创建新的 Caddyfile..."
    echo "$new_config" > /etc/caddy/Caddyfile
fi

# 重启 Caddy 服务
echo "正在重启 Caddy 服务..."
sudo systemctl restart caddy

# 输出更新信息
echo "Caddy 配置已更新，并已重启 Caddy 服务！"
