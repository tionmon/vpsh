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

# 解析端口范围
parse_port_range() {
    local port_input="$1"
    local ports=()
    
    # 检查是否为端口范围格式 (如: 1000-1100)
    if [[ "$port_input" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        local start_port="${BASH_REMATCH[1]}"
        local end_port="${BASH_REMATCH[2]}"
        
        # 验证端口范围
        if [ "$start_port" -lt 1 ] || [ "$start_port" -gt 65535 ] || [ "$end_port" -lt 1 ] || [ "$end_port" -gt 65535 ]; then
            echo -e "${RED}端口范围错误: $port_input (应在 1-65535 之间)${RESET}"
            return 1
        fi
        
        if [ "$start_port" -gt "$end_port" ]; then
            echo -e "${RED}端口范围错误: $port_input (起始端口不能大于结束端口)${RESET}"
            return 1
        fi
        
        # 生成端口列表
        for ((port=start_port; port<=end_port; port++)); do
            ports+=("$port")
        done
        
        echo "${ports[@]}"
        return 0
    # 检查是否为单个端口
    elif [[ "$port_input" =~ ^[0-9]+$ ]]; then
        if [ "$port_input" -lt 1 ] || [ "$port_input" -gt 65535 ]; then
            echo -e "${RED}端口范围错误: $port_input (应在 1-65535 之间)${RESET}"
            return 1
        fi
        echo "$port_input"
        return 0
    else
        echo -e "${RED}端口格式错误: $port_input (应为单个端口或端口范围，如: 8080 或 1000-1100)${RESET}"
        return 1
    fi
}

# 解析远程目标格式
parse_remote_target() {
    local remote_input="$1"
    local host=""
    local port_input=""
    
    # 检查是否为IPv6格式 [ipv6]:port
    if [[ "$remote_input" =~ ^\[.*\]:([0-9-]+)$ ]]; then
        # IPv6格式：[ipv6地址]:端口
        host=$(echo "$remote_input" | sed 's/]:.*$/]/')
        port_input="${BASH_REMATCH[1]}"
    # 检查是否为IPv4或域名格式 host:port
    elif [[ "$remote_input" =~ ^([a-zA-Z0-9.-]+):([0-9-]+)$ ]]; then
        # IPv4或域名格式：地址:端口
        host="${BASH_REMATCH[1]}"
        port_input="${BASH_REMATCH[2]}"
    else
        echo -e "${RED}远程目标格式错误: $remote_input${RESET}"
        echo -e "${RED}支持格式: IPv4:端口、域名:端口、[IPv6]:端口${RESET}"
        echo -e "${RED}端口支持范围格式: 1.1.1.1:1000-1100${RESET}"
        return 1
    fi
    
    # 解析端口范围
    local ports_output
    ports_output=$(parse_port_range "$port_input")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # 返回格式: "host|port1 port2 port3 ..."
    echo "$host|$ports_output"
    return 0
}

# 检查端口是否已被占用
check_port_occupied() {
    local port="$1"
    
    # 检查配置文件中是否已存在该端口
    if grep -q "listen = \"0.0.0.0:$port\"" "$CONFIG_FILE" 2>/dev/null; then
        return 0  # 端口已被占用
    fi
    
    # 检查系统中是否有进程在使用该端口
    if command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            return 0  # 端口已被占用
        fi
    elif command -v ss >/dev/null 2>&1; then
        if ss -tuln 2>/dev/null | grep -q ":$port "; then
            return 0  # 端口已被占用
        fi
    fi
    
    return 1  # 端口未被占用
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
    local LOCAL_PORT_INPUT REMOTE_TARGET_INPUT
    
    # 去除前后空格
    rule=$(echo "$rule" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # 跳过空行
    if [ -z "$rule" ]; then
        return 1
    fi
    
    # 解析输入
    LOCAL_PORT_INPUT=$(echo "$rule" | awk '{print $1}')
    REMOTE_TARGET_INPUT=$(echo "$rule" | awk '{print $2}')
    
    # 验证输入格式
    if [ -z "$LOCAL_PORT_INPUT" ] || [ -z "$REMOTE_TARGET_INPUT" ]; then
        echo -e "${RED}格式错误: $rule (应为: 本机端口 远程IP:端口)${RESET}"
        return 1
    fi
    
    # 解析本地端口范围
    local local_ports_output
    local_ports_output=$(parse_port_range "$LOCAL_PORT_INPUT")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # 解析远程目标
    local remote_output
    remote_output=$(parse_remote_target "$REMOTE_TARGET_INPUT")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # 分离主机和端口
    local remote_host=$(echo "$remote_output" | cut -d'|' -f1)
    local remote_ports_output=$(echo "$remote_output" | cut -d'|' -f2)
    
    # 将端口输出转换为数组
    local local_ports=($local_ports_output)
    local remote_ports=($remote_ports_output)
    
    # 检查端口数量是否匹配
    if [ ${#local_ports[@]} -ne ${#remote_ports[@]} ]; then
        echo -e "${RED}端口数量不匹配: 本地端口 ${#local_ports[@]} 个，远程端口 ${#remote_ports[@]} 个${RESET}"
        return 1
    fi
    
    # 检查端口是否已被占用
    local occupied_ports=()
    for local_port in "${local_ports[@]}"; do
        if check_port_occupied "$local_port"; then
            occupied_ports+=("$local_port")
        fi
    done
    
    if [ ${#occupied_ports[@]} -gt 0 ]; then
        echo -e "${RED}以下端口已被占用: ${occupied_ports[*]}${RESET}"
        echo -e "${RED}请选择其他端口或先删除现有规则${RESET}"
        return 1
    fi
    
    local rules_added=0
    
    # 为每个端口对添加规则
    for i in "${!local_ports[@]}"; do
        local local_port="${local_ports[$i]}"
        local remote_port="${remote_ports[$i]}"
        local remote_target="$remote_host:$remote_port"
        
        # 添加规则到配置文件
        cat >> "$CONFIG_FILE" <<EOF

[[endpoints]]
listen = "0.0.0.0:$local_port"
remote = "$remote_target"
type = "tcp+udp"
EOF
        rules_added=$((rules_added + 1))
    done
    
    if [ ${#local_ports[@]} -eq 1 ]; then
        echo -e "${GREEN}已添加规则: $LOCAL_PORT_INPUT -> $REMOTE_TARGET_INPUT${RESET}"
    else
        echo -e "${GREEN}已添加规则: $LOCAL_PORT_INPUT -> $REMOTE_TARGET_INPUT (共 ${#local_ports[@]} 个端口)${RESET}"
    fi
    
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
echo "   1000-1100 1.1.1.1:1000-1100"
echo "3. 逗号分隔: 1234 1.1.1.1:1234,1233 example.com:1233"
echo ""
echo "支持的本地端口格式："
echo "• 单个端口: 8080"
echo "• 端口范围: 1000-1100 (将添加101个端口)"
echo ""
echo "支持的远程目标格式："
echo "• IPv4: 192.168.1.1:8080"
echo "• 域名: example.com:8080"
echo "• IPv6: [2001:db8::1]:8080"
echo "• 端口范围: 1.1.1.1:1000-1100 (与本地端口范围对应)"
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

# 创建临时文件来安全删除规则块
TEMP_CONFIG=$(mktemp)
awk -v start="$START" -v end="$END" '
NR < start || NR >= end { print }
' "$CONFIG_FILE" > "$TEMP_CONFIG"

# 替换原配置文件
mv "$TEMP_CONFIG" "$CONFIG_FILE"

restart_realm
echo -e "${GREEN}规则已删除并重启 Realm。${RESET}"
}

batch_delete_rules() {
echo -e "${GREEN}批量删除转发规则${RESET}"
echo "支持以下输入方式："
echo "1. 单个端口: 8080"
echo "2. 端口范围: 1000-1100 (将删除101个端口)"
echo "3. 多个端口/范围用逗号分隔: 8080,1000-1100,2000"
echo ""
echo "输入 'done' 或空行结束删除"
echo "--------------------"

RULES_DELETED=0
echo "请输入要删除的端口 (支持端口范围):"

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

# 处理缓冲区中的所有端口
if [ -n "$INPUT_BUFFER" ]; then
    # 记录处理前的规则数量
    RULES_BEFORE=$(grep -c '\[\[endpoints\]\]' "$CONFIG_FILE" 2>/dev/null || echo 0)
    RULES_BEFORE=$(echo "$RULES_BEFORE" | tr -d '[:space:]')
    # 确保是数字
    if ! [[ "$RULES_BEFORE" =~ ^[0-9]+$ ]]; then
        RULES_BEFORE=0
    fi
    
    # 创建临时文件来存储分割后的端口
    TEMP_PORTS=$(mktemp)
    echo "$INPUT_BUFFER" | tr ',' '\n' > "$TEMP_PORTS"
    
    # 逐行处理端口
    while IFS= read -r port_input; do
        # 去除前后空格
        port_input=$(echo "$port_input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # 跳过空行
        if [ -z "$port_input" ]; then
            continue
        fi
        
        # 解析端口范围
        local ports_output
        ports_output=$(parse_port_range "$port_input")
        if [ $? -ne 0 ]; then
            continue
        fi
        
        # 将端口输出转换为数组
        local ports=($ports_output)
        
        # 为每个端口删除规则
        for port in "${ports[@]}"; do
            # 使用更简单的方法：直接使用 awk 删除包含指定端口的整个 [[endpoints]] 块
            local temp_config=$(mktemp)
            local deleted=false
            
            # 使用 awk 来删除包含指定端口的整个 [[endpoints]] 块
            awk -v target_port="$port" '
            BEGIN { 
                skip_block = 0
                in_endpoints = 0
            }
            /^\[\[endpoints\]\]$/ { 
                in_endpoints = 1
                skip_block = 0
                next
            }
            in_endpoints && /listen = "0\.0\.0\.0:'$port'"/ { 
                skip_block = 1
                next
            }
            in_endpoints && /^$/ { 
                in_endpoints = 0
                if (skip_block == 0) {
                    print "[[endpoints]]"
                }
                skip_block = 0
                next
            }
            in_endpoints && skip_block == 0 { 
                print "[[endpoints]]"
                print $0
                in_endpoints = 0
                next
            }
            !in_endpoints { 
                print $0
            }
            ' "$CONFIG_FILE" > "$temp_config"
            
            # 检查是否有变化
            if ! cmp -s "$CONFIG_FILE" "$temp_config"; then
                mv "$temp_config" "$CONFIG_FILE"
                RULES_DELETED=$((RULES_DELETED + 1))
                deleted=true
            else
                rm -f "$temp_config"
            fi
            
            if [ "$deleted" = true ]; then
                echo -e "${GREEN}已删除端口 $port 的规则${RESET}"
            else
                echo -e "${RED}未找到端口 $port 的规则${RESET}"
            fi
        done
    done < "$TEMP_PORTS"
    
    # 清理临时文件
    rm -f "$TEMP_PORTS"
    
    # 计算实际删除的规则数量
    RULES_AFTER=$(grep -c '\[\[endpoints\]\]' "$CONFIG_FILE" 2>/dev/null || echo 0)
    RULES_AFTER=$(echo "$RULES_AFTER" | tr -d '[:space:]')
    # 确保是数字
    if ! [[ "$RULES_AFTER" =~ ^[0-9]+$ ]]; then
        RULES_AFTER=0
    fi
    ACTUAL_DELETED=$((RULES_BEFORE - RULES_AFTER))
    
    if [ "$ACTUAL_DELETED" -gt 0 ]; then
        restart_realm
        echo -e "${GREEN}共删除了 $ACTUAL_DELETED 条规则并重启 Realm 服务。${RESET}"
    else
        echo -e "${RED}未删除任何规则。${RESET}"
    fi
else
    echo -e "${RED}未输入任何端口。${RESET}"
fi
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

# 检查 Realm 是否已安装，如果没有则自动安装
if [ ! -f "$REALM_BIN" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}检测到 Realm 未安装，正在自动安装...${RESET}"
    install_realm
    echo ""
fi

while true; do
    echo -e "${GREEN}===== Realm TCP+UDP 转发脚本 =====${RESET}"
    echo "1. 安装 Realm"
    echo "2. 卸载 Realm"
    echo "3. 重启 Realm"
    echo "--------------------"
    echo "4. 添加转发规则"
    echo "5. 批量添加规则 (支持端口范围)"
    echo "6. 删除单条规则"
    echo "7. 批量删除规则 (支持端口范围)"
    echo "8. 删除全部规则"
    echo "9. 查看当前规则"
    echo "10. 查看日志"
    echo "11. 查看配置"
    echo "0. 退出"
    read -p "请选择一个操作 [0-11]: " OPT
    case $OPT in
        1) install_realm ;;
        2) uninstall_realm ;;
        3) restart_realm ;;
        4) add_rule ;;
        5) batch_add_rules ;;
        6) delete_rule ;;
        7) batch_delete_rules ;;
        8) clear_rules ;;
        9) list_rules ;;
        10) view_log ;;
        11) view_config ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项。${RESET}" ;;
    esac
done
}

main_menu
