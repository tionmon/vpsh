#!/bin/bash

CONFIG_FILE="/etc/rinetd.conf"
SERVICE_NAME="rinetd"

function install_rinetd() {
    if command -v rinetd &>/dev/null; then
        echo "✅ rinetd 已安装"
        return
    fi

    if [ -f /etc/debian_version ]; then
        apt update && apt install -y rinetd
    elif [ -f /etc/redhat-release ]; then
        yum install -y rinetd
    else
        echo "❌ 不支持的系统"
        exit 1
    fi

    touch "$CONFIG_FILE"
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"
    echo "✅ rinetd 安装完成并已启动"
}

function uninstall_rinetd() {
    systemctl stop "$SERVICE_NAME"
    systemctl disable "$SERVICE_NAME"

    if [ -f /etc/debian_version ]; then
        apt remove -y rinetd
    elif [ -f /etc/redhat-release ]; then
        yum remove -y rinetd
    fi

    rm -f "$CONFIG_FILE"
    echo "✅ rinetd 已卸载并删除配置文件"
}

function list_rules() {
    if ! grep -q "^#ID:" "$CONFIG_FILE" 2>/dev/null; then
        echo "⚠️ 暂无规则。"
        return
    fi
    echo "📜 当前转发规则："
    grep -n "^#ID:" "$CONFIG_FILE" | while read -r line; do
        num=$(echo "$line" | cut -d: -f1)
        id=$(echo "$line" | cut -d':' -f3)
        rule=$(sed -n "$((num+1))p" "$CONFIG_FILE")
        echo "序号 $id: $rule"
    done
}

function add_rules() {
    echo "请输入转发规则（例如：0.0.0.0 1234 127.0.0.1 4321）"
    echo "格式：绑定IP 绑定端口 目标IP 目标端口"
    echo "示例：访问 VPS 的 1234 端口会转发到本地的 4321 端口"
    echo "一行一个规则，输入空行结束："

    id=$(grep "^#ID:" "$CONFIG_FILE" | tail -n 1 | awk -F: '{print $3}')
    [[ -z "$id" ]] && id=0

    while true; do
        read -r line
        [[ -z "$line" ]] && break
        id=$((id+1))
        echo "#ID:$id" >> "$CONFIG_FILE"
        echo "$line" >> "$CONFIG_FILE"
    done

    systemctl restart "$SERVICE_NAME"
    echo "✅ 已添加转发规则"
    list_rules
}


function reorder_ids() {
    tmpfile=$(mktemp)
    id=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^#ID: ]]; then
            id=$((id+1))
            echo "#ID:$id" >> "$tmpfile"
        else
            echo "$line" >> "$tmpfile"
        fi
    done < "$CONFIG_FILE"
    mv "$tmpfile" "$CONFIG_FILE"
}

function delete_rules() {
    echo "请输入要删除的序号（支持单个: 2 或范围: 3-5）："
    read -r input

    if [[ "$input" =~ ^[0-9]+$ ]]; then
        sed -i "/#ID:$input/{N;d}" "$CONFIG_FILE"
    elif [[ "$input" =~ ^[0-9]+-[0-9]+$ ]]; then
        start=$(echo "$input" | cut -d- -f1)
        end=$(echo "$input" | cut -d- -f2)
        for ((i=start; i<=end; i++)); do
            sed -i "/#ID:$i/{N;d}" "$CONFIG_FILE"
        done
    else
        echo "❌ 输入格式错误"
        return
    fi

    reorder_ids
    systemctl restart "$SERVICE_NAME"
    echo "✅ 已删除规则并重排序号"
    list_rules
}

function export_rules() {
    read -rp "请输入导出文件路径（默认 /root/rinetd_rules_backup.conf）: " filepath
    [[ -z "$filepath" ]] && filepath="/root/rinetd_rules_backup.conf"

    cp "$CONFIG_FILE" "$filepath"
    echo "✅ 已导出规则到：$filepath"
}

function import_rules() {
    read -rp "请输入要导入的文件路径: " filepath
    [[ ! -f "$filepath" ]] && echo "❌ 文件不存在" && return

    echo "请选择导入模式："
    echo "1. 覆盖现有规则"
    echo "2. 追加到现有规则"
    read -rp "选择: " mode

    if [ "$mode" == "1" ]; then
        cp "$filepath" "$CONFIG_FILE"
        echo "✅ 已覆盖现有规则"
    elif [ "$mode" == "2" ]; then
        cat "$filepath" >> "$CONFIG_FILE"
        echo "✅ 已追加规则"
    else
        echo "❌ 无效选择"
        return
    fi

    reorder_ids
    systemctl restart "$SERVICE_NAME"
    echo "✅ 导入完成并已重排序号"
    list_rules
}

function menu() {
    echo -e "\n=== rinetd 管理脚本 ==="
    echo "1. 安装 rinetd"
    echo "2. 卸载 rinetd"
    echo "3. 添加转发规则"
    echo "4. 删除转发规则"
    echo "5. 查看转发规则"
    echo "6. 导出规则"
    echo "7. 导入规则"
    echo "0. 退出"
    read -rp "请选择操作: " choice

    case $choice in
        1) install_rinetd ;;
        2) uninstall_rinetd ;;
        3) add_rules ;;
        4) delete_rules ;;
        5) list_rules ;;
        6) export_rules ;;
        7) import_rules ;;
        0) exit 0 ;;
        *) echo "❌ 无效选择" ;;
    esac
}

# 主循环
while true; do
    menu
done
