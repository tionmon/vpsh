#!/bin/bash
CONFIG_FILE="/etc/realm/config.toml"
REALM_BIN="/usr/local/bin/realm"
SERVICE_FILE="/etc/systemd/system/realm.service"
REALM_URL="https://github.com/zhboner/realm/releases/download/v2.9.2/realm-x86_64-unknown-linux-musl.tar.gz"
TMP_DIR="/tmp/realm-install"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

check_root() {
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请以 root 用户运行此脚本。${RESET}"
    exit 1
fi
}

install_realm() {
echo -e "${GREEN}正在安装 Realm TCP+UDP转发脚本...${RESET}"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR" || exit 1
curl -L -o realm.tar.gz "$REALM_URL"
tar -xzf realm.tar.gz
mv realm "$REALM_BIN"
chmod +x "$REALM_BIN"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Realm Proxy
After=network.target

[Service]
ExecStart=$REALM_BIN -c $CONFIG_FILE
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

mkdir -p $(dirname "$CONFIG_FILE")
echo "# 默认配置" > "$CONFIG_FILE"

systemctl daemon-reexec
systemctl enable realm
systemctl restart realm
echo -e "${GREEN}Realm 安装完成。${RESET}"
}

uninstall_realm() {
systemctl stop realm
systemctl disable realm
rm -f "$REALM_BIN" "$SERVICE_FILE" "$CONFIG_FILE"
systemctl daemon-reexec
echo -e "${GREEN}Realm 已卸载。${RESET}"
}

restart_realm() {
systemctl restart realm
echo -e "${GREEN}Realm 已重启。${RESET}"
}

add_rule() {
read -p "请输入监听端口: " LISTEN
read -p "请输入远程目标 IP:PORT: " REMOTE
cat >> "$CONFIG_FILE" <<EOF

[[endpoints]]
listen = "0.0.0.0:$LISTEN"
remote = "$REMOTE"
type = "tcp+udp"
EOF
restart_realm
echo -e "${GREEN}已添加规则并重启 Realm。${RESET}"
}

process_single_rule() {
    local rule="$1"
    local LOCAL_PORT REMOTE_TARGET
    
    # 去除前后空格
    rule=$(echo "$rule" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # 跳过空行
    if [ -z "$rule" ]; then
        return 1
    fi
    
    # 解析输入
    LOCAL_PORT=$(echo "$rule" | awk '{print $1}')
    REMOTE_TARGET=$(echo "$rule" | awk '{print $2}')
    
    # 验证输入格式
    if [[ ! "$LOCAL_PORT" =~ ^[0-9]+$ ]] || [ -z "$REMOTE_TARGET" ]; then
        echo -e "${RED}格式错误: $rule (应为: 本机端口 远程IP:端口)${RESET}"
        return 1
    fi
    
    # 验证端口范围
    if [ "$LOCAL_PORT" -lt 1 ] || [ "$LOCAL_PORT" -gt 65535 ]; then
        echo -e "${RED}端口范围错误: $LOCAL_PORT (应在 1-65535 之间)${RESET}"
        return 1
    fi
    
    # 验证远程目标格式 (支持 IPv4:端口、域名:端口 和 [IPv6]:端口)
    REMOTE_PORT=""
    
    # 检查是否为IPv6格式 [ipv6]:port
    if [[ "$REMOTE_TARGET" =~ ^\[.*\]:[0-9]+$ ]]; then
        # IPv6格式：[ipv6地址]:端口
        REMOTE_PORT=$(echo "$REMOTE_TARGET" | sed 's/.*]://')
    # 检查是否为IPv4或域名格式 host:port
    elif [[ "$REMOTE_TARGET" =~ ^[a-zA-Z0-9.-]+:[0-9]+$ ]]; then
        # IPv4或域名格式：地址:端口
        REMOTE_PORT=$(echo "$REMOTE_TARGET" | cut -d':' -f2)
    else
        echo -e "${RED}远程目标格式错误: $REMOTE_TARGET${RESET}"
        echo -e "${RED}支持格式: IPv4:端口、域名:端口、[IPv6]:端口${RESET}"
        return 1
    fi
    
    # 验证端口号
    if [ "$REMOTE_PORT" -lt 1 ] || [ "$REMOTE_PORT" -gt 65535 ]; then
        echo -e "${RED}远程端口范围错误: $REMOTE_PORT (应在 1-65535 之间)${RESET}"
        return 1
    fi
    
    # 添加规则到配置文件
    cat >> "$CONFIG_FILE" <<EOF

[[endpoints]]
listen = "0.0.0.0:$LOCAL_PORT"
remote = "$REMOTE_TARGET"
type = "tcp+udp"
EOF
    
    echo -e "${GREEN}已添加规则: $LOCAL_PORT -> $REMOTE_TARGET${RESET}"
    return 0
}

batch_add_rules() {
echo -e "${GREEN}批量添加转发规则${RESET}"
echo "支持以下输入方式："
echo "1. 逐行输入: 1234 1.1.1.1:1234"
echo "2. 多行粘贴:"
echo "   1234 1.1.1.1:1234"
echo "   1233 example.com:1233"
echo "   1111 [2001:db8::1]:2222"
echo "3. 逗号分隔: 1234 1.1.1.1:1234,1233 example.com:1233"
echo ""
echo "支持的远程目标格式："
echo "• IPv4: 192.168.1.1:8080"
echo "• 域名: example.com:8080"
echo "• IPv6: [2001:db8::1]:8080"
echo "输入 'done' 或空行结束添加"
echo "--------------------"

RULES_ADDED=0
echo "请输入规则 (支持多行粘贴或逗号分隔):"

# 读取多行输入直到遇到 "done" 或空行
INPUT_BUFFER=""
while true; do
    read -r LINE
    
    # 如果输入为空行或 "done"，处理缓冲区并结束
    if [ -z "$LINE" ] || [ "$LINE" = "done" ]; then
        break
    fi
    
    # 将输入添加到缓冲区
    if [ -z "$INPUT_BUFFER" ]; then
        INPUT_BUFFER="$LINE"
    else
        INPUT_BUFFER="$INPUT_BUFFER"$'\n'"$LINE"
    fi
done

# 处理缓冲区中的所有规则
if [ -n "$INPUT_BUFFER" ]; then
    # 记录处理前的规则数量
    RULES_BEFORE=$(grep -c '\[\[endpoints\]\]' "$CONFIG_FILE" 2>/dev/null || echo 0)
    RULES_BEFORE=$(echo "$RULES_BEFORE" | tr -d '[:space:]')
    # 确保是数字
    if ! [[ "$RULES_BEFORE" =~ ^[0-9]+$ ]]; then
        RULES_BEFORE=0
    fi
    
    # 创建临时文件来存储分割后的规则
    TEMP_RULES=$(mktemp)
    echo "$INPUT_BUFFER" | tr ',' '\n' > "$TEMP_RULES"
    
    # 逐行处理规则
    while IFS= read -r rule; do
        process_single_rule "$rule" && RULES_ADDED=$((RULES_ADDED + 1))
    done < "$TEMP_RULES"
    
    # 清理临时文件
    rm -f "$TEMP_RULES"
    
    # 计算实际添加的规则数量
    RULES_AFTER=$(grep -c '\[\[endpoints\]\]' "$CONFIG_FILE" 2>/dev/null || echo 0)
    RULES_AFTER=$(echo "$RULES_AFTER" | tr -d '[:space:]')
    # 确保是数字
    if ! [[ "$RULES_AFTER" =~ ^[0-9]+$ ]]; then
        RULES_AFTER=0
    fi
    ACTUAL_ADDED=$((RULES_AFTER - RULES_BEFORE))
    
    if [ "$ACTUAL_ADDED" -gt 0 ]; then
        restart_realm
        echo -e "${GREEN}共添加了 $ACTUAL_ADDED 条规则并重启 Realm 服务。${RESET}"
    else
        echo -e "${RED}未添加任何有效规则。${RESET}"
    fi
else
    echo -e "${RED}未输入任何规则。${RESET}"
fi
}

delete_rule() {
RULES=($(grep -n '\[\[endpoints\]\]' "$CONFIG_FILE" | cut -d: -f1))
COUNT=${#RULES[@]}
if [ "$COUNT" -eq 0 ]; then
    echo "${RED}无可删除规则。${RESET}"
    return
fi
echo "当前转发规则："
for ((i=0; i<COUNT; i++)); do
    START=${RULES[$i]}
    END=${RULES[$((i+1))]:-99999}
    BLOCK=$(sed -n "$START,$((END-1))p" "$CONFIG_FILE")
    echo -e "$((i+1)). $(echo "$BLOCK" | grep listen | cut -d'"' -f2) -> $(echo "$BLOCK" | grep remote | cut -d'"' -f2)"
done
read -p "请输入要删除的规则编号: " IDX
IDX=$((IDX-1))
if [ "$IDX" -lt 0 ] || [ "$IDX" -ge "$COUNT" ]; then
    echo "${RED}编号无效。${RESET}"
    return
fi
START=${RULES[$IDX]}
END=${RULES[$((IDX+1))]:-99999}
sed -i "$START,$((END-1))d" "$CONFIG_FILE"
restart_realm
echo -e "${GREEN}规则已删除并重启 Realm。${RESET}"
}

clear_rules() {
sed -i '/\[\[endpoints\]\]/,/^$/d' "$CONFIG_FILE"
restart_realm
echo -e "${GREEN}已清空所有规则并重启 Realm。${RESET}"
}

list_rules() {
echo "${GREEN}当前转发规则：${RESET}"
grep -A3 '\[\[endpoints\]\]' "$CONFIG_FILE" | sed '/^--$/d'
}

view_log() {
journalctl -u realm --no-pager --since "1 hour ago"
}

view_config() {
cat "$CONFIG_FILE"
}

main_menu() {
check_root
while true; do
    echo -e "${GREEN}===== Realm TCP+UDP 转发脚本 =====${RESET}"
    echo "1. 安装 Realm"
    echo "2. 卸载 Realm"
    echo "3. 重启 Realm"
    echo "--------------------"
    echo "4. 添加转发规则"
    echo "5. 批量添加规则"
    echo "6. 删除单条规则"
    echo "7. 删除全部规则"
    echo "8. 查看当前规则"
    echo "9. 查看日志"
    echo "10. 查看配置"
    echo "0. 退出"
    read -p "请选择一个操作 [0-10]: " OPT
    case $OPT in
        1) install_realm ;;
        2) uninstall_realm ;;
        3) restart_realm ;;
        4) add_rule ;;
        5) batch_add_rules ;;
        6) delete_rule ;;
        7) clear_rules ;;
        8) list_rules ;;
        9) view_log ;;
        10) view_config ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项。${RESET}" ;;
    esac
done
}

main_menu
