#!/bin/bash

# Caddy 一键管理脚本
# 功能：安装、卸载、反向代理配置
# 适用于 Debian / Ubuntu 系统

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CADDYFILE="/etc/caddy/Caddyfile"
CADDYFILE_BACKUP="/etc/caddy/Caddyfile.backup"

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════╗"
    echo "║       Caddy 一键管理脚本               ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}提示：部分操作需要 root 权限，将使用 sudo${NC}"
    fi
}

is_caddy_installed() {
    command -v caddy >/dev/null 2>&1
}

show_caddy_status() {
    echo -e "${GREEN}━━━━━━━━━━━━ Caddy 状态 ━━━━━━━━━━━━${NC}"
    echo -e "版本: ${CYAN}$(caddy version 2>/dev/null || echo '未知')${NC}"
    if systemctl is-active --quiet caddy 2>/dev/null; then
        echo -e "服务状态: ${GREEN}运行中${NC}"
    else
        echo -e "服务状态: ${RED}未运行${NC}"
    fi
    echo -e "配置文件: ${CYAN}${CADDYFILE}${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

show_menu() {
    echo ""
    echo -e "${YELLOW}请选择操作：${NC}"
    echo -e "  ${GREEN}1)${NC} 查看当前反代配置"
    echo -e "  ${GREEN}2)${NC} 添加反向代理"
    echo -e "  ${GREEN}3)${NC} 批量添加反向代理"
    echo -e "  ${GREEN}4)${NC} 删除反向代理"
    echo -e "  ${GREEN}5)${NC} 重启 Caddy 服务"
    echo -e "  ${GREEN}6)${NC} 查看 Caddy 日志"
    echo -e "  ${GREEN}7)${NC} 完整卸载 Caddy"
    echo -e "  ${GREEN}0)${NC} 退出"
    echo ""
}

show_install_menu() {
    echo ""
    echo -e "${YELLOW}Caddy 未安装，请选择操作：${NC}"
    echo -e "  ${GREEN}1)${NC} 安装 Caddy"
    echo -e "  ${GREEN}0)${NC} 退出"
    echo ""
}

install_caddy() {
    echo -e "${BLUE}[1/5] 正在更新系统并安装必要工具...${NC}"
    sudo apt update -y
    sudo apt full-upgrade -y
    sudo apt install -y curl wget sudo unzip

    echo -e "${BLUE}[2/5] 安装 Caddy 所需的依赖...${NC}"
    sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https ca-certificates gnupg

    echo -e "${BLUE}[3/5] 添加 Caddy stable 版 GPG 密钥...${NC}"
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

    echo -e "${BLUE}[4/5] 添加 Caddy stable 版 apt 源...${NC}"
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null

    echo -e "${BLUE}[5/5] 再次更新软件包列表并安装 Caddy...${NC}"
    sudo apt update
    sudo apt install -y caddy

    sudo systemctl enable caddy
    sudo systemctl start caddy

    echo -e "${GREEN}Caddy 安装完成！${NC}"
    sleep 2
}

uninstall_caddy() {
    echo -e "${RED}警告：此操作将完整卸载 Caddy 及其配置文件！${NC}"
    read -p "确认卸载？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "取消卸载"
        return
    fi

    echo -e "${BLUE}停止 Caddy 服务...${NC}"
    sudo systemctl stop caddy 2>/dev/null || true
    sudo systemctl disable caddy 2>/dev/null || true

    echo -e "${BLUE}卸载 Caddy 软件包...${NC}"
    sudo apt purge -y caddy

    echo -e "${BLUE}删除配置文件和数据...${NC}"
    sudo rm -rf /etc/caddy
    sudo rm -rf /var/lib/caddy
    sudo rm -rf /var/log/caddy
    sudo rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    sudo rm -f /etc/apt/sources.list.d/caddy-stable.list

    echo -e "${BLUE}清理残留依赖...${NC}"
    sudo apt autoremove -y

    echo -e "${GREEN}Caddy 已完整卸载！${NC}"
    sleep 2
}

show_current_proxies() {
    echo -e "${GREEN}━━━━━━━━━━ 当前反代配置 ━━━━━━━━━━${NC}"
    echo -e "配置文件: ${CYAN}${CADDYFILE}${NC}"
    echo ""
    if [[ -f "$CADDYFILE" ]]; then
        cat -n "$CADDYFILE"
    else
        echo -e "${YELLOW}配置文件不存在${NC}"
    fi
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "按回车继续..."
}

parse_proxy_input() {
    local input="$1"
    local addr domain_str
    read addr domain_str <<< "$input"
    
    # 处理地址，如果没有冒号则默认 localhost
    if [[ "$addr" != *":"* ]]; then
        addr="localhost:$addr"
    fi
    
    echo "$addr $domain_str"
}

add_proxy_config() {
    local addr="$1"
    local domains="$2"
    
    # 将逗号分隔的域名转换为空格分隔
    domains=$(echo "$domains" | tr ',' ' ')
    
    local config="${domains} {
    encode gzip
    reverse_proxy ${addr}
}

"
    echo "$config" | sudo tee -a "$CADDYFILE" > /dev/null
    echo -e "${GREEN}已添加: ${domains} -> ${addr}${NC}"
}

add_single_proxy() {
    echo -e "${CYAN}添加反向代理${NC}"
    echo "格式说明："
    echo "  端口        域名           -> localhost:端口 反代到 域名"
    echo "  IP:端口     域名           -> IP:端口 反代到 域名"
    echo "  端口/IP:端口 域名1,域名2   -> 多域名反代"
    echo ""
    read -p "请输入 (例: 8080 example.com): " input
    
    if [[ -z "$input" ]]; then
        echo -e "${RED}输入为空，取消操作${NC}"
        return
    fi
    
    local parsed=$(parse_proxy_input "$input")
    local addr=$(echo "$parsed" | cut -d' ' -f1)
    local domains=$(echo "$parsed" | cut -d' ' -f2-)
    
    if [[ -z "$domains" ]]; then
        echo -e "${RED}域名不能为空${NC}"
        return
    fi
    
    add_proxy_config "$addr" "$domains"
    reload_caddy
}

add_batch_proxy() {
    echo -e "${CYAN}批量添加反向代理${NC}"
    echo "每行一条配置，格式同单条添加"
    echo "示例："
    echo "  8080 example.com"
    echo "  192.168.5.71:9080 example1.com"
    echo "  8080 example2.com,example3.com"
    echo ""
    echo -e "${YELLOW}请输入配置（输入空行结束）：${NC}"
    
    local configs=()
    while true; do
        read -p "> " line
        if [[ -z "$line" ]]; then
            break
        fi
        configs+=("$line")
    done
    
    if [[ ${#configs[@]} -eq 0 ]]; then
        echo -e "${RED}未输入任何配置${NC}"
        return
    fi
    
    for config in "${configs[@]}"; do
        local parsed=$(parse_proxy_input "$config")
        local addr=$(echo "$parsed" | cut -d' ' -f1)
        local domains=$(echo "$parsed" | cut -d' ' -f2-)
        
        if [[ -n "$domains" ]]; then
            add_proxy_config "$addr" "$domains"
        fi
    done
    
    reload_caddy
}

delete_proxy() {
    echo -e "${GREEN}━━━━━━━━━━ 删除反向代理 ━━━━━━━━━━${NC}"
    echo -e "配置文件: ${CYAN}${CADDYFILE}${NC}"
    echo ""
    if [[ -f "$CADDYFILE" ]]; then
        cat -n "$CADDYFILE"
    else
        echo -e "${YELLOW}配置文件不存在${NC}"
        read -p "按回车继续..."
        return
    fi
    
    echo ""
    echo -e "${YELLOW}选项：${NC}"
    echo "  1) 输入删除的行号"
    echo "  2) 清空所有配置"
    echo "  0) 返回"
    read -p "请选择: " choice
    
    case $choice in
        1)
            read -p "请输入要删除的行号 (如: 5 或 1-6): " line_input
            if [[ -z "$line_input" ]]; then
                echo -e "${RED}输入为空，取消操作${NC}"
                read -p "按回车继续..."
                return
            fi
            
            # 验证输入格式
            if [[ "$line_input" =~ ^[0-9]+$ ]]; then
                # 单行删除
                sudo sed -i "${line_input}d" "$CADDYFILE"
                echo -e "${GREEN}已删除第 ${line_input} 行${NC}"
            elif [[ "$line_input" =~ ^[0-9]+-[0-9]+$ ]]; then
                # 范围删除
                local start=$(echo "$line_input" | cut -d'-' -f1)
                local end=$(echo "$line_input" | cut -d'-' -f2)
                sudo sed -i "${start},${end}d" "$CADDYFILE"
                echo -e "${GREEN}已删除第 ${start}-${end} 行${NC}"
            else
                echo -e "${RED}格式错误，请输入如 5 或 1-6${NC}"
                read -p "按回车继续..."
                return
            fi
            
            # 删除可能残留的空行
            sudo sed -i '/^[[:space:]]*$/d' "$CADDYFILE"
            reload_caddy
            ;;
        2)
            read -p "确认清空所有配置？(y/N): " confirm
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                echo "" | sudo tee "$CADDYFILE" > /dev/null
                echo -e "${GREEN}配置已清空${NC}"
                reload_caddy
            fi
            ;;
        0)
            return
            ;;
    esac
    read -p "按回车继续..."
}

reload_caddy() {
    echo -e "${BLUE}重载 Caddy 配置...${NC}"
    if sudo caddy reload --config "$CADDYFILE" --adapter caddyfile 2>/dev/null; then
        echo -e "${GREEN}配置重载成功！${NC}"
    else
        echo -e "${YELLOW}重载失败，尝试重启服务...${NC}"
        sudo systemctl restart caddy
        if systemctl is-active --quiet caddy; then
            echo -e "${GREEN}服务重启成功！${NC}"
        else
            echo -e "${RED}服务启动失败，请检查配置${NC}"
        fi
    fi
}

restart_caddy() {
    echo -e "${BLUE}重启 Caddy 服务...${NC}"
    sudo systemctl restart caddy
    if systemctl is-active --quiet caddy; then
        echo -e "${GREEN}Caddy 服务已重启！${NC}"
    else
        echo -e "${RED}重启失败，请检查日志${NC}"
    fi
    read -p "按回车继续..."
}

show_logs() {
    echo -e "${CYAN}Caddy 最近日志（按 q 退出）：${NC}"
    sudo journalctl -u caddy -n 50 --no-pager | less
}

main() {
    check_root
    
    while true; do
        print_banner
        
        if is_caddy_installed; then
            show_caddy_status
            show_menu
            read -p "请输入选项: " choice
            
            case $choice in
                1) show_current_proxies ;;
                2) add_single_proxy; read -p "按回车继续..." ;;
                3) add_batch_proxy; read -p "按回车继续..." ;;
                4) delete_proxy ;;
                5) restart_caddy ;;
                6) show_logs ;;
                7) uninstall_caddy ;;
                0) echo "再见！"; exit 0 ;;
                *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
            esac
        else
            echo -e "${YELLOW}Caddy 未安装${NC}"
            show_install_menu
            read -p "请输入选项: " choice
            
            case $choice in
                1) install_caddy ;;
                0) echo "再见！"; exit 0 ;;
                *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
            esac
        fi
    done
}

main
