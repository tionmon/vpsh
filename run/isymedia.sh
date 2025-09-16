#!/bin/bash

# Media 一键部署脚本
# 作者: AI Assistant
# 版本: 1.0

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}    Media 服务一键部署脚本${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

# 检查网络连接
check_network() {
    print_message "检查网络连接..."
    
    if ping -c 1 8.8.8.8 &> /dev/null || ping -c 1 114.114.114.114 &> /dev/null; then
        print_message "网络连接正常"
        return 0
    else
        print_warning "网络连接异常，但继续执行..."
        return 1
    fi
}

# 获取服务器IP地址
get_server_ip() {
    local server_ip=""
    
    # 方法1: 尝试获取公网IP
    if command -v curl &> /dev/null; then
        # 尝试多个IP查询服务
        for service in "ip.sb" "ipinfo.io/ip" "icanhazip.com" "ipv4.icanhazip.com"; do
            server_ip=$(curl -s --connect-timeout 5 --max-time 10 "$service" 2>/dev/null | tr -d '\n\r')
            # 验证IP格式
            if [[ $server_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                echo "$server_ip"
                return 0
            fi
        done
    fi
    
    # 方法2: 获取默认路由的本地IP
    if command -v ip &> /dev/null; then
        server_ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[0-9.]+' | head -1)
        if [[ $server_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "$server_ip"
            return 0
        fi
    fi
    
    # 方法3: 使用hostname -I
    if command -v hostname &> /dev/null; then
        server_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        if [[ $server_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "$server_ip"
            return 0
        fi
    fi
    
    # 方法4: 使用ifconfig获取第一个非回环IP
    if command -v ifconfig &> /dev/null; then
        server_ip=$(ifconfig 2>/dev/null | grep -E 'inet [0-9]' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d':' -f2)
        if [[ $server_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "$server_ip"
            return 0
        fi
    fi
    
    # 方法5: 从/proc/net/route获取
    if [ -f /proc/net/route ]; then
        local gateway_iface=$(awk '$2 == 00000000 { print $1 }' /proc/net/route | head -1)
        if [ -n "$gateway_iface" ]; then
            server_ip=$(ip addr show "$gateway_iface" 2>/dev/null | grep -oP 'inet \K[0-9.]+' | head -1)
            if [[ $server_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                echo "$server_ip"
                return 0
            fi
        fi
    fi
    
    # 如果都失败了，返回localhost
    echo "localhost"
}

# 检查是否为root用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用root权限运行此脚本"
        print_message "使用命令: sudo $0"
        exit 1
    fi
}

# 更新系统并安装必要工具
update_system_and_install_tools() {
    print_message "更新系统并安装必要工具..."
    
    # 检测操作系统类型
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
    else
        OS="Unknown"
    fi
    
    # 根据不同系统使用不同的包管理器
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        print_message "检测到 Debian/Ubuntu 系统，使用 apt 更新..."
        apt update -y
        apt full-upgrade -y
        apt install -y curl wget sudo unzip tar
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Rocky"* ]] || [[ "$OS" == *"AlmaLinux"* ]]; then
        print_message "检测到 RHEL 系列系统，使用 yum/dnf 更新..."
        if command -v dnf &> /dev/null; then
            dnf update -y
            dnf install -y curl wget sudo unzip tar
        else
            yum update -y
            yum install -y curl wget sudo unzip tar
        fi
    elif [[ "$OS" == *"Fedora"* ]]; then
        print_message "检测到 Fedora 系统，使用 dnf 更新..."
        dnf update -y
        dnf install -y curl wget sudo unzip tar
    elif [[ "$OS" == *"Arch"* ]]; then
        print_message "检测到 Arch Linux 系统，使用 pacman 更新..."
        pacman -Syu --noconfirm
        pacman -S --noconfirm curl wget sudo unzip tar
    elif [[ "$OS" == *"openSUSE"* ]]; then
        print_message "检测到 openSUSE 系统，使用 zypper 更新..."
        zypper refresh
        zypper update -y
        zypper install -y curl wget sudo unzip tar
    else
        print_warning "未识别的操作系统，尝试使用 apt..."
        if command -v apt &> /dev/null; then
            apt update -y
            apt full-upgrade -y
            apt install -y curl wget sudo unzip tar
        else
            print_warning "无法自动更新系统，请手动安装必要工具: curl wget sudo unzip tar"
        fi
    fi
    
    print_message "系统更新和工具安装完成"
}

# 检测操作系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        OS=Debian
        VER=$(cat /etc/debian_version)
    elif [ -f /etc/SuSe-release ]; then
        OS=openSUSE
    elif [ -f /etc/redhat-release ]; then
        OS=RedHat
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
}

# 安装Docker (Ubuntu/Debian)
install_docker_debian() {
    print_message "在 Debian/Ubuntu 系统上安装 Docker..."
    
    # 更新包索引
    apt-get update
    
    # 安装必要的包
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # 添加Docker官方GPG密钥
    mkdir -p /etc/apt/keyrings
    
    # 删除已存在的GPG密钥文件以避免覆盖提示
    rm -f /etc/apt/keyrings/docker.gpg
    
    # 根据系统选择正确的GPG密钥URL
    if [[ "$OS" == *"Debian"* ]]; then
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        DOCKER_REPO="https://download.docker.com/linux/debian"
    else
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        DOCKER_REPO="https://download.docker.com/linux/ubuntu"
    fi
    
    # 添加Docker仓库
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $DOCKER_REPO \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 更新包索引
    apt-get update
    
    # 安装Docker Engine
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    print_message "Docker 安装完成"
}

# 安装Docker (CentOS/RHEL/Rocky Linux)
install_docker_rhel() {
    print_message "在 CentOS/RHEL/Rocky Linux 系统上安装 Docker..."
    
    # 安装必要的包
    yum install -y yum-utils
    
    # 添加Docker仓库
    yum-config-manager \
        --add-repo \
        https://download.docker.com/linux/centos/docker-ce.repo
    
    # 安装Docker Engine
    yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    print_message "Docker 安装完成"
}

# 安装Docker (Fedora)
install_docker_fedora() {
    print_message "在 Fedora 系统上安装 Docker..."
    
    # 安装必要的包
    dnf -y install dnf-plugins-core
    
    # 添加Docker仓库
    dnf config-manager \
        --add-repo \
        https://download.docker.com/linux/fedora/docker-ce.repo
    
    # 安装Docker Engine
    dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    print_message "Docker 安装完成"
}

# 安装Docker (Arch Linux)
install_docker_arch() {
    print_message "在 Arch Linux 系统上安装 Docker..."
    
    # 更新包数据库
    pacman -Sy
    
    # 安装Docker
    pacman -S --noconfirm docker docker-compose
    
    print_message "Docker 安装完成"
}

# 安装Docker (openSUSE)
install_docker_opensuse() {
    print_message "在 openSUSE 系统上安装 Docker..."
    
    # 添加Docker仓库
    zypper addrepo https://download.docker.com/linux/opensuse/docker-ce.repo
    
    # 安装Docker
    zypper install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    print_message "Docker 安装完成"
}

# 设置Docker开机自启动
setup_docker_autostart() {
    print_message "设置Docker开机自启动..."
    
    # 启动Docker服务
    systemctl start docker
    
    # 设置开机自启动
    systemctl enable docker
    
    # 检查服务状态
    if systemctl is-active --quiet docker; then
        print_message "Docker服务已启动"
    else
        print_warning "Docker服务启动失败，尝试重新启动..."
        systemctl restart docker
        sleep 3
        if systemctl is-active --quiet docker; then
            print_message "Docker服务重启成功"
        else
            print_error "Docker服务启动失败，请检查系统日志"
            exit 1
        fi
    fi
    
    if systemctl is-enabled --quiet docker; then
        print_message "Docker开机自启动已设置"
    else
        print_error "Docker开机自启动设置失败"
        exit 1
    fi
}

# 安装Docker Compose (如果需要)
install_docker_compose() {
    print_message "检查Docker Compose..."
    
    # 检查是否有docker compose插件
    if docker compose version &> /dev/null; then
        print_message "Docker Compose (插件版本) 已安装"
        return
    fi
    
    # 检查是否有独立的docker-compose
    if command -v docker-compose &> /dev/null; then
        print_message "Docker Compose (独立版本) 已安装"
        return
    fi
    
    print_message "安装Docker Compose..."
    
    # 获取最新版本号
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    
    # 下载并安装Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    # 设置执行权限
    chmod +x /usr/local/bin/docker-compose
    
    # 创建符号链接
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    print_message "Docker Compose 安装完成"
}

# 检查并安装Docker
check_and_install_docker() {
    print_message "检查Docker环境..."
    
    # 检测操作系统
    detect_os
    print_message "检测到操作系统: $OS $VER"
    
    # 检查Docker是否已安装
    if command -v docker &> /dev/null; then
        print_message "Docker 已安装，版本: $(docker --version)"
        
        # 检查Docker服务是否运行
        if systemctl is-active --quiet docker; then
            print_message "Docker 服务正在运行"
        else
            print_message "启动Docker服务..."
            systemctl start docker
        fi
        
        # 检查Docker是否设置为开机自启
        if ! systemctl is-enabled --quiet docker; then
            print_message "设置Docker开机自启动..."
            systemctl enable docker
        fi
    else
        print_message "Docker 未安装，将自动安装Docker..."
        print_message "开始自动安装Docker..."
        
        case $OS in
            "Ubuntu"|"Debian GNU/Linux"|"Debian")
                install_docker_debian
                ;;
            "CentOS Linux"|"Red Hat Enterprise Linux"|"Rocky Linux"|"AlmaLinux")
                install_docker_rhel
                ;;
            "Fedora Linux"|"Fedora")
                install_docker_fedora
                ;;
            "Arch Linux")
                install_docker_arch
                ;;
            "openSUSE"*)
                install_docker_opensuse
                ;;
            *)
                print_error "不支持的操作系统: $OS"
                print_message "请手动安装Docker后重新运行此脚本"
                exit 1
                ;;
        esac
        
        # 设置开机自启动
        setup_docker_autostart
    fi
    
    # 安装Docker Compose (如果需要)
    install_docker_compose
    
    # 验证安装
    print_message "验证Docker安装..."
    if docker --version && (docker compose version || docker-compose --version); then
        print_message "Docker环境检查通过"
    else
        print_error "Docker安装验证失败"
        exit 1
    fi
    
    # 测试Docker是否可以正常运行
    print_message "测试Docker功能..."
    if docker run --rm hello-world &> /dev/null; then
        print_message "Docker功能测试通过"
    else
        print_warning "Docker功能测试失败，但继续执行部署..."
    fi
}

# 创建必要的目录
create_directories() {
    print_message "创建必要的目录..."
    
    # 创建主要目录
    mkdir -p /home/docker/aaaa
    mkdir -p /home/docker/aaaa/openlist/data
    mkdir -p /volume1/media/data
    mkdir -p /volume2/hdd/Resource
    mkdir -p /volume1/CloudNAS
    
    print_message "目录创建完成"
}

# 下载docker-compose.yaml文件
download_compose_file() {
    print_message "下载docker-compose.yaml文件..."
    
    local compose_url="https://cloud.7so.top/f/AnprUE/docker-compose.yaml"
    local target_dir="/home/docker/aaaa"
    local target_file="$target_dir/docker-compose.yaml"
    
    # 确保目标目录存在
    mkdir -p "$target_dir"
    
    # 检查并删除已存在的文件
    if [ -f "$target_file" ]; then
        print_warning "发现已存在的docker-compose.yaml文件，正在删除..."
        rm -f "$target_file"
        print_message "已删除旧文件，准备下载新文件"
    fi
    
    # 下载文件
    if command -v curl &> /dev/null; then
        if curl -fsSL "$compose_url" -o "$target_file"; then
            print_message "docker-compose.yaml 下载成功"
        else
            print_error "下载失败，请检查网络连接"
            exit 1
        fi
    elif command -v wget &> /dev/null; then
        if wget -q "$compose_url" -O "$target_file"; then
            print_message "docker-compose.yaml 下载成功"
        else
            print_error "下载失败，请检查网络连接"
            exit 1
        fi
    else
        print_error "未找到 curl 或 wget 工具，无法下载文件"
        exit 1
    fi
    
    # 验证文件是否下载成功
    if [ ! -f "$target_file" ] || [ ! -s "$target_file" ]; then
        print_error "docker-compose.yaml 文件下载失败或文件为空"
        exit 1
    fi
    
    print_message "docker-compose.yaml 文件已保存到: $target_file"
}

# 获取Symedia配置信息
get_symedia_config() {
    echo ""
    print_message "Symedia 配置设置"
    echo ""
    
    # 获取 Symedia 的用户名和密码
    print_message "请输入 Symedia 的用户名和密码:"
    read -p "global_settings username: " GLOBAL_USERNAME
    read -s -p "global_settings password: " GLOBAL_PASSWORD
    echo ""
    
    # 获取 Clouddrive2 的用户名和密码
    print_message "请输入 Clouddrive2 的用户名和密码:"
    read -p "cloud_drive_config username: " CLOUD_DRIVE_USERNAME
    read -s -p "cloud_drive_config password: " CLOUD_DRIVE_PASSWORD
    echo ""
    
    # 获取115 /待刮削/mix 文件夹ID
    print_message "请输入115 /待刮削/mix 文件夹ID:"
    read -p "115文件夹ID: " FOLDER_115_ID
    
    # 获取115 cookies
    print_message "请输入115 cookies:"
    read -p "115 cookies: " COOKIES_115
    
    # 获取Telegram配置
    print_message "请输入Telegram配置:"
    read -p "Telegram bot_token: " TG_BOT_TOKEN
    read -p "Telegram chat_id: " TG_CHAT_ID
    
    echo ""
    print_message "Symedia配置信息已收集完成"
}


# 获取DockerCopilot secretKey
get_dockercopilot_secretkey() {
    echo ""
    print_message "请输入DockerCopilot secretKey:"
    read -p "secretKey: " DOCKERCOPILOT_SECRET_KEY
    
    if [ -z "$DOCKERCOPILOT_SECRET_KEY" ]; then
        print_warning "secretKey不能为空，使用默认空值"
        DOCKERCOPILOT_SECRET_KEY=""
    fi
    
    echo ""
    print_message "DockerCopilot secretKey已设置: ${DOCKERCOPILOT_SECRET_KEY:0:10}..." # 只显示前10个字符保护隐私
}

# 下载并解压aaaa.tar.gz文件
download_and_extract_aaaa() {
    print_message "开始下载和解压aaaa.tar.gz文件..."
    
    local download_url="https://cloud.7so.top/f/Elw2hp/aaaa.tar.gz"
    local target_dir="/home/docker"
    local temp_file="/tmp/aaaa.tar.gz"
    
    # 确保目标目录存在
    if [ ! -d "$target_dir" ]; then
        print_message "创建目录: $target_dir"
        mkdir -p "$target_dir"
    fi
    
    # 清理可能存在的临时文件
    if [ -f "$temp_file" ]; then
        rm -f "$temp_file"
    fi
    
    # 下载文件
    print_message "正在下载文件..."
    if command -v curl &> /dev/null; then
        if curl -fL --progress-bar "$download_url" -o "$temp_file"; then
            print_message "文件下载成功"
        else
            print_error "下载失败，请检查网络连接"
            exit 1
        fi
    elif command -v wget &> /dev/null; then
        if wget --progress=bar "$download_url" -O "$temp_file"; then
            print_message "文件下载成功"
        else
            print_error "下载失败，请检查网络连接"
            exit 1
        fi
    else
        print_error "未找到 curl 或 wget 工具，无法下载文件"
        exit 1
    fi
    
    # 验证下载的文件
    if [ ! -f "$temp_file" ] || [ ! -s "$temp_file" ]; then
        print_error "下载的文件不存在或为空"
        exit 1
    fi
    
    # 检查文件类型（使用更通用的方法）
    if command -v file &> /dev/null; then
        if ! file "$temp_file" | grep -q -E "(gzip compressed|compressed data)"; then
            print_warning "文件类型检查警告，但将继续尝试解压..."
        else
            print_message "文件类型验证通过"
        fi
    else
        print_message "跳过文件类型检查（file命令不可用）"
    fi
    
    # 解压文件
    print_message "正在解压文件到 $target_dir ..."
    cd "$target_dir" || {
        print_error "无法切换到目录: $target_dir"
        exit 1
    }
    
    if tar -xzf "$temp_file" --verbose; then
        print_message "文件解压成功"
    else
        print_error "文件解压失败，可能的原因："
        print_error "1. 文件损坏"
        print_error "2. 磁盘空间不足"
        print_error "3. 权限不足"
        print_message "尝试手动解压：tar -xzf $temp_file -C $target_dir"
        exit 1
    fi
    
    # 清理临时文件
    rm -f "$temp_file"
    
    # 验证解压结果
    if [ -d "$target_dir/aaaa" ]; then
        print_message "aaaa目录已成功创建在: $target_dir/aaaa"
    else
        print_warning "未找到预期的aaaa目录，但解压过程已完成"
    fi
    
    print_message "aaaa.tar.gz 下载和解压完成"
}


# 更新Symedia配置文件
update_symedia_config() {
    print_message "更新Symedia配置文件..."
    
    local config_dir="/home/docker/aaaa/symedia/config"
    local config_file="$config_dir/config.yaml"
    
    # 确保目录存在
    mkdir -p "$config_dir"
    
    # 如果文件存在，先备份
    if [ -f "$config_file" ]; then
        print_message "发现已存在的config.yaml文件，正在备份..."
        cp "$config_file" "$config_file.backup.$(date +%Y%m%d_%H%M%S)"
        print_message "备份完成，将仅更新指定配置项"
    else
        print_message "配置文件不存在，将创建新文件"
        # 创建基础配置文件
        cat > "$config_file" << EOF
global_settings:
  username: 
  password: 

cloud_drive_config:
  username: 
  password: 

cloud_drive_transfer_refresh_dir:
  cloud_115:
  - :/115/待刮削/mix

settings_115:
- name: 115(IOS端)_Sy_cd2
  cookies: ''
  status: false
  id: e4059dcd-a412-4506-8d3c-eb829f92c0d4

notify_config:
  telegram:
    switch: true
    bot_token: 
    chat_id: 
EOF
    fi
    
    # 创建临时文件进行替换
    temp_file=$(mktemp)
    
    # 逐行读取并替换指定配置项
    while IFS= read -r line || [ -n "$line" ]; do
        # 替换global_settings下的username
        if [[ "$line" =~ ^[[:space:]]*username:[[:space:]]* ]] && [[ "$in_global_settings" == "true" ]]; then
            indent="${line%%username*}"
            echo "${indent}username: ${GLOBAL_USERNAME}"
        # 替换global_settings下的password
        elif [[ "$line" =~ ^[[:space:]]*password:[[:space:]]* ]] && [[ "$in_global_settings" == "true" ]]; then
            indent="${line%%password*}"
            echo "${indent}password: ${GLOBAL_PASSWORD}"
        # 替换cloud_drive_config下的username
        elif [[ "$line" =~ ^[[:space:]]*username:[[:space:]]* ]] && [[ "$in_cloud_drive_config" == "true" ]]; then
            indent="${line%%username*}"
            echo "${indent}username: ${CLOUD_DRIVE_USERNAME}"
        # 替换cloud_drive_config下的password
        elif [[ "$line" =~ ^[[:space:]]*password:[[:space:]]* ]] && [[ "$in_cloud_drive_config" == "true" ]]; then
            indent="${line%%password*}"
            echo "${indent}password: ${CLOUD_DRIVE_PASSWORD}"
        # 替换115文件夹ID
        elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]*[^:]*:/115/待刮削/mix$ ]]; then
            indent="${line%%-*}"
            echo "${indent}- ${FOLDER_115_ID}:/115/待刮削/mix"
        # 替换115 cookies
        elif [[ "$line" =~ ^[[:space:]]*cookies:[[:space:]]* ]]; then
            indent="${line%%cookies*}"
            echo "${indent}cookies: '${COOKIES_115}'"
        # 替换telegram bot_token
        elif [[ "$line" =~ ^[[:space:]]*bot_token:[[:space:]]* ]]; then
            indent="${line%%bot_token*}"
            echo "${indent}bot_token: ${TG_BOT_TOKEN}"
        # 替换telegram chat_id
        elif [[ "$line" =~ ^[[:space:]]*chat_id:[[:space:]]* ]]; then
            indent="${line%%chat_id*}"
            echo "${indent}chat_id: ${TG_CHAT_ID}"
        # 替换helper_115下的share_cids
        elif [[ "$line" =~ ^[[:space:]]*share_cids:[[:space:]]* ]]; then
            indent="${line%%share_cids*}"
            echo "${indent}share_cids: 'mix:${FOLDER_115_ID}'"
        else
            echo "$line"
        fi
        
        # 检测当前所在的配置区域
        if [[ "$line" =~ ^global_settings: ]]; then
            in_global_settings="true"
            in_cloud_drive_config="false"
        elif [[ "$line" =~ ^cloud_drive_config: ]]; then
            in_global_settings="false"
            in_cloud_drive_config="true"
        elif [[ "$line" =~ ^[a-zA-Z_]+: ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
            in_global_settings="false"
            in_cloud_drive_config="false"
        fi
    done < "$config_file" > "$temp_file"
    
    # 替换原文件
    mv "$temp_file" "$config_file"
    
    print_message "Symedia配置文件已更新: $config_file"
    
    # 验证文件是否更新成功
    if [ -f "$config_file" ] && [ -s "$config_file" ]; then
        print_message "配置文件更新成功"
    else
        print_error "配置文件更新失败"
        exit 1
    fi
}

# 更新FastEmby配置文件
update_fastemby_config() {
    print_message "更新FastEmby配置文件..."
    
    local config_dir="/home/docker/aaaa/FastEmby/config"
    local config_file="$config_dir/config.yaml"
    
    # 确保目录存在
    mkdir -p "$config_dir"
    
    # 如果文件存在，先备份
    if [ -f "$config_file" ]; then
        print_message "发现已存在的FastEmby config.yaml文件，正在备份..."
        cp "$config_file" "$config_file.backup.$(date +%Y%m%d_%H%M%S)"
        print_message "备份完成，将仅更新指定配置项"
    else
        print_message "FastEmby配置文件不存在，将创建新文件"
        # 创建基础配置文件
        cat > "$config_file" << EOF
username: 
password: 

115_cookies: 
EOF
    fi
    
    # 创建临时文件进行替换
    temp_file=$(mktemp)
    
    # 逐行读取并替换指定配置项
    while IFS= read -r line || [ -n "$line" ]; do
        # 替换username
        if [[ "$line" =~ ^[[:space:]]*username:[[:space:]]* ]]; then
            indent="${line%%username*}"
            echo "${indent}username: ${GLOBAL_USERNAME}"
        # 替换password
        elif [[ "$line" =~ ^[[:space:]]*password:[[:space:]]* ]]; then
            indent="${line%%password*}"
            echo "${indent}password: ${GLOBAL_PASSWORD}"
        # 替换115_cookies
        elif [[ "$line" =~ ^[[:space:]]*115_cookies:[[:space:]]* ]]; then
            indent="${line%%115_cookies*}"
            echo "${indent}115_cookies: ${COOKIES_115}"
        else
            echo "$line"
        fi
    done < "$config_file" > "$temp_file"
    
    # 替换原文件
    mv "$temp_file" "$config_file"
    
    print_message "FastEmby配置文件已更新: $config_file"
    
    # 验证文件是否更新成功
    if [ -f "$config_file" ] && [ -s "$config_file" ]; then
        print_message "FastEmby配置文件更新成功"
    else
        print_error "FastEmby配置文件更新失败"
        exit 1
    fi
}


# 提前获取Symedia激活码
get_license_key_early() {
    echo ""
    print_message "请输入Symedia激活码:"
    read -p "激活码: " LICENSE_KEY
    
    if [ -z "$LICENSE_KEY" ]; then
        print_warning "激活码不能为空，使用默认空值"
        LICENSE_KEY=""
    fi
    
    echo ""
    print_message "激活码已设置: ${LICENSE_KEY:0:10}..." # 只显示前10个字符保护隐私
    print_message "开始系统初始化..."
}

# 获取Symedia激活码（备用函数，现在只用于确认）
get_license_key() {
    # 如果已经设置了激活码，直接返回
    if [ -n "$LICENSE_KEY" ]; then
        print_message "使用已设置的Symedia激活码"
        return
    fi
    
    # 如果在Docker安装时输入过激活码，使用那个
    if [ -n "$DOCKER_INSTALL_LICENSE_KEY" ]; then
        LICENSE_KEY="$DOCKER_INSTALL_LICENSE_KEY"
        print_message "使用Docker安装时输入的激活码"
        print_message "激活码已设置: ${LICENSE_KEY:0:10}..." # 只显示前10个字符保护隐私
        return
    fi
    
    echo ""
    print_message "请输入Symedia激活码:"
    read -p "激活码: " LICENSE_KEY
    
    if [ -z "$LICENSE_KEY" ]; then
        print_warning "激活码不能为空，使用默认空值"
        LICENSE_KEY=""
    fi
    
    echo ""
    print_message "激活码已设置: ${LICENSE_KEY:0:10}..." # 只显示前10个字符保护隐私
}

# 更新docker-compose.yaml中的LICENSE_KEY和SECRET_KEY
update_license_keys() {
    print_message "更新配置文件中的激活码和密钥..."
    
    local target_file="/home/docker/aaaa/docker-compose.yaml"
    
    if [ ! -f "$target_file" ]; then
        print_error "docker-compose.yaml文件不存在: $target_file"
        exit 1
    fi
    
    # 备份原文件
    cp "$target_file" "$target_file.backup"
    
    # 更新Symedia和FastEmby的LICENSE_KEY以及DockerCopilot的SECRET_KEY
    # 使用更安全的方法进行替换，避免特殊字符问题
    print_message "正在更新激活码和密钥..."
    
    # 创建临时文件进行替换
    temp_file=$(mktemp)
    
    # 逐行读取并替换
    while IFS= read -r line || [ -n "$line" ]; do
        # 检查是否是LICENSE_KEY行（以- LICENSE_KEY=结尾且后面没有其他内容）
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+LICENSE_KEY=[[:space:]]*$ ]]; then
            # 获取行的缩进（使用bash内置功能）
            indent="${line%%-*}"
            echo "${indent}- LICENSE_KEY=${LICENSE_KEY}"
        # 检查是否是secretKey行（以- secretKey=开头）
        elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]+secretKey= ]]; then
            # 获取行的缩进（使用bash内置功能）
            indent="${line%%-*}"
            echo "${indent}- secretKey=${DOCKERCOPILOT_SECRET_KEY}"
        else
            echo "$line"
        fi
    done < "$target_file" > "$temp_file"
    
    # 替换原文件
    mv "$temp_file" "$target_file"
    
    print_message "激活码和密钥配置更新完成"
    
    # 验证更新是否成功
    local license_updated=false
    local secret_updated=false
    
    if grep -q "LICENSE_KEY=${LICENSE_KEY}" "$target_file"; then
        print_message "Symedia激活码已成功填入配置文件"
        license_updated=true
    else
        print_warning "Symedia激活码填入可能不完整，请检查配置文件"
    fi
    
    if grep -q "secretKey=${DOCKERCOPILOT_SECRET_KEY}" "$target_file"; then
        print_message "DockerCopilot密钥已成功填入配置文件"
        secret_updated=true
    else
        print_warning "DockerCopilot密钥填入可能不完整，请检查配置文件"
    fi
    
    if [ "$license_updated" = true ] && [ "$secret_updated" = true ]; then
        print_message "所有密钥配置更新成功"
    fi
}

# 拉取Docker镜像
pull_images() {
    print_message "拉取Docker镜像..."
    
    # 切换到目标目录
    cd /home/docker/aaaa || {
        print_error "无法切换到目录 /home/docker/aaaa"
        exit 1
    }
    
    # 使用docker-compose拉取所有镜像
    if command -v docker-compose &> /dev/null; then
        docker-compose pull
    else
        docker compose pull
    fi
    
    print_message "镜像拉取完成"
}

# 启动服务
start_services() {
    print_message "启动服务..."
    
    # 切换到目标目录
    cd /home/docker/aaaa || {
        print_error "无法切换到目录 /home/docker/aaaa"
        exit 1
    }
    
    # 启动所有服务
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi
    
    print_message "服务启动完成"
}

# 显示服务状态
show_status() {
    echo ""
    print_message "服务状态:"
    
    # 切换到目标目录
    cd /home/docker/aaaa || {
        print_error "无法切换到目录 /home/docker/aaaa"
        return 1
    }
    
    if command -v docker-compose &> /dev/null; then
        docker-compose ps
    else
        docker compose ps
    fi
    
    echo ""
    print_message "服务访问地址:"
    
    # 获取服务器IP地址
    SERVER_IP=$(get_server_ip)
    
    if [ "$SERVER_IP" != "localhost" ]; then
        print_message "检测到服务器IP: $SERVER_IP"
    else
        print_warning "无法检测到服务器IP，使用localhost"
    fi
    
    echo ""
    echo -e "  ${GREEN}Symedia:${NC}      http://${SERVER_IP}:8095"
    echo -e "  ${GREEN}CloudDrive:${NC}   http://${SERVER_IP}:19798"
    echo -e "  ${GREEN}Emby:${NC}         http://${SERVER_IP}:8096"
    echo -e "  ${GREEN}OpenList:${NC}     http://${SERVER_IP}:5244"
    echo -e "  ${GREEN}DockerCopilot:${NC} http://${SERVER_IP}:12712"
    echo -e "  ${GREEN}MoviePilot:${NC}   http://${SERVER_IP}:3000"
    echo ""
    print_message "配置文件位置: /home/docker/aaaa/docker-compose.yaml"
    echo ""
}


# 获取MoviePilot初始密码（内部执行）
get_moviepilot_password_once() {
    print_message "等待MoviePilot服务启动并获取初始密码..."
    
    # 切换到目标目录
    cd /home/docker/aaaa || {
        print_error "无法切换到目录 /home/docker/aaaa"
        return 1
    }
    
    # 等待最多5分钟来获取密码
    local max_wait=300  # 5分钟
    local wait_time=0
    local check_interval=10  # 每10秒检查一次
    
    print_message "正在等待MoviePilot生成初始密码（最多等待5分钟）..."
    
    while [ $wait_time -lt $max_wait ]; do
        # 检查容器是否正在运行
        if ! docker compose ps moviepilot 2>/dev/null | grep -q "Up"; then
            print_warning "MoviePilot容器尚未启动，继续等待..."
            sleep $check_interval
            wait_time=$((wait_time + check_interval))
            continue
        fi
        
        # 获取日志并查找密码信息
        local log_output
        if command -v docker-compose &> /dev/null; then
            log_output=$(docker-compose logs moviepilot 2>/dev/null)
        else
            log_output=$(docker compose logs moviepilot 2>/dev/null)
        fi
        
        # 查找超级管理员初始密码关键词
        local password_info=$(echo "$log_output" | grep -i "超级管理员初始密码")
        
        if [ -n "$password_info" ]; then
            echo ""
            echo "🎉 MoviePilot 密码获取成功"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "$log_output" | grep -i -A 2 "超级管理员初始密码"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "🌐 访问地址: http://${SERVER_IP:-localhost}:3000"
            echo "👤 用户名: admin"
            echo ""
            return 0
        fi
        
        # 显示等待进度
        echo -n "."
        sleep $check_interval
        wait_time=$((wait_time + check_interval))
    done
    
    echo ""
    print_warning "等待超时，未能获取到MoviePilot初始密码"
    print_message "请手动查看MoviePilot日志获取初始密码："
    print_message "命令: cd /home/docker/aaaa && docker compose logs moviepilot | grep -i 密码"
    echo ""
}

# 获取OpenList初始密码（内部执行）
get_openlist_password_once() {
    print_message "等待OpenList服务启动并获取初始密码..."
    
    # 切换到目标目录
    cd /home/docker/aaaa || {
        print_error "无法切换到目录 /home/docker/aaaa"
        return 1
    }
    
    # 等待最多3分钟来获取密码
    local max_wait=180  # 3分钟
    local wait_time=0
    local check_interval=10  # 每10秒检查一次
    
    print_message "正在等待OpenList生成初始密码（最多等待3分钟）..."
    
    while [ $wait_time -lt $max_wait ]; do
        # 检查容器是否正在运行
        if ! docker compose ps openlist 2>/dev/null | grep -q "Up"; then
            print_warning "OpenList容器尚未启动，继续等待..."
            sleep $check_interval
            wait_time=$((wait_time + check_interval))
            continue
        fi
        
        # 获取日志并查找密码信息
        local log_output
        if command -v docker-compose &> /dev/null; then
            log_output=$(docker-compose logs openlist 2>/dev/null)
        else
            log_output=$(docker compose logs openlist 2>/dev/null)
        fi
        
        # 查找包含"Successfully created the admin user"的行
        local password_info=$(echo "$log_output" | grep -i "Successfully created the admin user")
        
        if [ -n "$password_info" ]; then
            echo ""
            echo "🎉 OpenList 密码获取成功"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "$log_output" | grep -i -A 2 "Successfully created the admin user"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "🌐 访问地址: http://${SERVER_IP:-localhost}:5244"
            echo "👤 用户名: admin"
            echo ""
            return 0
        fi
        
        # 显示等待进度
        echo -n "."
        sleep $check_interval
        wait_time=$((wait_time + check_interval))
    done
    
    echo ""
    print_warning "等待超时，未能获取到OpenList初始密码"
    print_message "请手动查看OpenList日志获取初始密码："
    print_message "命令: cd /home/docker/aaaa && docker compose logs openlist | grep -i admin"
    echo ""
}


# 主函数
main() {
    print_header
    
    # 检查运行权限
    check_root
    
    # 获取激活码（优先进行）
    get_license_key_early
    
    # 获取DockerCopilot secretKey
    get_dockercopilot_secretkey
    
    # 获取Symedia配置信息
    get_symedia_config
    
    # 下载并解压aaaa.tar.gz文件
    download_and_extract_aaaa
    
    # 更新系统并安装必要工具
    update_system_and_install_tools
    
    # 检查网络连接
    check_network
    
    # 检查并安装Docker环境
    check_and_install_docker
    
    # 创建目录
    create_directories
    
    # 更新Symedia配置文件
    update_symedia_config
    
    # 更新FastEmby配置文件
    update_fastemby_config
    
    # 下载docker-compose.yaml文件
    download_compose_file
    
    
    # 获取激活码
    get_license_key
    
    # 更新配置
    update_license_keys
    
    # 拉取镜像
    pull_images
    
    # 启动服务
    start_services
    
    # 显示状态
    show_status
    
    # 等待服务启动并获取MoviePilot初始密码
    get_moviepilot_password_once
    
    # 等待服务启动并获取OpenList初始密码
    get_openlist_password_once
    
    
    print_message "🎉 部署完成！"
    print_warning "首次启动可能需要几分钟时间来初始化服务"
    echo ""
    print_message "📁 工作目录: cd /home/docker/aaaa"
    print_message "🔧 常用命令："
    echo "  • 停止服务: docker compose down"
    echo "  • 查看日志: docker compose logs -f [服务名]"
    echo "  • 重新启动: docker compose up -d"
    echo ""
}

# 脚本入口
main "$@"
