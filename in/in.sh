#!/bin/bash

# 删除 /etc/apt/sources.list 文件中的所有内容并添加新的源
echo "删除 /etc/apt/sources.list 文件中的所有内容并添加新的源"
echo "deb http://mirrors.aliyun.com/debian/ stable main contrib non-free non-free-firmware" | tee /etc/apt/sources.list > /dev/null

# 安装必要的软件包
echo "安装 curl, wget, sudo 和 unzip..."
 apt update
 apt install -y curl wget sudo unzip

# 更新 apt 包管理器的索引
echo "更新 apt 包管理器的索引"
 apt update

# 设置下载 URL 环境变量
export DOWNLOAD_URL="https://mirrors.tuna.tsinghua.edu.cn/docker-ce"
echo "DOWNLOAD_URL 环境变量已设置为 $DOWNLOAD_URL"

# 检查 /etc/docker 目录是否存在，如果不存在则创建
if [ ! -d "/etc/docker" ]; then
  echo "/etc/docker 目录不存在，正在创建..."
  mkdir -p /etc/docker
fi

# 创建 /etc/docker/daemon.json 文件并添加内容
echo '{"registry-mirrors": ["https://docker.1ms.run","https://docker.ketches.cn","https://docker.1panel.top","https://proxy.1panel.live","https://dockerproxy.1panel.live","https://docker.1panel.live","https://docker.1panelproxy.com","https://dockerproxy.net","https://docker-registry.nmqu.com","https://hub1.nat.tf"]}' > /etc/docker/daemon.json

# 检查文件是否创建成功
if [ $? -eq 0 ]; then
  echo "文件 /etc/docker/daemon.json 已成功创建并更新内容 脚本执行完成！"
else
  echo "创建或更新文件时出错"
fi

# 安装docker
curl -fsSL https://gh-proxy.com/raw.githubusercontent.com/docker/docker-install/master/install.sh | bash

# 下载 docker-compose-linux-x86_64 到 /usr/local/bin/ 命名为 docker-compose
curl -L -o /usr/local/bin/docker-compose https://gh-proxy.com/https://github.com/docker/compose/releases/download/v2.38.2/docker-compose-linux-x86_64


# 给文件添加可执行权限
chmod +x /usr/local/bin/docker-compose

# 输出结果
echo "docker-compose 已成功移动并赋予可执行权限"

# 创建并安装 v2raya
mkdir -p /home/docker/v2raya && cd /home/docker/v2raya && sudo curl -L -o docker-compose.yaml https://gh-proxy.com/https://raw.githubusercontent.com/tionmon/vpsh/refs/heads/main/v2raya.yaml

# 启动 docker-compose
docker-compose up -d

# 获取本机 IP
IP=$(curl -s ip.sb)

# 输出结果
echo "v2raya 已经安装 http://${IP}:2017"
