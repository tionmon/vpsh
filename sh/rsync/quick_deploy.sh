#!/bin/bash

# Rsync备份工具快速部署脚本
# 用于在多台服务器上快速部署相同配置的备份工具

# ================================
# 快速配置区
# 修改以下变量以适应您的环境
# ================================

# Telegram配置
TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN_HERE"
TELEGRAM_CHAT_ID="YOUR_CHAT_ID_HERE"

# 远程备份服务器配置
BACKUP_SERVER_IP="YOUR_BACKUP_SERVER_IP"
BACKUP_SERVER_USER="backup"
BACKUP_SERVER_SSH_PORT="22"
BACKUP_BASE_DIR="/backups"

# 默认备份配置
DEFAULT_BACKUP_SOURCES="/etc /home /var/www /opt"
DEFAULT_EXCLUDE_PATTERNS="*.log *.tmp cache/* temp/* .cache/* node_modules/*"
DEFAULT_LOCAL_KEEP_DAYS="7"
DEFAULT_REMOTE_KEEP_DAYS="30"
DEFAULT_BACKUP_INTERVAL="24"

# ================================
# 脚本逻辑（通常不需要修改）
# ================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

error_exit() {
    log "${RED}错误: $1${NC}"
    exit 1
}

show_banner() {
    clear
    echo -e "${BLUE}"
    echo "=================================================="
    echo "       Rsync备份工具 - 快速部署脚本"
    echo "=================================================="
    echo -e "${NC}"
    echo
}

check_config() {
    log "${YELLOW}检查配置...${NC}"
    
    if [ "$TELEGRAM_BOT_TOKEN" = "YOUR_BOT_TOKEN_HERE" ] || [ -z "$TELEGRAM_BOT_TOKEN" ]; then
        error_exit "请先配置 TELEGRAM_BOT_TOKEN"
    fi
    
    if [ "$TELEGRAM_CHAT_ID" = "YOUR_CHAT_ID_HERE" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        error_exit "请先配置 TELEGRAM_CHAT_ID"
    fi
    
    if [ "$BACKUP_SERVER_IP" = "YOUR_BACKUP_SERVER_IP" ] || [ -z "$BACKUP_SERVER_IP" ]; then
        error_exit "请先配置 BACKUP_SERVER_IP"
    fi
    
    log "${GREEN}✓ 配置检查通过${NC}"
}

download_installer() {
    log "${YELLOW}下载安装脚本...${NC}"
    
    if [ ! -f "rsync_backup_installer.sh" ]; then
        error_exit "rsync_backup_installer.sh 文件不存在，请确保文件在当前目录"
    fi
    
    log "${GREEN}✓ 安装脚本已就绪${NC}"
}

create_auto_config() {
    local hostname=$(hostname)
    local config_script="auto_install_${hostname}.sh"
    
    log "${YELLOW}为主机 ${hostname} 创建自动配置脚本...${NC}"
    
    # 创建预配置的安装脚本
    cp rsync_backup_installer.sh "$config_script"
    
    # 替换配置变量
    sed -i "s/^BOT_TOKEN=\"\"/BOT_TOKEN=\"$TELEGRAM_BOT_TOKEN\"/" "$config_script"
    sed -i "s/^CHAT_ID=\"\"/CHAT_ID=\"$TELEGRAM_CHAT_ID\"/" "$config_script"
    sed -i "s/^TARGET_IP=\"\"/TARGET_IP=\"$BACKUP_SERVER_IP\"/" "$config_script"
    sed -i "s/^TARGET_USER=\"\"/TARGET_USER=\"$BACKUP_SERVER_USER\"/" "$config_script"
    sed -i "s/^SSH_PORT=\"\"/SSH_PORT=\"$BACKUP_SERVER_SSH_PORT\"/" "$config_script"
    sed -i "s/^TARGET_BASE_DIR=\"\"/TARGET_BASE_DIR=\"$BACKUP_BASE_DIR\"/" "$config_script"
    sed -i "s/^REMOTE_DIR_NAME=\"\"/REMOTE_DIR_NAME=\"$hostname\"/" "$config_script"
    sed -i "s/^BACKUP_SOURCE_DIRS=\".*\"/BACKUP_SOURCE_DIRS=\"$DEFAULT_BACKUP_SOURCES\"/" "$config_script"
    sed -i "s/^BACKUP_EXCLUDE_PATTERNS=\".*\"/BACKUP_EXCLUDE_PATTERNS=\"$DEFAULT_EXCLUDE_PATTERNS\"/" "$config_script"
    sed -i "s/^LOCAL_BACKUP_KEEP_DAYS=\".*\"/LOCAL_BACKUP_KEEP_DAYS=\"$DEFAULT_LOCAL_KEEP_DAYS\"/" "$config_script"
    sed -i "s/^REMOTE_BACKUP_KEEP_DAYS=\".*\"/REMOTE_BACKUP_KEEP_DAYS=\"$DEFAULT_REMOTE_KEEP_DAYS\"/" "$config_script"
    sed -i "s/^BACKUP_INTERVAL_HOURS=\".*\"/BACKUP_INTERVAL_HOURS=\"$DEFAULT_BACKUP_INTERVAL\"/" "$config_script"
    
    chmod +x "$config_script"
    
    log "${GREEN}✓ 自动配置脚本已创建: $config_script${NC}"
    echo "$config_script"
}

show_deployment_info() {
    local config_script="$1"
    local hostname=$(hostname)
    
    echo
    log "${CYAN}部署信息:${NC}"
    log "  主机名: ${hostname}"
    log "  备份服务器: ${BACKUP_SERVER_USER}@${BACKUP_SERVER_IP}:${BACKUP_SERVER_SSH_PORT}"
    log "  远程目录: ${BACKUP_BASE_DIR}/${hostname}"
    log "  备份源: ${DEFAULT_BACKUP_SOURCES}"
    log "  本地保留: ${DEFAULT_LOCAL_KEEP_DAYS}天"
    log "  远程保留: ${DEFAULT_REMOTE_KEEP_DAYS}天"
    log "  备份间隔: ${DEFAULT_BACKUP_INTERVAL}小时"
    echo
    
    read -p "确认以上配置并开始安装？[Y/n]: " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        log "${YELLOW}安装已取消${NC}"
        exit 0
    fi
}

run_installation() {
    local config_script="$1"
    
    log "${YELLOW}开始自动安装...${NC}"
    
    if [ "$EUID" -ne 0 ]; then
        log "${YELLOW}需要root权限，正在使用sudo...${NC}"
        sudo bash "$config_script"
    else
        bash "$config_script"
    fi
    
    if [ $? -eq 0 ]; then
        log "${GREEN}✓ 安装完成！${NC}"
    else
        error_exit "安装失败"
    fi
}

cleanup() {
    local config_script="$1"
    
    if [ -f "$config_script" ]; then
        rm -f "$config_script"
        log "${CYAN}✓ 清理临时文件${NC}"
    fi
}

generate_batch_script() {
    log "${YELLOW}生成批量部署脚本...${NC}"
    
    cat > "batch_deploy.sh" << 'EOFBATCH'
#!/bin/bash

# 批量部署脚本
# 使用方法: ./batch_deploy.sh server1 server2 server3 ...

if [ $# -eq 0 ]; then
    echo "使用方法: $0 <服务器IP1> [服务器IP2] [服务器IP3] ..."
    echo "示例: $0 192.168.1.10 192.168.1.11 192.168.1.12"
    exit 1
fi

SCRIPT_DIR=$(dirname "$0")
DEPLOY_SCRIPT="$SCRIPT_DIR/quick_deploy.sh"

if [ ! -f "$DEPLOY_SCRIPT" ]; then
    echo "错误: 找不到 quick_deploy.sh 脚本"
    exit 1
fi

for server in "$@"; do
    echo "=================================================="
    echo "正在部署到服务器: $server"
    echo "=================================================="
    
    if ssh -o ConnectTimeout=10 root@"$server" 'bash -s' < "$DEPLOY_SCRIPT"; then
        echo "✓ 服务器 $server 部署成功"
    else
        echo "✗ 服务器 $server 部署失败"
    fi
    
    echo
done

echo "批量部署完成！"
EOFBATCH
    
    chmod +x batch_deploy.sh
    log "${GREEN}✓ 批量部署脚本已创建: batch_deploy.sh${NC}"
}

show_usage() {
    echo "用法说明:"
    echo
    echo "1. 单机部署:"
    echo "   sudo ./quick_deploy.sh"
    echo
    echo "2. 批量部署:"
    echo "   ./batch_deploy.sh 192.168.1.10 192.168.1.11 192.168.1.12"
    echo
    echo "3. 远程部署:"
    echo "   scp quick_deploy.sh root@target-server:/"
    echo "   ssh root@target-server './quick_deploy.sh'"
    echo
}

main() {
    show_banner
    
    # 如果有参数，显示使用说明
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_usage
        exit 0
    fi
    
    # 如果有参数 --batch，生成批量部署脚本
    if [ "$1" = "--batch" ]; then
        generate_batch_script
        exit 0
    fi
    
    check_config
    download_installer
    
    local config_script=$(create_auto_config)
    show_deployment_info "$config_script"
    run_installation "$config_script"
    cleanup "$config_script"
    
    echo
    log "${GREEN}🎉 快速部署完成！${NC}"
    echo
    log "${CYAN}管理命令:${NC}"
    log "  查看状态: systemctl status rsync-backup.timer"
    log "  立即备份: systemctl start rsync-backup.service"
    log "  查看日志: journalctl -u rsync-backup.service -f"
    echo
    log "${BLUE}如需批量部署到多台服务器，运行: $0 --batch${NC}"
}

# 运行主程序
main "$@"
