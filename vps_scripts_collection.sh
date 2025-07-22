#!/bin/bash

# VPS脚本合集 - 基于【合集】常用VPS脚本.md
# 作者: VPS脚本合集
# 版本: 1.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 清屏函数
clear_screen() {
    clear
}

# 显示标题
show_header() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}           VPS脚本合集 - 一键运行工具${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

# 暂停函数
pause() {
    echo ""
    echo -e "${YELLOW}按任意键继续...${NC}"
    read -n 1 -s
}

# 确认执行函数
confirm_execution() {
    local script_name="$1"
    echo -e "${YELLOW}即将执行: ${script_name}${NC}"
    echo -e "${CYAN}提示: 默认选择为执行(Y)，直接按回车即可执行${NC}"
    echo -e "${RED}请确认是否继续执行? (Y/n): ${NC}"
    read -r confirm
    # 默认为Y，如果用户输入n或N则取消执行
    if [[ $confirm =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}已取消执行${NC}"
        return 1
    else
        return 0
    fi
}

# 执行脚本函数
execute_script() {
    local script="$1"
    local name="$2"
    
    if confirm_execution "$name"; then
        echo -e "${GREEN}正在执行: $name${NC}"
        echo -e "${CYAN}命令: $script${NC}"
        echo ""
        eval "$script"
        echo ""
        echo -e "${GREEN}执行完成!${NC}"
    fi
    pause
}

# DD重装脚本菜单
dd_reinstall_menu() {
    while true; do
        clear_screen
        show_header
        echo -e "${PURPLE}1. DD重装脚本${NC}"
        echo ""
        echo "1) 史上最强脚本 (Debian 12)"
        echo "2) 萌咖大佬的脚本 (Debian 11)"
        echo "3) beta.gs大佬的脚本"
        echo "4) DD Windows 10"
        echo "0) 返回主菜单"
        echo ""
        echo -e "${YELLOW}请选择要执行的脚本 [0-4]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                execute_script "wget --no-check-certificate -qO InstallNET.sh 'https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh' && chmod a+x InstallNET.sh && bash InstallNET.sh -debian 12 -pwd 'password'" "史上最强DD脚本 (Debian 12)"
                ;;
            2)
                echo -e "${YELLOW}注意: 请手动修改密码和端口参数${NC}"
                execute_script "bash <(wget --no-check-certificate -qO- 'https://raw.githubusercontent.com/MoeClub/Note/master/InstallNET.sh') -d 11 -v 64 -p 密码 -port 端口 -a -firmware" "萌咖大佬的DD脚本"
                ;;
            3)
                execute_script "wget --no-check-certificate -O NewReinstall.sh https://raw.githubusercontent.com/fcurrk/reinstall/master/NewReinstall.sh && chmod a+x NewReinstall.sh && bash NewReinstall.sh" "beta.gs大佬的DD脚本"
                ;;
            4)
                echo -e "${YELLOW}默认账户: Administrator, 密码: Teddysun.com${NC}"
                execute_script "bash <(curl -sSL https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh) -windows 10 -lang 'cn'" "DD Windows 10"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                pause
                ;;
        esac
    done
}

# 综合测试脚本菜单
comprehensive_test_menu() {
    while true; do
        clear_screen
        show_header
        echo -e "${PURPLE}2. 综合测试脚本${NC}"
        echo ""
        echo "1) bench.sh"
        echo "2) LemonBench"
        echo "3) 融合怪"
        echo "4) NodeBench"
        echo "0) 返回主菜单"
        echo ""
        echo -e "${YELLOW}请选择要执行的脚本 [0-4]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                execute_script "wget -qO- bench.sh | bash" "bench.sh 综合测试"
                ;;
            2)
                execute_script "wget -qO- https://raw.githubusercontent.com/LemonBench/LemonBench/main/LemonBench.sh | bash -s -- --fast" "LemonBench 快速测试"
                ;;
            3)
                execute_script "bash <(wget -qO- --no-check-certificate https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh)" "融合怪测试"
                ;;
            4)
                execute_script "bash <(curl -sL https://raw.githubusercontent.com/LloydAsp/NodeBench/main/NodeBench.sh)" "NodeBench 测试"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                pause
                ;;
        esac
    done
}

# 性能测试菜单
performance_test_menu() {
    while true; do
        clear_screen
        show_header
        echo -e "${PURPLE}3. 性能测试${NC}"
        echo ""
        echo "1) YABS 完整测试"
        echo "2) YABS 跳过网络测试"
        echo "3) YABS 跳过网络和磁盘测试"
        echo "4) YABS GB5测试"
        echo "0) 返回主菜单"
        echo ""
        echo -e "${YELLOW}请选择要执行的脚本 [0-4]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                execute_script "curl -sL yabs.sh | bash" "YABS 完整性能测试"
                ;;
            2)
                execute_script "curl -sL yabs.sh | bash -s -- -n" "YABS 跳过网络测试"
                ;;
            3)
                execute_script "curl -sL yabs.sh | bash -s -- -n -d" "YABS 跳过网络和磁盘测试"
                ;;
            4)
                execute_script "curl -sL yabs.sh | bash -s -- -5" "YABS GB5测试"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                pause
                ;;
        esac
    done
}

# 流媒体及IP质量测试菜单
streaming_ip_test_menu() {
    while true; do
        clear_screen
        show_header
        echo -e "${PURPLE}4. 流媒体及IP质量测试${NC}"
        echo ""
        echo "1) 流媒体解锁检测 (常用版本)"
        echo "2) 原生检测脚本"
        echo "3) 流媒体解锁检测 (准确度最高)"
        echo "4) IP质量体检脚本"
        echo "5) 一键修改解锁DNS"
        echo "0) 返回主菜单"
        echo ""
        echo -e "${YELLOW}请选择要执行的脚本 [0-5]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                execute_script "bash <(curl -L -s check.unlock.media)" "流媒体解锁检测 (常用版本)"
                ;;
            2)
                execute_script "bash <(curl -sL Media.Check.Place)" "原生流媒体检测"
                ;;
            3)
                execute_script "bash <(curl -L -s https://github.com/1-stream/RegionRestrictionCheck/raw/main/check.sh)" "流媒体解锁检测 (准确度最高)"
                ;;
            4)
                execute_script "bash <(curl -sL IP.Check.Place)" "IP质量体检脚本"
                ;;
            5)
                execute_script "wget https://raw.githubusercontent.com/Jimmyzxk/DNS-Alice-Unlock/refs/heads/main/dns-unlock.sh && bash dns-unlock.sh" "一键修改解锁DNS"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                pause
                ;;
        esac
    done
}

# 测速脚本菜单
speed_test_menu() {
    while true; do
        clear_screen
        show_header
        echo -e "${PURPLE}5. 测速脚本${NC}"
        echo ""
        echo "1) Speedtest"
        echo "2) Taier"
        echo "3) Hyperspeed"
        echo "4) 全球测速"
        echo "5) 区域速度测试"
        echo "6) Ping和路由测试"
        echo "0) 返回主菜单"
        echo ""
        echo -e "${YELLOW}请选择要执行的脚本 [0-6]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                execute_script "bash <(curl -sL bash.icu/speedtest)" "Speedtest 测速"
                ;;
            2)
                execute_script "bash <(curl -sL res.yserver.ink/taier.sh)" "Taier 测速"
                ;;
            3)
                execute_script "bash <(curl -Lso- https://bench.im/hyperspeed)" "Hyperspeed 测速"
                ;;
            4)
                execute_script "wget -qO- nws.sh | bash" "全球测速"
                ;;
            5)
                echo -e "${YELLOW}请手动指定区域参数${NC}"
                execute_script "wget -qO- nws.sh | bash -s" "区域速度测试"
                ;;
            6)
                echo -e "${YELLOW}请手动指定区域参数 [region]${NC}"
                execute_script "wget -qO- nws.sh | bash -s -- -rt" "Ping和路由测试"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                pause
                ;;
        esac
    done
}

# 回程测试菜单
backtrace_test_menu() {
    while true; do
        clear_screen
        show_header
        echo -e "${PURPLE}6. 回程测试${NC}"
        echo ""
        echo "1) 直接显示回程 (小白推荐)"
        echo "2) 回程详细测试 (推荐)"
        echo "3) 回程测试 (备用)"
        echo "0) 返回主菜单"
        echo ""
        echo -e "${YELLOW}请选择要执行的脚本 [0-3]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                execute_script "curl https://raw.githubusercontent.com/ludashi2020/backtrace/main/install.sh -sSf | sh" "直接显示回程测试"
                ;;
            2)
                execute_script "wget -N --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh && chmod +x AutoTrace.sh && bash AutoTrace.sh" "回程详细测试"
                ;;
            3)
                execute_script "wget https://ghproxy.com/https://raw.githubusercontent.com/vpsxb/testrace/main/testrace.sh -O testrace.sh && bash testrace.sh" "回程测试 (备用)"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                pause
                ;;
        esac
    done
}

# 功能脚本菜单
function_scripts_menu() {
    while true; do
        clear_screen
        show_header
        echo -e "${PURPLE}7. 功能脚本${NC}"
        echo ""
        echo "1) 添加SWAP"
        echo "2) 安装Fail2ban"
        echo "3) 一键开启BBR"
        echo "4) 多功能BBR安装脚本"
        echo "5) 锐速/BBRPLUS/BBR2/BBR3"
        echo "6) TCP窗口调优"
        echo "7) 添加WARP"
        echo "8) 25端口开放测试"
        echo "0) 返回主菜单"
        echo ""
        echo -e "${YELLOW}请选择要执行的脚本 [0-8]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                execute_script "wget https://www.moerats.com/usr/shell/swap.sh && bash swap.sh" "添加SWAP"
                ;;
            2)
                execute_script "wget --no-check-certificate https://raw.githubusercontent.com/FunctionClub/Fail2ban/master/fail2ban.sh && bash fail2ban.sh 2>&1 | tee fail2ban.log" "安装Fail2ban"
                ;;
            3)
                execute_script 'echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf && echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf && sysctl -p && sysctl net.ipv4.tcp_available_congestion_control && lsmod | grep bbr' "一键开启BBR"
                ;;
            4)
                execute_script 'wget -N --no-check-certificate "https://gist.github.com/zeruns/a0ec603f20d1b86de6a774a8ba27588f/raw/4f9957ae23f5efb2bb7c57a198ae2cffebfb1c56/tcp.sh" && chmod +x tcp.sh && ./tcp.sh' "多功能BBR安装脚本"
                ;;
            5)
                execute_script 'wget -O tcpx.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcpx.sh" && chmod +x tcpx.sh && ./tcpx.sh' "锐速/BBRPLUS/BBR2/BBR3"
                ;;
            6)
                execute_script "wget http://sh.nekoneko.cloud/tools.sh -O tools.sh && bash tools.sh" "TCP窗口调优"
                ;;
            7)
                echo -e "${YELLOW}请手动指定参数 [option] [lisence/url/token]${NC}"
                execute_script "wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh" "添加WARP"
                ;;
            8)
                execute_script "telnet smtp.aol.com 25" "25端口开放测试"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                pause
                ;;
        esac
    done
}

# 一键安装环境及软件菜单
install_software_menu() {
    while true; do
        clear_screen
        show_header
        echo -e "${PURPLE}8. 一键安装常用环境及软件${NC}"
        echo ""
        echo "1) 安装Docker"
        echo "2) 安装Python"
        echo "3) 安装iperf3"
        echo "4) 安装realm"
        echo "5) 安装gost"
        echo "6) 安装极光面板"
        echo "7) 安装哪吒监控"
        echo "8) 安装WARP"
        echo "9) 安装Aria2"
        echo "10) 安装宝塔面板"
        echo "11) 安装PVE虚拟化"
        echo "12) 安装Argox"
        echo "0) 返回主菜单"
        echo ""
        echo -e "${YELLOW}请选择要执行的脚本 [0-12]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                echo -e "${YELLOW}注意: Docker安装脚本URL不完整，请手动补充${NC}"
                execute_script "bash <(curl -sL 'https://get.docker.com')" "安装Docker"
                ;;
            2)
                execute_script "curl -O https://raw.githubusercontent.com/lx969788249/lxspacepy/master/pyinstall.sh && chmod +x pyinstall.sh && ./pyinstall.sh" "安装Python"
                ;;
            3)
                execute_script "apt install iperf3" "安装iperf3"
                ;;
            4)
                execute_script "bash <(curl -L https://raw.githubusercontent.com/zhouh047/realm-oneclick-install/main/realm.sh) -i" "安装realm"
                ;;
            5)
                execute_script "wget --no-check-certificate -O gost.sh https://raw.githubusercontent.com/qqrrooty/EZgost/main/gost.sh && chmod +x gost.sh && ./gost.sh" "安装gost"
                ;;
            6)
                execute_script "bash <(curl -fsSL https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/install.sh)" "安装极光面板"
                ;;
            7)
                execute_script "curl -L https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -o nezha.sh && chmod +x nezha.sh && sudo ./nezha.sh" "安装哪吒监控"
                ;;
            8)
                execute_script "wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh" "安装WARP"
                ;;
            9)
                execute_script "wget -N git.io/aria2.sh && chmod +x aria2.sh && ./aria2.sh" "安装Aria2"
                ;;
            10)
                execute_script "wget -O install.sh http://v7.hostcli.com/install/install-ubuntu_6.0.sh && sudo bash install.sh" "安装宝塔面板"
                ;;
            11)
                execute_script "bash <(wget -qO- --no-check-certificate https://raw.githubusercontent.com/oneclickvirt/pve/main/scripts/build_backend.sh)" "安装PVE虚拟化"
                ;;
            12)
                execute_script "bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/argox/main/argox.sh)" "安装Argox"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                pause
                ;;
        esac
    done
}

# 综合功能脚本菜单
comprehensive_function_menu() {
    while true; do
        clear_screen
        show_header
        echo -e "${PURPLE}9. 综合功能脚本${NC}"
        echo ""
        echo "1) 科技lion"
        echo "2) SKY-BOX"
        echo "0) 返回主菜单"
        echo ""
        echo -e "${YELLOW}请选择要执行的脚本 [0-2]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                execute_script "apt update -y && apt install -y curl && bash <(curl -sL kejilion.sh)" "科技lion 综合脚本"
                ;;
            2)
                execute_script "wget -O box.sh https://raw.githubusercontent.com/BlueSkyXN/SKY-BOX/main/box.sh && chmod +x box.sh && clear && ./box.sh" "SKY-BOX 综合脚本"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                pause
                ;;
        esac
    done
}

# 主菜单
main_menu() {
    while true; do
        clear_screen
        show_header
        echo -e "${GREEN}请选择要使用的脚本类别:${NC}"
        echo ""
        echo "1) DD重装脚本"
        echo "2) 综合测试脚本"
        echo "3) 性能测试"
        echo "4) 流媒体及IP质量测试"
        echo "5) 测速脚本"
        echo "6) 回程测试"
        echo "7) 功能脚本"
        echo "8) 一键安装常用环境及软件"
        echo "9) 综合功能脚本"
        echo "0) 退出"
        echo ""
        echo -e "${YELLOW}请输入选择 [0-9]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                dd_reinstall_menu
                ;;
            2)
                comprehensive_test_menu
                ;;
            3)
                performance_test_menu
                ;;
            4)
                streaming_ip_test_menu
                ;;
            5)
                speed_test_menu
                ;;
            6)
                backtrace_test_menu
                ;;
            7)
                function_scripts_menu
                ;;
            8)
                install_software_menu
                ;;
            9)
                comprehensive_function_menu
                ;;
            0)
                echo -e "${GREEN}感谢使用VPS脚本合集!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                pause
                ;;
        esac
    done
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}警告: 建议使用root权限运行此脚本${NC}"
        echo -e "${YELLOW}某些功能可能需要管理员权限${NC}"
        echo ""
    fi
}

# 主程序入口
main() {
    check_root
    main_menu
}

# 运行主程序
main "$@"