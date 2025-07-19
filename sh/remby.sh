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
fi

# 询问用户的域名或本地端口号
read -p "请输入你的域名或本地端口号: " domain

# 处理数字输入，判断是否有端口
if [[ "$domain" =~ ^[0-9]+$ ]]; then
    domain=":$domain"
fi

# 询问用户的反代地址（ip:port 格式）
read -p "输入反代地址 ip:port: " redomain

# 构建 Caddy 配置
echo "正在更新 Caddy 配置..."
cat <<EOF > /etc/caddy/Caddyfile
$domain { 
    reverse_proxy $redomain { 
        header_up Host {upstream_hostport}
    }

    @cors_preflight {
        method OPTIONS
        header Origin *
    }

    handle @cors_preflight {
        respond 204
        header Access-Control-Allow-Origin "*"
        header Access-Control-Allow-Methods "GET, POST, OPTIONS"
        header Access-Control-Allow-Headers "*"
    }

    header {
        Access-Control-Allow-Origin *
        Access-Control-Allow-Methods "GET, POST, OPTIONS"
    }
}
EOF

# 重启 Caddy 服务
echo "正在重启 Caddy 服务..."
sudo systemctl restart caddy

# 输出更新信息
echo "Caddy 配置已更新，并已重启 Caddy 服务！"
