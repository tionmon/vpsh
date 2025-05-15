#!/bin/bash

# 检测终端是否支持颜色
if [ -t 1 ] && command -v tput > /dev/null && [ $(tput colors) -ge 8 ]; then
    # 定义颜色变量
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
    MAGENTA="$(tput setaf 5)"
    CYAN="$(tput setaf 6)"
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
    
    printf "${CYAN}|${RESET}  ${YELLOW}%-4s${RESET}${WHITE}%-10s${RESET}${MAGENTA}%s${RESET} ${GREEN}%-$(( BORDER_WIDTH - 30 ))s${RESET}${CYAN}|${RESET}\n" "$number." "$description" "$arrow_style" "$short_desc"
}

# 显示标题
draw_line
center_text "VPSH 脚本管理面板" "${MAGENTA}"
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
show_option "18" "msdocker" "1ms Docker助手"
show_option "19" "indocker" "国内Docker安装"

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
        echo "1. 国内"
        echo "2. 国外"
        read -p "请输入序号：" sub_choice

        case $sub_choice in
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
        echo "1. 国内"
        echo "2. 国外"
        read -p "请输入序号：" sub_choice

        case $sub_choice in
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
        echo "1. 国内"
        echo "2. 国外"
        read -p "请输入序号：" sub_choice

        case $sub_choice in
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
        echo "1. 3xui"
        echo "2. 3xui-"
        echo "3. xuiv6"
        read -p "请输入序号：" sub_choice

        case $sub_choice in
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
            2)
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
        echo "1. 国内"
        echo "2. 国外"
        read -p "请输入序号：" sub_choice

        case $sub_choice in
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
        echo "执行msdocker脚本"
        # 这里替换为实际的更新脚本命令
        curl -s https://static.1ms.run/1ms-helper/scripts/install.sh | bash /dev/stdin config:account
        ;;
    19)
        echo "国内安装docker"
        # 这里替换为实际的更新脚本命令
        bash <(curl -f -s --connect-timeout 10 --retry 3 https://linuxmirrors.cn/docker.sh) --source mirrors.tencent.com/docker-ce --source-registry docker.1ms.run --protocol https --install-latested true --close-firewall false --ignore-backup-tips
        ;;
    *)
        echo "无效的选择，请重新运行脚本并选择正确的序号。"
        exit 1
        ;;
esac
