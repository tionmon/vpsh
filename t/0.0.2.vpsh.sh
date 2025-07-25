#!/bin/bash

# 检测终端是否支持颜色
if [ -t 1 ] && command -v tput > /dev/null && [ $(tput colors) -ge 8 ]; then
    # 定义颜色变量 - 优化后的颜色配置，提高在light模式下的可读性
    RED="$(tput setaf 1)$(tput bold)"
    GREEN="$(tput setaf 2)$(tput bold)"
    YELLOW="$(tput setaf 3)$(tput bold)"
    BLUE="$(tput setaf 4)$(tput bold)"
    MAGENTA="$(tput setaf 5)$(tput bold)"
    CYAN="$(tput setaf 6)$(tput bold)"
    WHITE="$(tput setaf 7)$(tput bold)"
    BOLD="$(tput bold)"
    RESET="$(tput sgr0)"
else
    # 如果不支持颜色，则使用空字符串
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    WHITE=""
    BOLD=""
    RESET=""
fi

# 清屏
clear

# 获取终端宽度
TERM_WIDTH=$(tput cols)

# 如果终端宽度未知或太小，设置一个默认值
if [ -z "$TERM_WIDTH" ] || [ "$TERM_WIDTH" -lt 60 ]; then
    TERM_WIDTH=60
fi

# 计算边框宽度
BORDER_WIDTH=$TERM_WIDTH

# 创建分隔线函数
draw_line() {
    printf "${CYAN}+%${BORDER_WIDTH}s+${RESET}\n" | tr ' ' '-'
}

# 创建居中文本函数
center_text() {
    local text="$1"
    local color="$2"
    local text_length=${#text}
    local padding=$(( (BORDER_WIDTH - text_length) / 2 ))
    printf "${CYAN}|${RESET}%${padding}s${color}${BOLD}%s${RESET}%${padding}s${CYAN}|${RESET}\n" "" "$text" ""
}

# 创建选项显示函数
# 箭头样式数组
arrow_styles=("→→→" "➔ " "➡️ " "⇨ " "⇒ " "⮞⮞⮞" "➜ " "➙ " "➸ " "⮕ ")

show_option() {
    local number="$1"
    local description="$2"
    local short_desc="$3"
    
    # 根据序号选择箭头样式，循环使用
    local arrow_index=$(( $number % ${#arrow_styles[@]} ))
    local arrow_style=${arrow_styles[$arrow_index]}
    
    # 优化显示格式，提高light模式下的可读性
    printf "${CYAN}|${RESET}  ${YELLOW}%-4s${RESET}${BOLD}%-10s${RESET}${MAGENTA}%s${RESET} ${GREEN}%-$(( BORDER_WIDTH - 30 ))s${RESET}${CYAN}|${RESET}\n" "$number." "$description" "$arrow_style" "$short_desc"
}

# 显示标题
draw_line
center_text "VPSH 脚本管理面板 v0.0.2" "${MAGENTA}"
draw_line

# 显示选项
printf "${CYAN}|${GREEN}${BOLD} 请选择要执行的脚本：${RESET}%$(( BORDER_WIDTH - 24 ))s${CYAN}|${RESET}\n" ""
draw_line

show_option "0" "t" "快捷别名设置"
show_option "1" "kejilion" "科技lion一键脚本"
show_option "2" "reinstall" "系统重装工具"
show_option "3" "jpso" "流媒体解锁检测"
show_option "4" "update" "系统更新与工具安装"
show_option "5" "realm" "Realm部署工具"
show_option "6" "nezha" "哪吒监控面板"
show_option "7" "xui" "X-UI面板安装"
show_option "8" "toolbasic" "基础工具安装"
show_option "9" "onekey" "V2Ray WSS一键安装"
show_option "10" "backtrace" "回溯工具"
show_option "11" "gg_test" "Google连通性测试"
show_option "12" "key.sh" "SSH密钥管理"
show_option "13" "jiguang" "极光面板安装"
show_option "14" "NetQuality" "网络质量测试"
show_option "15" "armnetwork" "ARM网络配置"
show_option "16" "NodeQuality" "节点质量测试"
show_option "17" "snell" "Snell服务器安装"
show_option "18" "docker" "Docker相关工具"
show_option "19" "caddy" "Caddy服务器安装"
show_option "20" "80443" "清理80/443端口占用"
show_option "21" "caddy-install" "Caddy快速安装"
show_option "22" "remby" "Caddy反向代理配置"
show_option "up" "update-vpsh" "更新VPSH脚本"

draw_line

# 读取用户输入
printf "${CYAN}|${RESET} ${GREEN}请输入序号：${RESET} "
read choice


case $choice in
    0)
        echo "执行t脚本"
        # 这里替换为实际的t脚本命令
        echo "alias t='./vpsh.sh'" >> ~/.bashrc && source ~/.bashrc
        ;;
    1)
        echo "执行kejilion脚本"
        bash <(curl -sL kejilion.sh)
        ;;
    2)
        echo "请选择重装脚本的类型："
        echo "0. 返回上一级菜单"
        echo "1. 国内"
        echo "2. 国外"
        read -p "请输入序号：" sub_choice

        case $sub_choice in
            0)
                # 返回主菜单
                exec $0
                ;;
            1)
                echo "执行国内重装脚本"
                # 这里替换为实际的国内重装脚本命令
                curl -O https://gitlab.com/bin456789/reinstall/-/raw/main/reinstall.sh || wget -O reinstall.sh $_
                ;;
            2)
                echo "执行国外重装脚本"
                # 这里替换为实际的国外重装脚本命令
                curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh || wget -O reinstall.sh $_
                ;;
            *)
                echo "无效的选择，请重新运行脚本并选择正确的序号。"
                exit 1
                ;;
        esac
        ;;
    3)
        echo "执行解锁检测脚本"
        # 这里替换为实际的解锁脚本命令
        bash <(curl -L -s check.unlock.media)
        ;;
    4)
        echo "执行更新脚本"
        # 这里替换为实际的更新脚本命令
        apt update -y&&apt install -y curl&&apt install -y socat
        ;;
    5)
        echo "请选择realm脚本的类型："
        echo "0. 返回上一级菜单"
        echo "1. 国内"
        echo "2. 国外"
        read -p "请输入序号：" sub_choice

        case $sub_choice in
            0)
                # 返回主菜单
                exec $0
                ;;
            1)
                echo "执行国内重装脚本"
                # 这里替换为实际的国内重装脚本命令
                curl -L https://host.wxgwxha.eu.org/https://github.com/wcwq98/realm/releases/download/v2.1/realm.sh -o realm.sh && chmod +x realm.sh &&  ./realm.sh
                ;;
            2)
                echo "执行国外重装脚本"
                # 这里替换为实际的国外重装脚本命令
                curl -L https://github.com/wcwq98/realm/releases/download/v2.1/realm.sh -o realm.sh && chmod +x realm.sh &&  ./realm.sh
                ;;
            *)
                echo "无效的选择，请重新运行脚本并选择正确的序号。"
                exit 1
                ;;
        esac
        ;;
    6)
        echo "请选择nezha脚本的类型："
        echo "0. 返回上一级菜单"
        echo "1. 国内"
        echo "2. 国外"
        read -p "请输入序号：" sub_choice

        case $sub_choice in
            0)
                # 返回主菜单
                exec $0
                ;;
            1)
                echo "执行国内重装脚本"
                # 这里替换为实际的国内重装脚本命令
                curl -L https://host.wxgwxha.eu.org/https://github.com/wcwq98/realm/releases/download/v2.1/realm.sh -o realm.sh && chmod +x realm.sh &&  ./realm.sh
                ;;
            2)
                echo "执行国外重装脚本"
                # 这里替换为实际的国外重装脚本命令
                curl -L https://raw.githubusercontent.com/nezhahq/scripts/refs/heads/main/install.sh -o nezha.sh && chmod +x nezha.sh && sudo ./nezha.sh
                ;;
            *)
                echo "无效的选择，请重新运行脚本并选择正确的序号。"
                exit 1
                ;;
        esac
        ;;
    7)
        echo "请选择xui脚本的类型："
        echo "0. 返回上一级菜单"
        echo "1. 3xui"
        echo "2. 3xui-"
        echo "3. xuiv6"
        read -p "请输入序号：" sub_choice

        case $sub_choice in
            0)
                # 返回主菜单
                exec $0
                ;;
            1)
                echo "执行3xui脚本"
                # 这里替换为实际的国内重装脚本命令
                bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
                ;;
            2)
                echo "执行3xui-脚本"
                # 这里替换为实际的国外重装脚本命令
                VERSION=v2.5.3 && bash <(curl -Ls "https://raw.githubusercontent.com/mhsanaei/3x-ui/$VERSION/install.sh") $VERSION
                ;;
            3)
                echo "执行xuiv6脚本"
                # 这里替换为实际的国外重装脚本命令
                bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/x-ui-yg/main/install.sh)
                ;;
            *)
                echo "无效的选择，请重新运行脚本并选择正确的序号。"
                exit 1
                ;;
        esac
        ;;
    8)
        echo "执行toolbasic脚本"
        # 这里替换为实际的更新脚本命令
        apt install curl wget sudo unzip
        ;;
    9)
        echo "执行onekey脚本"
        # 这里替换为实际的更新脚本命令
        wget https://raw.githubusercontent.com/yeahwu/v2ray-wss/main/tcp-wss.sh && bash tcp-wss.sh
        ;;
    10)
        echo "执行backtrace脚本"
        # 这里替换为实际的更新脚本命令
        curl https://raw.githubusercontent.com/ludashi2020/backtrace/main/install.sh -sSf | sh
        ;;
    11)
        echo "执行gg_test脚本"
        # 这里替换为实际的更新脚本命令
        curl https://scholar.google.com.hk/
        ;;
    12)
        echo "请选择key脚本的类型："
        echo "0. 返回上一级菜单"
        echo "1. 国内"
        echo "2. 国外"
        read -p "请输入序号：" sub_choice

        case $sub_choice in
            0)
                # 返回主菜单
                exec $0
                ;;
            1)
                echo "执行国内key脚本"
                # 这里替换为实际的国内重装脚本命令
                bash <(curl -fsSL https;//gh-proxy.com/git.io/key.sh) -u https://pan.7so.top/f/qQVEhX/id_ecdsa.pub
                ;;
            2)
                echo "执行国外重装脚本"
                # 这里替换为实际的国外重装脚本命令
                bash <(curl -fsSL git.io/key.sh) -og tionmon -p 2017 -d
                ;;
            *)
                echo "无效的选择，请重新运行脚本并选择正确的序号。"
                exit 1
                ;;
        esac
        ;;
    13)
        echo "执行jiguang脚本"
        # 这里替换为实际的更新脚本命令
        bash <(curl -fsSL https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/install.sh)
        ;;
    14)
        echo "执行NetQuality脚本"
        # 这里替换为实际的更新脚本命令
        bash <(curl -Ls Net.Check.Place)
        ;;
    15)
        echo "执行armnetwork脚本"
        # 这里替换为实际的更新脚本命令
        sudo nano /etc/netplan/armbian-default.yaml
        ;;
    16)
        echo "执行NodeQuality脚本"
        # 这里替换为实际的更新脚本命令
        bash <(curl -sL https://run.NodeQuality.com)
        ;;
    17)
        echo "执行snell脚本"
        # 这里替换为实际的更新脚本命令
        wget -q https://raw.githubusercontent.com/passeway/Snell/main/Snell.sh -O Snell.sh && chmod +x Snell.sh && ./Snell.sh
        ;;
    18)
        echo "请选择Docker相关工具："
        echo "0. 返回上一级菜单"
        echo "1. 1ms Docker助手"
        echo "2. 国内Docker安装"
        echo "3. Docker + Docker Compose 一键安装"
        read -p "请输入序号：" sub_choice

        case $sub_choice in
            0)
                # 返回主菜单
                exec $0
                ;;
            1)
                echo "执行1ms Docker助手脚本"
                # 这里替换为实际的更新脚本命令
                curl -s https://static.1ms.run/1ms-helper/scripts/install.sh | bash /dev/stdin config:account
                ;;
            2)
                echo "国内安装Docker"
                # 这里替换为实际的更新脚本命令
                bash <(curl -f -s --connect-timeout 10 --retry 3 https://linuxmirrors.cn/docker.sh) --source mirrors.tencent.com/docker-ce --source-registry docker.1ms.run --protocol https --install-latested true --close-firewall false --ignore-backup-tips
                ;;
            3)
                echo "一键安装 Docker + Docker Compose"
                # 安装Docker
                apt update -y
                sudo curl -sSL get.docker.com | sh
                
                # 安装Docker Compose
                curl -L "https://github.com/docker/compose/releases/download/v2.18.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                chmod +x /usr/local/bin/docker-compose
                
                # 验证安装
                echo "检查Docker和Docker Compose安装状态："
                docker --version
                docker-compose --version
                
                # 启动Docker并设置开机自启
                systemctl start docker
                systemctl enable docker
                
                echo "Docker和Docker Compose安装完成!"
                ;;
            *)
                echo "无效的选择，请重新运行脚本并选择正确的序号。"
                exit 1
                ;;
        esac
        ;;
    19)
        echo "执行Caddy安装脚本"
        # 原有的Caddy安装代码
        set -euo pipefail

        # Ensure the script is run as root
        if [ "$(id -u)" -ne 0 ]; then
          echo "This script must be run as root. Please use sudo or switch to the root user." >&2
          exit 1
        fi

        # Update package lists and install prerequisites
        apt update
        apt install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg

        # Add the Caddy GPG key
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
          | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

        # Add the Caddy repository
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
          | tee /etc/apt/sources.list.d/caddy-stable.list

        # Update package lists and install Caddy
        apt update
        apt install -y caddy

        echo "Caddy installation complete. You can now start and enable the service with:"
        echo "  systemctl enable --now caddy"
        ;;
    20)
        echo "执行80443端口清理脚本"
        # 获取脚本目录
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        # 执行80443.sh脚本
        if [ -f "$SCRIPT_DIR/../sh/80443.sh" ]; then
            bash "$SCRIPT_DIR/../sh/80443.sh"
        else
            echo "80443.sh脚本未找到，正在执行内置清理功能..."
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
        fi
        ;;
    21)
        echo "执行Caddy快速安装脚本"
        # 获取脚本目录
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        # 执行caddy.sh脚本
        if [ -f "$SCRIPT_DIR/../sh/caddy.sh" ]; then
            bash "$SCRIPT_DIR/../sh/caddy.sh"
        else
            echo "caddy.sh脚本未找到，正在执行内置安装功能..."
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
            else
                echo "Caddy 已经安装"
            fi
        fi
        ;;
    22)
        echo "执行Caddy反向代理配置脚本"
        # 获取脚本目录
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        # 执行remby.sh脚本
        if [ -f "$SCRIPT_DIR/../sh/remby.sh" ]; then
            bash "$SCRIPT_DIR/../sh/remby.sh"
        else
            echo "remby.sh脚本未找到，请确保脚本文件存在。"
        fi
        ;;
    up)
        echo "${GREEN}正在更新VPSH脚本...${RESET}"
        # 获取当前脚本路径
        SCRIPT_PATH=$(readlink -f "$0")
        SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
        
        # 备份当前脚本
        cp "$SCRIPT_PATH" "${SCRIPT_PATH}.bak"
        echo "${BLUE}已备份当前脚本到 ${SCRIPT_PATH}.bak${RESET}"
        
        # 拉取最新脚本，添加随机参数防止缓存
        echo "${YELLOW}正在从远程仓库拉取最新脚本...${RESET}"
        RANDOM_PARAM="$(date +%s%N)"
        curl -s -H "Cache-Control: no-cache, no-store" -H "Pragma: no-cache" -o "$SCRIPT_PATH" "https://raw.githubusercontent.com/tionmon/vpsh/main/vpsh.sh?nocache=$RANDOM_PARAM" || \
        wget -q --no-cache --no-cookies --header="Cache-Control: no-cache, no-store" --header="Pragma: no-cache" -O "$SCRIPT_PATH" "https://raw.githubusercontent.com/tionmon/vpsh/main/vpsh.sh?nocache=$RANDOM_PARAM"
        
        # 确保脚本有执行权限
        chmod +x "$SCRIPT_PATH"
        
        echo "${GREEN}VPSH脚本已更新到最新版本!${RESET}"
        echo "${CYAN}重新启动脚本以应用更新...${RESET}"
        
        # 重新执行脚本
        exec "$SCRIPT_PATH"
        ;;
    *)
        echo "无效的选择，请重新运行脚本并选择正确的序号。"
        exit 1
        ;;
esac