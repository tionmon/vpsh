#!/usr/bin/env bash
# Incus 一键安装和配置脚本
# 集成安装、初始化、创建实例（容器/虚拟机）、配置网络和基础软件

set -e

# 检查是否以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "此脚本必须以 root 权限运行。请使用 sudo 或以 root 身份运行。"
    exit 1
fi

echo "================================"
echo "Incus 一键安装和配置脚本"
echo "================================"
echo ""

# ============================================
# 第一步：检测并安装 Incus
# ============================================
echo "步骤 1/9: 检测并安装 Incus..."

# 检测是否已安装 Incus
if command -v incus &>/dev/null; then
    echo "✓ 检测到 Incus 已安装，跳过安装步骤"
    incus version
else
    echo "未检测到 Incus，开始安装..."

    # 安装 gpg（如果尚未安装）
    if ! command -v gpg &>/dev/null; then
        echo "正在安装 gpg..."
        apt-get update
        apt-get install -y gnupg
    fi

    # 显示 GPG 密钥信息
    echo "显示 GPG 密钥信息："
    curl -fsSL https://pkgs.zabbly.com/key.asc | gpg --show-keys --fingerprint

    # 创建目录并下载密钥
    mkdir -p /etc/apt/keyrings/
    curl -fsSL https://pkgs.zabbly.com/key.asc -o /etc/apt/keyrings/zabbly.asc

    # 添加 apt 源（Stable）
    cat <<EOF >/etc/apt/sources.list.d/zabbly-incus-stable.sources
Enabled: yes
Types: deb
URIs: https://pkgs.zabbly.com/incus/stable
Suites: $(. /etc/os-release && echo ${VERSION_CODENAME})
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/zabbly.asc
EOF

    # 更新软件包列表并安装 incus
    apt-get update
    apt-get install -y incus

    echo "✓ Incus 安装完成"
fi
echo ""

# ============================================
# 第二步：初始化 Incus
# ============================================
echo "步骤 2/9: 初始化 Incus..."
incus admin init --minimal
echo "✓ Incus 初始化完成"
echo ""

# ============================================
# 第三步：获取用户输入的操作系统和实例名称
# ============================================
echo "步骤 3/9: 配置实例参数"

# 选择实例类型
echo "请选择实例类型："
echo "  1) 容器 (container) - 轻量级，不需要 KVM 支持（推荐）"
echo "  2) 虚拟机 (VM) - 需要 KVM 支持"
read -p "选择 [1]: " INSTANCE_TYPE_CHOICE
if [ -z "$INSTANCE_TYPE_CHOICE" ]; then
    INSTANCE_TYPE_CHOICE=1
fi

if [ "$INSTANCE_TYPE_CHOICE" = "2" ]; then
    INSTANCE_TYPE="vm"
    INSTANCE_TYPE_FLAG="--vm"
    INSTANCE_TYPE_NAME="虚拟机"
else
    INSTANCE_TYPE="container"
    INSTANCE_TYPE_FLAG=""
    INSTANCE_TYPE_NAME="容器"
fi

echo "请输入要安装的操作系统（例如: debian/12, ubuntu/22.04，默认: debian/12）："
read -p "操作系统名称: " OS_NAME
if [ -z "$OS_NAME" ]; then
    OS_NAME=debian/12
fi

echo "请输入实例名称（例如: d12, u22）："
read -p "实例名称: " INSTANCE_NAME

echo ""
echo "配置资源限制："
echo "请输入 CPU 核心数（默认: 1）："
read -p "CPU 核心数 [1]: " CPU_LIMIT
if [ -z "$CPU_LIMIT" ]; then
    CPU_LIMIT=1
fi

echo "请输入内存大小（单位: MiB，默认: 256）："
read -p "内存大小 [256]: " MEMORY_LIMIT
if [ -z "$MEMORY_LIMIT" ]; then
    MEMORY_LIMIT=256
fi

echo ""
echo "实例配置："
echo "  类型: ${INSTANCE_TYPE_NAME}"
echo "  操作系统: ${OS_NAME}"
echo "  实例名称: ${INSTANCE_NAME}"
echo "  CPU 核心数: ${CPU_LIMIT}"
echo "  内存大小: ${MEMORY_LIMIT}MiB"
echo ""

# ============================================
# 第四步：创建实例
# ============================================
echo "步骤 4/9: 创建${INSTANCE_TYPE_NAME}..."
echo "正在创建并启动 ${OS_NAME} ${INSTANCE_TYPE_NAME}，名称为 ${INSTANCE_NAME}..."
echo "配置: CPU=${CPU_LIMIT}核, 内存=${MEMORY_LIMIT}MiB"
incus launch images:${OS_NAME} ${INSTANCE_NAME} ${INSTANCE_TYPE_FLAG} --config limits.cpu=${CPU_LIMIT} --config limits.memory=${MEMORY_LIMIT}MiB

if [ "$INSTANCE_TYPE" = "vm" ]; then
    echo "等待虚拟机启动（30秒）..."
    sleep 30
else
    echo "等待容器启动（10秒）..."
    sleep 10
fi
echo "✓ ${INSTANCE_TYPE_NAME}创建完成"
echo ""

# ============================================
# 第五步：显示当前实例列表
# ============================================
echo "步骤 5/9: 显示实例列表"
incus list
echo ""

# ============================================
# 第六步：配置静态 IP 地址
# ============================================
echo "步骤 6/9: 配置网络"
echo "请输入要为实例分配的 IPv4 地址（例如: 实例列表 IPV4 地址）："
read -p "IP 地址: " IP_ADDRESS

echo "正在配置静态 IP 地址..."
incus config device override ${INSTANCE_NAME} eth0 ipv4.address=${IP_ADDRESS}

echo "✓ 网络配置完成"
echo ""

# ============================================
# 第七步：在实例内安装基础软件
# ============================================
echo "步骤 7/9: 安装基础软件包"
echo "正在实例内安装基础软件包..."

# 等待实例完全启动
echo "等待实例完全启动..."
for i in {1..30}; do
    if incus exec ${INSTANCE_NAME} -- test -f /etc/os-release 2>/dev/null; then
        echo "实例已就绪"
        break
    fi
    echo "等待中... ($i/30)"
    sleep 2
done

# 更新系统并安装软件包
echo "更新系统..."
incus exec ${INSTANCE_NAME} -- bash -c "apt update -y && apt full-upgrade -y"

echo "安装基础工具..."
incus exec ${INSTANCE_NAME} -- bash -c "apt install -y curl wget sudo unzip tar"

echo "安装 OpenSSH Server..."
incus exec ${INSTANCE_NAME} -- bash -c "apt install -y openssh-server"

echo "启用 SSH 服务..."
incus exec ${INSTANCE_NAME} -- bash -c "systemctl enable ssh && systemctl start ssh"

echo "✓ 基础软件包安装完成"
echo ""

# ============================================
# 第八步：配置 SSH 代理端口转发
# ============================================
echo "步骤 8/9: 配置 SSH 代理端口转发"

# 获取宿主机 IP 地址
echo "检测宿主机 IP 地址..."
HOST_IP=$(hostname -I | awk '{print $1}')
if [ -z "$HOST_IP" ]; then
    # 备用方法
    HOST_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}')
fi

echo "检测到的宿主机 IP 地址: ${HOST_IP}"
echo "请确认或输入宿主机 IP 地址（直接回车使用上述地址）："
read -p "宿主机 IP [${HOST_IP}]: " INPUT_HOST_IP
if [ -n "$INPUT_HOST_IP" ]; then
    HOST_IP=$INPUT_HOST_IP
fi

echo "请输入宿主机监听端口（用于 SSH 代理，避免使用 22 等常用端口，建议使用 2222-9999）："
read -p "SSH 代理端口: " SSH_PROXY_PORT

# 验证端口号
while [ -z "$SSH_PROXY_PORT" ] || [ "$SSH_PROXY_PORT" -lt 1024 ] || [ "$SSH_PROXY_PORT" -gt 65535 ]; do
    echo "请输入有效的端口号（1024-65535）："
    read -p "SSH 代理端口: " SSH_PROXY_PORT
done

echo "正在配置 SSH 代理..."
incus config device add ${INSTANCE_NAME} ssh-proxy proxy listen=tcp:${HOST_IP}:${SSH_PROXY_PORT} connect=tcp:0.0.0.0:22 nat=true

echo "✓ SSH 代理配置完成"
echo "  宿主机 IP: ${HOST_IP}"
echo "  监听端口: ${SSH_PROXY_PORT}"
echo ""

# ============================================
# 第九步：配置 root 密码登录
# ============================================
echo "步骤 9/9: 配置 root 密码登录"

# 配置 SSH 允许 root 密码登录
echo "配置 SSH 允许 root 密码登录..."
incus exec ${INSTANCE_NAME} -- bash -c "sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config"
incus exec ${INSTANCE_NAME} -- bash -c "sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config"

# 重启 SSH 服务
echo "重启 SSH 服务..."
incus exec ${INSTANCE_NAME} -- bash -c "systemctl restart ssh"

# 设置 root 密码
echo ""
echo "现在需要设置实例的 root 密码："
echo "请输入密码（输入时不会显示）："
incus exec ${INSTANCE_NAME} -- bash -c "passwd root"

echo ""
echo "✓ root 密码登录配置完成"
echo ""

# ============================================
# 完成
# ============================================
echo "================================"
echo "✓ 所有步骤完成！"
echo "================================"
echo ""
echo "实例信息："
echo "  类型: ${INSTANCE_TYPE_NAME}"
echo "  实例名称: ${INSTANCE_NAME}"
echo "  操作系统: ${OS_NAME}"
echo "  实例 IP: ${IP_ADDRESS}"
echo "  宿主机 IP: ${HOST_IP}"
echo "  SSH 代理端口: ${SSH_PROXY_PORT}"
echo ""
echo "=========================================="
echo "访问实例的方式："
echo "=========================================="
echo ""
echo "方式 1: 直接进入实例"
echo "  incus exec ${INSTANCE_NAME} -- bash"
echo ""
echo "方式 2: 通过实例 IP SSH 连接（局域网内）"
echo "  ssh root@${IP_ADDRESS}"
echo ""
echo "方式 3: 通过宿主机代理 SSH 连接（推荐，可远程访问）"
echo "  ssh -p ${SSH_PROXY_PORT} root@${HOST_IP}"
echo ""
echo "=========================================="
echo ""
echo "其他有用命令："
echo "  查看所有实例: incus list"
echo "  停止实例: incus stop ${INSTANCE_NAME}"
echo "  启动实例: incus start ${INSTANCE_NAME}"
echo "  删除实例: incus delete ${INSTANCE_NAME} --force"
echo ""
echo "提示：要让普通用户无需 sudo 即可使用 Incus，请运行："
echo "  sudo usermod -aG incus-admin \$USER"
echo "  然后注销并重新登录以使更改生效。"
echo ""
