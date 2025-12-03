#!/bin/bash

# iptables 端口转发管理脚本
# 功能：端口转发、流量控制、规则管理

set -euo pipefail

# 颜色定义
declare -r RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'

# 配置路径
declare -r CONFIG_DIR="/etc/iptables-forward"
declare -r RULES_FILE="${CONFIG_DIR}/rules.conf"
declare -r CONFIG_FILE="${CONFIG_DIR}/config.conf"

# 默认流量控制配置
declare IPV4_IN="allow" IPV4_OUT="allow" IPV6_IN="allow" IPV6_OUT="allow"

# 输出函数
msg()  { echo -e "${1}${*:2}${NC}"; }
info() { msg "$BLUE" "$@"; }
ok()   { msg "$GREEN" "✔ $*"; }
warn() { msg "$YELLOW" "$@"; }
err()  { msg "$RED" "$@"; }

die() { err "$@"; exit 1; }

# 检查 root 权限
check_root() { [[ $EUID -eq 0 ]] || die "错误：必须以 root 权限运行"; }

# 检测系统类型
detect_system() {
    if [[ -f /etc/redhat-release ]] || grep -Eqi "centos|red hat|redhat" /etc/issue /proc/version 2>/dev/null; then
        echo "centos"
    elif grep -qi "ubuntu" /etc/issue /proc/version 2>/dev/null; then
        echo "ubuntu"
    elif grep -Eqi "debian" /etc/issue /proc/version 2>/dev/null; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# 获取默认网卡
get_iface() { ip route show default | awk '/default/{print $5; exit}'; }

# 安装依赖
install_deps() {
    local sys=$(detect_system)
    info "正在检查系统依赖..."

    if ! command -v iptables &>/dev/null; then
        warn "正在安装 iptables..."
        case $sys in
            centos)
                yum install -y iptables iptables-services
                systemctl enable --now iptables ip6tables
                ;;
            debian|ubuntu)
                apt-get update
                DEBIAN_FRONTEND=noninteractive apt-get install -y iptables iptables-persistent
                ;;
            *) die "不支持的系统" ;;
        esac
    fi
    ok "iptables 已就绪"

    # 启用 IP 转发
    local -a params=("net.ipv4.ip_forward=1" "net.ipv6.conf.all.forwarding=1")
    for p in "${params[@]}"; do
        local key="${p%=*}"
        grep -q "^${key}" /etc/sysctl.conf 2>/dev/null && \
            sed -i "s|^${key}.*|${p}|" /etc/sysctl.conf || \
            echo "$p" >> /etc/sysctl.conf
    done
    sysctl -p &>/dev/null
    ok "IP 转发已启用"

    # 创建配置目录和文件
    mkdir -p "$CONFIG_DIR"
    [[ -f "$CONFIG_FILE" ]] || echo -e "IPV4_IN=allow\nIPV4_OUT=allow\nIPV6_IN=allow\nIPV6_OUT=allow" > "$CONFIG_FILE"
    [[ -f "$RULES_FILE" ]] || touch "$RULES_FILE"

    ok "初始化完成！"
}

# 加载/保存配置
load_config() { [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"; }

save_config() {
    cat > "$CONFIG_FILE" <<-EOF
	IPV4_IN=${IPV4_IN}
	IPV4_OUT=${IPV4_OUT}
	IPV6_IN=${IPV6_IN}
	IPV6_OUT=${IPV6_OUT}
	EOF
}

# 应用流量控制策略
apply_traffic_policy() {
    load_config
    local -a tables=(iptables ip6tables)

    for t in "${tables[@]}"; do
        $t -P INPUT ACCEPT 2>/dev/null || true
        $t -P OUTPUT ACCEPT 2>/dev/null || true
        $t -P FORWARD ACCEPT 2>/dev/null || true
    done

    # IPv4 入站
    if [[ "$IPV4_IN" == "deny" ]]; then
        iptables -P INPUT DROP
        iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        iptables -A INPUT -i lo -j ACCEPT
    fi

    # IPv4 出站
    if [[ "$IPV4_OUT" == "deny" ]]; then
        iptables -P OUTPUT DROP
        iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        iptables -A OUTPUT -o lo -j ACCEPT
    fi

    # IPv6 入站
    if [[ "$IPV6_IN" == "deny" ]]; then
        ip6tables -P INPUT DROP
        ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        ip6tables -A INPUT -i lo -j ACCEPT
    fi

    # IPv6 出站
    if [[ "$IPV6_OUT" == "deny" ]]; then
        ip6tables -P OUTPUT DROP
        ip6tables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        ip6tables -A OUTPUT -o lo -j ACCEPT
    fi
}

# 添加单个转发规则
add_forward_rule() {
    local lport=$1 rip=$2 rport=$3
    local iface=$(get_iface)

    # 检查是否已存在
    grep -q "^${lport}:" "$RULES_FILE" 2>/dev/null && { warn "端口 ${lport} 规则已存在"; return 1; }

    if [[ "$rip" == *:* ]]; then
        # IPv6
        ip6tables -t nat -A PREROUTING -p tcp --dport "${lport}" -j DNAT --to-destination "[${rip}]:${rport}"
        ip6tables -t nat -A PREROUTING -p udp --dport "${lport}" -j DNAT --to-destination "[${rip}]:${rport}"
        ip6tables -t nat -A POSTROUTING -o "${iface}" -j MASQUERADE
        ip6tables -A FORWARD -p tcp -d "${rip}" --dport "${rport}" -j ACCEPT
        ip6tables -A FORWARD -p udp -d "${rip}" --dport "${rport}" -j ACCEPT
    else
        # IPv4
        iptables -t nat -A PREROUTING -p tcp --dport "${lport}" -j DNAT --to-destination "${rip}:${rport}"
        iptables -t nat -A PREROUTING -p udp --dport "${lport}" -j DNAT --to-destination "${rip}:${rport}"
        iptables -t nat -A POSTROUTING -o "${iface}" -j MASQUERADE
        iptables -A FORWARD -p tcp -d "${rip}" --dport "${rport}" -j ACCEPT
        iptables -A FORWARD -p udp -d "${rip}" --dport "${rport}" -j ACCEPT
        iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
    fi

    echo "${lport}:${rip}:${rport}" >> "$RULES_FILE"
    ok "添加转发: ${lport} -> ${rip}:${rport}"
}

# 删除单个转发规则
del_forward_rule() {
    local lport=$1
    local rule=$(grep "^${lport}:" "$RULES_FILE" 2>/dev/null)

    [[ -z "$rule" ]] && { warn "未找到端口 ${lport}"; return 1; }

    local ip=$(cut -d: -f2 <<< "$rule")
    local rport=$(cut -d: -f3 <<< "$rule")

    if [[ "$ip" == *:* ]]; then
        ip6tables -t nat -D PREROUTING -p tcp --dport "${lport}" -j DNAT --to-destination "[${ip}]:${rport}" 2>/dev/null
        ip6tables -t nat -D PREROUTING -p udp --dport "${lport}" -j DNAT --to-destination "[${ip}]:${rport}" 2>/dev/null
        ip6tables -D FORWARD -p tcp -d "${ip}" --dport "${rport}" -j ACCEPT 2>/dev/null
        ip6tables -D FORWARD -p udp -d "${ip}" --dport "${rport}" -j ACCEPT 2>/dev/null
    else
        iptables -t nat -D PREROUTING -p tcp --dport "${lport}" -j DNAT --to-destination "${ip}:${rport}" 2>/dev/null
        iptables -t nat -D PREROUTING -p udp --dport "${lport}" -j DNAT --to-destination "${ip}:${rport}" 2>/dev/null
        iptables -D FORWARD -p tcp -d "${ip}" --dport "${rport}" -j ACCEPT 2>/dev/null
        iptables -D FORWARD -p udp -d "${ip}" --dport "${rport}" -j ACCEPT 2>/dev/null
    fi

    sed -i "/^${lport}:/d" "$RULES_FILE"
    ok "删除转发: ${lport} -> ${ip}:${rport}"
}

# 解析端口范围
parse_port_range() {
    local input=$1 callback=$2

    IFS=',' read -ra groups <<< "$input"
    for g in "${groups[@]}"; do
        g=$(tr -d ' ' <<< "$g")
        if [[ "$g" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            for ((p=BASH_REMATCH[1]; p<=BASH_REMATCH[2]; p++)); do
                $callback "$p"
            done
        elif [[ "$g" =~ ^[0-9]+$ ]]; then
            $callback "$g"
        fi
    done
}

# 添加转发（交互）
add_forward() {
    info "\n=== 添加端口转发 ==="
    echo "格式: [本地端口] [远程IP:远程端口]"
    echo "示例: 80 1.1.1.1:80 或 81-85 1.1.1.1:81-85"
    echo
    read -rp "请输入: " input

    [[ -z "$input" ]] && { err "输入不能为空"; return; }

    local lports rip rports
    read -r lports rip_rport <<< "$input"
    rip=$(rev <<< "$rip_rport" | cut -d: -f2- | rev)
    rports=$(rev <<< "$rip_rport" | cut -d: -f1 | rev)

    [[ -z "$lports" || -z "$rip" || -z "$rports" ]] && { err "格式错误"; return; }

    # 处理端口范围
    if [[ "$lports" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        local ls=${BASH_REMATCH[1]} le=${BASH_REMATCH[2]}
        if [[ "$rports" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local rs=${BASH_REMATCH[1]} re=${BASH_REMATCH[2]}
            [[ $((le-ls)) -ne $((re-rs)) ]] && { err "端口范围不匹配"; return; }
            for ((i=0; i<=(le-ls); i++)); do
                add_forward_rule $((ls+i)) "$rip" $((rs+i))
            done
        else
            err "本地使用范围时，远程也必须使用范围"
            return
        fi
    else
        add_forward_rule "$lports" "$rip" "$rports"
    fi

    save_rules
    ok "\n添加完成！"
}

# 删除转发（交互）
del_forward() {
    info "\n=== 删除端口转发 ==="
    list_forwards
    echo "格式: 80 或 80,81 或 82-84"
    read -rp "请输入要删除的端口: " input

    [[ -z "$input" ]] && { err "输入不能为空"; return; }

    parse_port_range "$input" del_forward_rule
    save_rules
}

# 列出所有转发规则
list_forwards() {
    info "\n=== 当前转发规则 ==="

    [[ ! -s "$RULES_FILE" ]] && { warn "暂无转发规则"; return; }

    printf "\n%-10s %-28s %-10s\n" "本地端口" "远程地址" "远程端口"
    printf "%-10s %-28s %-10s\n" "--------" "--------------------------" "--------"

    while IFS=: read -r lp rip rp; do
        [[ -z "$lp" ]] && continue
        printf "%-10s %-28s %-10s\n" "$lp" "$rip" "$rp"
    done < "$RULES_FILE"
    echo
}

# 流量控制配置菜单
traffic_control_menu() {
    load_config
    while true; do
        clear
        info "\n=== 流量控制配置 ==="
        local v4in=$([ "$IPV4_IN" == "allow" ] && echo "允许" || echo "禁止")
        local v4out=$([ "$IPV4_OUT" == "allow" ] && echo "允许" || echo "禁止")
        local v6in=$([ "$IPV6_IN" == "allow" ] && echo "允许" || echo "禁止")
        local v6out=$([ "$IPV6_OUT" == "allow" ] && echo "允许" || echo "禁止")

        echo
        echo "  1. IPv4 入站: $v4in"
        echo "  2. IPv4 出站: $v4out"
        echo "  3. IPv6 入站: $v6in"
        echo "  4. IPv6 出站: $v6out"
        echo "  ─────────────────"
        echo "  5. 预设配置"
        echo "  0. 返回"
        echo
        read -rp "选择: " c

        case $c in
            1) IPV4_IN=$([ "$IPV4_IN" == "allow" ] && echo "deny" || echo "allow") ;;
            2) IPV4_OUT=$([ "$IPV4_OUT" == "allow" ] && echo "deny" || echo "allow") ;;
            3) IPV6_IN=$([ "$IPV6_IN" == "allow" ] && echo "deny" || echo "allow") ;;
            4) IPV6_OUT=$([ "$IPV6_OUT" == "allow" ] && echo "deny" || echo "allow") ;;
            5) preset_menu; continue ;;
            0) break ;;
            *) continue ;;
        esac

        save_config
        apply_traffic_policy
        save_rules
    done
}

# 预设配置菜单
preset_menu() {
    clear
    info "=== 预设流量控制 ==="
    echo
    echo "  ┌─────────┬────────────┬────────────┬────────────┐"
    echo "  │         │  IPv4 出站 │  IPv6 出站 │   双栈出站 │"
    echo "  ├─────────┼────────────┼────────────┼────────────┤"
    echo "  │ IPv4入站│     1      │     2      │     3      │"
    echo "  ├─────────┼────────────┼────────────┼────────────┤"
    echo "  │ IPv6入站│     4      │     5      │     6      │"
    echo "  ├─────────┼────────────┼────────────┼────────────┤"
    echo "  │ 双栈入站│     7      │     8      │     9      │"
    echo "  └─────────┴────────────┴────────────┴────────────┘"
    echo
    echo "  0. 返回"
    echo
    read -rp "选择 [0-9]: " p

    case $p in
        1) IPV4_IN=allow; IPV4_OUT=allow; IPV6_IN=deny;  IPV6_OUT=deny  ;;
        2) IPV4_IN=allow; IPV4_OUT=deny;  IPV6_IN=deny;  IPV6_OUT=allow ;;
        3) IPV4_IN=allow; IPV4_OUT=allow; IPV6_IN=deny;  IPV6_OUT=allow ;;
        4) IPV4_IN=deny;  IPV4_OUT=allow; IPV6_IN=allow; IPV6_OUT=deny  ;;
        5) IPV4_IN=deny;  IPV4_OUT=deny;  IPV6_IN=allow; IPV6_OUT=allow ;;
        6) IPV4_IN=deny;  IPV4_OUT=allow; IPV6_IN=allow; IPV6_OUT=allow ;;
        7) IPV4_IN=allow; IPV4_OUT=allow; IPV6_IN=allow; IPV6_OUT=deny  ;;
        8) IPV4_IN=allow; IPV4_OUT=deny;  IPV6_IN=allow; IPV6_OUT=allow ;;
        9) IPV4_IN=allow; IPV4_OUT=allow; IPV6_IN=allow; IPV6_OUT=allow ;;
        0) return ;;
        *) return ;;
    esac

    save_config
    apply_traffic_policy
    save_rules
    ok "预设已应用！"
    sleep 1
}

# 保存 iptables 规则到持久化文件
save_rules() {
    local sys=$(detect_system)
    case $sys in
        centos)
            iptables-save > /etc/sysconfig/iptables
            ip6tables-save > /etc/sysconfig/ip6tables
            ;;
        debian|ubuntu)
            iptables-save > /etc/iptables/rules.v4
            ip6tables-save > /etc/iptables/rules.v6
            ;;
    esac
}

# 从配置文件加载规则
load_rules() {
    [[ -f "$RULES_FILE" ]] || return
    info "正在加载规则..."

    # 清空现有规则
    iptables -t nat -F
    ip6tables -t nat -F 2>/dev/null || true

    apply_traffic_policy

    local iface=$(get_iface)

    while IFS=: read -r lport rip rport; do
        [[ -z "$lport" ]] && continue

        if [[ "$rip" == *:* ]]; then
            ip6tables -t nat -A PREROUTING -p tcp --dport "${lport}" -j DNAT --to-destination "[${rip}]:${rport}"
            ip6tables -t nat -A PREROUTING -p udp --dport "${lport}" -j DNAT --to-destination "[${rip}]:${rport}"
            ip6tables -t nat -A POSTROUTING -o "${iface}" -j MASQUERADE
            ip6tables -A FORWARD -p tcp -d "${rip}" --dport "${rport}" -j ACCEPT
            ip6tables -A FORWARD -p udp -d "${rip}" --dport "${rport}" -j ACCEPT
        else
            iptables -t nat -A PREROUTING -p tcp --dport "${lport}" -j DNAT --to-destination "${rip}:${rport}"
            iptables -t nat -A PREROUTING -p udp --dport "${lport}" -j DNAT --to-destination "${rip}:${rport}"
            iptables -t nat -A POSTROUTING -o "${iface}" -j MASQUERADE
            iptables -A FORWARD -p tcp -d "${rip}" --dport "${rport}" -j ACCEPT
            iptables -A FORWARD -p udp -d "${rip}" --dport "${rport}" -j ACCEPT
            iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
        fi
    done < "$RULES_FILE"

    ok "规则加载完成"
}

# 查看 iptables 规则
view_rules() {
    clear
    info "=== NAT PREROUTING ==="
    iptables -t nat -L PREROUTING -nv --line-numbers 2>/dev/null || true
    echo
    info "=== NAT POSTROUTING ==="
    iptables -t nat -L POSTROUTING -nv --line-numbers 2>/dev/null || true
    echo
    info "=== FORWARD ==="
    iptables -L FORWARD -nv --line-numbers 2>/dev/null || true
    echo
    read -rp "按回车继续..."
}

# 完整卸载
uninstall() {
    msg "$RED" "\n=== 完整卸载 ==="
    read -rp "确定卸载？(yes/no): " c
    [[ "$c" != "yes" ]] && return

    local -a tables=(iptables ip6tables)
    for t in "${tables[@]}"; do
        $t -F 2>/dev/null || true
        $t -X 2>/dev/null || true
        $t -t nat -F 2>/dev/null || true
        $t -t nat -X 2>/dev/null || true
        $t -P INPUT ACCEPT 2>/dev/null || true
        $t -P FORWARD ACCEPT 2>/dev/null || true
        $t -P OUTPUT ACCEPT 2>/dev/null || true
    done

    rm -rf "$CONFIG_DIR"
    save_rules
    ok "卸载完成！"
    exit 0
}

# 主菜单
main_menu() {
    while true; do
        clear
        msg "$GREEN" "╔════════════════════════════════════════════╗"
        msg "$GREEN" "║          iptables 端口转发管理             ║"
        msg "$GREEN" "╚════════════════════════════════════════════╝"
        echo
        echo "  1. 添加端口转发"
        echo "  2. 删除端口转发"
        echo "  3. 查看转发规则"
        echo "  4. 流量控制配置"
        echo "  5. 查看 iptables 规则"
        echo "  6. 重新加载规则"
        echo "  7. 完整卸载"
        echo "  0. 退出"
        echo
        read -rp "选择 [0-7]: " c

        case $c in
            1) add_forward; read -rp "按回车继续..." ;;
            2) del_forward; read -rp "按回车继续..." ;;
            3) list_forwards; read -rp "按回车继续..." ;;
            4) traffic_control_menu ;;
            5) view_rules ;;
            6) load_rules; save_rules; ok "规则重载完成！"; read -rp "按回车继续..." ;;
            7) uninstall ;;
            0) info "再见！"; exit 0 ;;
        esac
    done
}

# 主入口
main() {
    check_root

    if [[ ! -d "$CONFIG_DIR" ]]; then
        clear
        msg "$GREEN" "╔════════════════════════════════════════════╗"
        msg "$GREEN" "║          iptables 端口转发管理             ║"
        msg "$GREEN" "╚════════════════════════════════════════════╝"
        echo
        install_deps
        echo
        read -rp "按回车继续..."
    else
        load_rules
    fi

    main_menu
}

main "$@"
