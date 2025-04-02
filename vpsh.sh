#!/bin/bash

echo "请选择要执行的脚本："
echo "0. t"
echo "1. kejilion"
echo "2. reinstall"
echo "3. jpso"
echo "4. update"
echo "5. realm"
echo "6. nezha"
echo "7. xui"
echo "8. toolbasic"
echo "9. onekey"
echo "10. backtrace"
echo "11. gg_test"
echo "12. key.sh"
echo "13. jiguang"
echo "14. NetQuality"
echo "15. armnetwork"
echo "16. NodeQuality"




read -p "请输入序号：" choice

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
    *)
        echo "无效的选择，请重新运行脚本并选择正确的序号。"
        exit 1
        ;;
esac
