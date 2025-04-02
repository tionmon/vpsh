#!/bin/bash

echo "请选择要执行的脚本："
echo "1. 科技脚本"
echo "2. 重装脚本"
echo "3. 解锁脚本"
echo "4. 更新脚本"

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
    *)
        echo "无效的选择，请重新运行脚本并选择正确的序号。"
        exit 1
        ;;
esac
