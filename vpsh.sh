#!/bin/bash

echo "请选择要执行的脚本："
echo "1. kejilion"
echo "2. reinstall"
echo "3. jpso"
echo "4. update"
echo "5. realm"
echo "6. nezha"
echo "7. xui"

read -p "请输入序号：" choice

case $choice in
    1)
        echo "执行科技脚本"
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
                ./chongzhuang_guonei.sh
                ;;
            2)
                echo "执行国外重装脚本"
                # 这里替换为实际的国外重装脚本命令
                ./chongzhuang_guowai.sh
                ;;
            *)
                echo "无效的选择，请重新运行脚本并选择正确的序号。"
                exit 1
                ;;
        esac
        ;;
    3)
        echo "执行解锁脚本"
        # 这里替换为实际的解锁脚本命令
        ./jiesuo.sh
        ;;
    4)
        echo "执行更新脚本"
        # 这里替换为实际的更新脚本命令
        ./gengxin.sh
        ;;
    5)
        echo "请选择重装脚本的类型："
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
        echo "请选择重装脚本的类型："
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
        echo "请选择重装脚本的类型："
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
    *)
        echo "无效的选择，请重新运行脚本并选择正确的序号。"
        exit 1
        ;;
esac
