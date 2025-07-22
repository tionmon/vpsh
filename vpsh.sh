#!/bin/bash

# 检测终端是否支持颜色
if [ -t 1 ] && command -v tput > /dev/null && [ $(tput colors) -ge 8 ]; then
    # 现代化颜色配置 - 更好的视觉层次和对比度
    RED="$(tput setaf 196)$(tput bold)"        # 鲜艳红色
    GREEN="$(tput setaf 46)$(tput bold)"       # 现代绿色
    YELLOW="$(tput setaf 226)$(tput bold)"     # 明亮黄色
    BLUE="$(tput setaf 39)$(tput bold)"        # 现代蓝色
    MAGENTA="$(tput setaf 201)$(tput bold)"    # 紫红色
    CYAN="$(tput setaf 51)$(tput bold)"        # 青色
    WHITE="$(tput setaf 15)$(tput bold)"       # 纯白色
    ORANGE="$(tput setaf 208)$(tput bold)"     # 橙色
    PURPLE="$(tput setaf 135)$(tput bold)"     # 紫色
    GRAY="$(tput setaf 244)"                   # 灰色
    BOLD="$(tput bold)"
    DIM="$(tput dim)"
    UNDERLINE="$(tput smul)"
    RESET="$(tput sgr0)"
else
    # 如果不支持颜色，则使用空字符串
    RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" WHITE="" ORANGE="" PURPLE="" GRAY="" BOLD="" DIM="" UNDERLINE="" RESET=""
fi

# 清屏并初始化
clear
printf "\033[?25l"  # 隐藏光标

# 获取终端宽度
TERM_WIDTH=$(tput cols)

# 如果终端宽度未知或太小，设置一个默认值
if [ -z "$TERM_WIDTH" ] || [ "$TERM_WIDTH" -lt 80 ]; then
    TERM_WIDTH=80
fi

# 计算边框宽度
BORDER_WIDTH=$(( TERM_WIDTH - 4 ))
CONTENT_WIDTH=$(( BORDER_WIDTH - 4 ))

# 现代化边框函数
draw_top_border() {
    printf "${CYAN}╭"$(printf "─%.0s" $(seq 1 $BORDER_WIDTH))"╮${RESET}\n"
}

draw_bottom_border() {
    printf "${CYAN}╰"$(printf "─%.0s" $(seq 1 $BORDER_WIDTH))"╯${RESET}\n"
}

draw_separator() {
    printf "${CYAN}├"$(printf "─%.0s" $(seq 1 $BORDER_WIDTH))"┤${RESET}\n"
}

draw_thin_separator() {
    printf "${CYAN}│${GRAY}"$(printf "┄%.0s" $(seq 1 $BORDER_WIDTH))"${CYAN}│${RESET}\n"
}

# 现代化居中文本函数
center_text() {
    local text="$1"
    local color="$2"
    local icon="$3"
    local text_length=${#text}
    local icon_length=${#icon}
    local total_length=$(( text_length + icon_length + 1 ))
    local padding=$(( (BORDER_WIDTH - total_length) / 2 ))
    local right_padding=$(( BORDER_WIDTH - total_length - padding ))
    
    if [ -n "$icon" ]; then
        printf "${CYAN}│${RESET}%${padding}s${color}${icon} ${BOLD}%s${RESET}%${right_padding}s${CYAN}│${RESET}\n" "" "$text" ""
    else
        local padding=$(( (BORDER_WIDTH - text_length) / 2 ))
        local right_padding=$(( BORDER_WIDTH - text_length - padding ))
        printf "${CYAN}│${RESET}%${padding}s${color}${BOLD}%s${RESET}%${right_padding}s${CYAN}│${RESET}\n" "" "$text" ""
    fi
}

# 创建空行函数
draw_empty_line() {
    printf "${CYAN}│${RESET}%${BORDER_WIDTH}s${CYAN}│${RESET}\n" ""
}

show_option() {
    local number="$1"
    local description="$2"
    local short_desc="$3"
    
    # 格式化序号，确保对齐
    local formatted_number
    if [ "$number" = "up" ]; then
        formatted_number="${ORANGE}[UP]${RESET}"
    else
        formatted_number="${YELLOW}[$(printf "%2s" "$number")]${RESET}"
    fi
    
    # 精确计算宽度以确保对齐
    local desc_width=20
    local separator_width=3
    local remaining_width=$(( BORDER_WIDTH - desc_width - separator_width - 8 ))
    
    printf "${CYAN}│${RESET} ${formatted_number} ${GREEN}%-${desc_width}s${RESET} ${GRAY}│${RESET} ${WHITE}%-${remaining_width}s${RESET} ${CYAN}│${RESET}\n" "$description" "$short_desc"
}



# 显示现代化标题
draw_top_border
draw_empty_line
center_text "VPSH 脚本管理面板 v0.0.2" "${MAGENTA}" "🚀"
draw_empty_line
draw_separator

# 显示选项
printf "${CYAN}│${GREEN}${BOLD} 请选择要执行的脚本：${RESET}%$(( BORDER_WIDTH - 24 ))s${CYAN}│${RESET}\n" ""
draw_thin_separator

show_option "1" "kejilion" "科技lion一键脚本"
show_option "2" "reinstall" "系统重装工具"
show_option "3" "jpso" "流媒体解锁检测"
show_option "4" "update" "系统更新与基础工具安装"
show_option "5" "realm" "Realm部署工具"
show_option "6" "nezha" "哪吒监控面板"
show_option "7" "xui" "X-UI面板安装"
show_option "8" "onekey" "V2Ray WSS一键安装"
show_option "9" "backtrace" "回溯工具"
show_option "10" "gg_test" "Google连通性测试"
show_option "11" "jiguang" "极光面板安装"
show_option "12" "armnetwork" "ARM网络配置"
show_option "13" "NodeQuality" "节点质量测试"
show_option "14" "snell" "Snell服务器安装"
show_option "15" "docker" "Docker相关工具"
show_option "16" "caddy" "Caddy服务器安装"
show_option "17" "80443" "清理80/443端口占用"
show_option "18" "remby" "Caddy反向代理配置"
show_option "19" "in" "环境初始化脚本"
show_option "up" "update-vpsh" "更新VPSH脚本"

draw_bottom_border

# 现代化用户输入界面
echo
printf "${CYAN}╭─────────────────────────────────────────────────────────────────────────────╮${RESET}\n"
printf "${CYAN}│${RESET} ${BLUE}💡 ${WHITE}${BOLD}使用说明：${RESET}${GRAY}输入对应序号选择功能，输入 'q' 或 'exit' 退出${RESET}%8s${CYAN}│${RESET}\n" ""
printf "${CYAN}╰─────────────────────────────────────────────────────────────────────────────╯${RESET}\n"
echo
printf "${GREEN}${BOLD}➤ 请输入您的选择: ${RESET}"
printf "\033[?25h"  # 显示光标
read choice
printf "\033[?25l"  # 隐藏光标
echo


# 处理退出命令
if [[ "$choice" == "q" || "$choice" == "exit" || "$choice" == "quit" ]]; then
    printf "\033[?25h"  # 显示光标
    echo
    printf "${GREEN}${BOLD}👋 感谢使用 VPSH 脚本管理面板！${RESET}\n"
    echo
    exit 0
fi

# 显示执行状态
echo
printf "${CYAN}╭─ 执行状态 ─────────────────────────────────────────────────────────────────╮${RESET}\n"
printf "${CYAN}│${RESET} ${YELLOW}⚡ 正在执行选项 [${choice}]...${RESET}%46s${CYAN}│${RESET}\n" ""
printf "${CYAN}╰─────────────────────────────────────────────────────────────────────────────╯${RESET}\n"
echo

case $choice in
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
                curl -O https://gitlab.com/bin456789/reinstall/-/raw/main/reinstall.sh || wget -O reinstall.sh $_
                echo "下载完成，请运行: bash reinstall.sh debian 12 安装 debian 12"
                ;;
            2)
                echo "执行国外重装脚本"
                curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh || wget -O reinstall.sh $_
                echo "下载完成，请运行: bash reinstall.sh debian 12 安装 debian 12"
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
        bash <(curl -L -s media.ispvps.com)
        ;;
    4)
        echo "执行系统更新与基础工具安装"
        apt update -y && apt install -y curl wget sudo unzip socat
        echo "系统更新和基础工具安装完成"
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
                echo "执行国内realm脚本"
                wget -N https://raw.githubusercontent.com/shiyi11yi/EZRealm/main/CN/realm.sh && chmod +x realm.sh && ./realm.sh
                ;;
            2)
                echo "执行国外realm脚本"
                wget -N https://raw.githubusercontent.com/shiyi11yi/EZRealm/main/CN/realm.sh && chmod +x realm.sh && ./realm.sh
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
        echo "执行onekey脚本"
        wget https://raw.githubusercontent.com/yeahwu/v2ray-wss/main/tcp-wss.sh && bash tcp-wss.sh
        ;;
    9)
        echo "执行backtrace脚本"
        curl https://raw.githubusercontent.com/ludashi2020/backtrace/main/install.sh -sSf | sh
        ;;
    10)
        echo "执行gg_test脚本"
        curl https://scholar.google.com.hk/
        ;;

    11)
        echo "执行jiguang脚本"
        bash <(curl -fsSL https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/install.sh)
        ;;

    12)
        echo "执行armnetwork脚本"
        sudo nano /etc/netplan/armbian-default.yaml
        ;;
    13)
        echo "执行NodeQuality脚本"
        bash <(curl -sL https://run.NodeQuality.com)
        ;;
    14)
        echo "执行snell脚本"
        wget -q https://raw.githubusercontent.com/passeway/Snell/main/Snell.sh -O Snell.sh && chmod +x Snell.sh && ./Snell.sh
        ;;
    15)
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
                
                # 启动Docker并设置开机自启
                systemctl start docker
                systemctl enable docker
                
                echo "Docker 安装完成!"
                ;;
            *)
                echo "无效的选择，请重新运行脚本并选择正确的序号。"
                exit 1
                ;;
        esac
        ;;
    16)
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
    17)
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
    19)
        echo "执行环境初始化脚本"
        # 获取脚本目录
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        # 执行in.sh脚本
        if [ -f "$SCRIPT_DIR/in/in.sh" ]; then
            bash "$SCRIPT_DIR/in/in.sh"
        else
            echo "in.sh脚本未找到，正在执行内置初始化功能..."
            # 删除 /etc/apt/sources.list 文件中的所有内容并添加新的源
            echo "删除 /etc/apt/sources.list 文件中的所有内容并添加新的源"
            echo "deb http://mirrors.aliyun.com/debian/ stable main contrib non-free non-free-firmware" | tee /etc/apt/sources.list > /dev/null
            
            # 安装必要的软件包
            echo "安装 curl, wget, sudo 和 unzip..."
            apt update
            apt install -y curl wget sudo unzip
            
            # 设置Docker镜像源
            if [ ! -d "/etc/docker" ]; then
                mkdir -p /etc/docker
            fi
            echo '{"registry-mirrors": ["https://docker.1ms.run","https://docker.ketches.cn","https://docker.1panel.top"]}' > /etc/docker/daemon.json
            
            echo "环境初始化完成！"
        fi
        ;;

    18)
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
        echo "更新VPSH脚本"
        curl -o vpsh.sh https://raw.githubusercontent.com/tionmon/vpsh/main/vpsh.sh && chmod +x vpsh.sh
        echo "VPSH脚本已更新到最新版本"
        ;;
    *)
        echo
        printf "${RED}╭─ 错误信息 ─────────────────────────────────────────────────────────────────╮${RESET}\n"
        printf "${RED}│${RESET} ${RED}❌ 无效的选择: [${choice}]${RESET}%54s${RED}│${RESET}\n" ""
        printf "${RED}│${RESET} ${YELLOW}💡 请输入有效的序号 (0-19, up) 或 'q' 退出${RESET}%32s${RED}│${RESET}\n" ""
        printf "${RED}╰─────────────────────────────────────────────────────────────────────────────╯${RESET}\n"
        echo
        printf "${GRAY}按任意键返回主菜单...${RESET}"
        read -n 1
        printf "\033[?25h"  # 显示光标
        exec "$0"  # 重新运行脚本
        ;;
esac

# 脚本执行完成后的处理
echo
printf "${GREEN}╭─ 执行完成 ─────────────────────────────────────────────────────────────────╮${RESET}\n"
printf "${GREEN}│${RESET} ${GREEN}✅ 操作已完成！${RESET}%60s${GREEN}│${RESET}\n" ""
printf "${GREEN}╰─────────────────────────────────────────────────────────────────────────────╯${RESET}\n"
echo
printf "${CYAN}${BOLD}是否返回主菜单？ [Y/n]: ${RESET}"
printf "\033[?25h"  # 显示光标
read -n 1 return_choice
printf "\033[?25l"  # 隐藏光标
echo

if [[ "$return_choice" != "n" && "$return_choice" != "N" ]]; then
    exec "$0"  # 重新运行脚本
else
    echo
    printf "${GREEN}${BOLD}👋 感谢使用 VPSH 脚本管理面板！${RESET}\n"
    printf "\033[?25h"  # 显示光标
    echo
fi