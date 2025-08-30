#!/bin/bash

# 增强版rsync备份工具安装脚本
# 版本: v1.0 - 基于系统快照备份工具改进
# 功能: 智能rsync备份、Telegram通知、系统监控、定时任务

# ====================================================================
# ## 用户配置区 ##
# 在运行脚本前，您可以直接在此处修改默认值，以实现快速部署
# ====================================================================

# --- Telegram 配置 ---
BOT_TOKEN=""
CHAT_ID=""

# --- 远程 SSH 服务器配置 ---
TARGET_IP=""
TARGET_USER=""
SSH_PORT="22"
TARGET_BASE_DIR="/backups"
REMOTE_DIR_NAME=""

# --- 本地配置 ---
BACKUP_SOURCE_DIRS="/etc /home /var/www /opt"  # 要备份的目录，空格分隔
BACKUP_EXCLUDE_PATTERNS="*.log *.tmp cache/* temp/* .cache/* node_modules/*"  # 排除模式
LOCAL_BACKUP_DIR="/backups/rsync"
ENABLE_COMPRESSION="Y"  # 是否启用压缩传输

# --- 备份保留策略 ---
LOCAL_BACKUP_KEEP_DAYS="7"
REMOTE_BACKUP_KEEP_DAYS="30"
INCREMENTAL_BACKUP="Y"  # 是否使用增量备份

# --- 自动化配置 ---
BACKUP_INTERVAL_HOURS="24"  # 备份间隔（小时）
RUN_NOW="Y"

# --- 高级配置 ---
DISK_SPACE_THRESHOLD="85"  # 磁盘使用率阈值(%)
MAX_RETRY_ATTEMPTS="3"     # 网络操作最大重试次数
LOAD_THRESHOLD_MULTIPLIER="1.5"  # 负载阈值倍数
MEMORY_THRESHOLD="80"      # 内存使用率阈值(%)
RSYNC_BANDWIDTH_LIMIT=""   # rsync带宽限制(KB/s)，空值表示不限制

# ====================================================================
# 脚本核心代码
# ====================================================================

# 颜色设置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 标准化路径定义
CONFIG_DIR="/etc/rsync_backup"
CONFIG_FILE="$CONFIG_DIR/config.conf"
SCRIPT_DIR="/usr/local/sbin"
SCRIPT_FILE="$SCRIPT_DIR/rsync_backup.sh"
LOG_DIR="/var/log/rsync_backup"
INSTALL_LOG_FILE="$LOG_DIR/install.log"
BACKUP_LOG_FILE="$LOG_DIR/backup.log"
DEBUG_LOG_FILE="$LOG_DIR/debug.log"

# 日志函数
log() {
    mkdir -p "$LOG_DIR"
    echo -e "$1" | tee -a "$INSTALL_LOG_FILE"
}

# 错误处理函数
error_exit() {
    log "${RED}错误: $1${NC}"
    exit 1
}

# 显示带边框的标题
show_title() {
    local title="$1"
    local width=60
    local padding=$(( (width - ${#title}) / 2 ))
    echo -e "\n${BLUE}$(printf '=%.0s' {1..60})${NC}"
    echo -e "${BLUE}$(printf ' %.0s' {1..$padding})${CYAN}$title${BLUE}$(printf ' %.0s' {1..$padding})${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..60})${NC}\n"
}

# 验证必要条件
check_requirements() {
    if [ "$EUID" -ne 0 ]; then
        error_exit "请使用root权限运行此脚本"
    fi
    
    for cmd in curl ssh rsync tar git hostname jq bc; do
        if ! command -v $cmd &> /dev/null; then
            log "${YELLOW}安装 $cmd...${NC}"
            apt-get update && apt-get install -y $cmd || error_exit "无法安装 $cmd"
        fi
    done
    
    # 检查rsync版本
    rsync_version=$(rsync --version | head -n1 | awk '{print $3}')
    log "${GREEN}✓ rsync版本: $rsync_version${NC}"
}

# 配置验证
validate_config() {
    for param in BOT_TOKEN CHAT_ID TARGET_IP; do
        if [ -z "${!param}" ]; then
            error_exit "配置参数 $param 不能为空"
        fi
    done
    
    if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
        error_exit "SSH端口无效: $SSH_PORT"
    fi
    
    # 验证备份源目录
    for dir in $BACKUP_SOURCE_DIRS; do
        if [ ! -d "$dir" ]; then
            log "${YELLOW}警告: 备份源目录不存在: $dir${NC}"
        fi
    done
}

# 配置收集函数
collect_config() {
    show_title "Rsync备份工具配置向导"
    log "${CYAN}ℹ️ 将加载脚本顶部的预设值作为默认项，可直接回车使用。${NC}\n"

    # Telegram配置
    log "${YELLOW}📱 Telegram 通知配置:${NC}"
    read -p "请输入 Telegram Bot Token [当前: ${BOT_TOKEN:0:8}...]: " INPUT
    BOT_TOKEN=${INPUT:-$BOT_TOKEN}
    while [ -z "$BOT_TOKEN" ]; do
        log "${RED}Bot Token 不能为空${NC}"
        read -p "请输入 Telegram Bot Token: " BOT_TOKEN
    done

    read -p "请输入 Telegram Chat ID [当前: $CHAT_ID]: " INPUT
    CHAT_ID=${INPUT:-$CHAT_ID}
    while [ -z "$CHAT_ID" ]; do
        log "${RED}Chat ID 不能为空${NC}"
        read -p "请输入 Telegram Chat ID: " CHAT_ID
    done
    echo

    # 远程服务器配置
    log "${YELLOW}🌐 远程服务器配置:${NC}"
    read -p "请输入远程服务器IP地址 [当前: $TARGET_IP]: " INPUT
    TARGET_IP=${INPUT:-$TARGET_IP}
    while [ -z "$TARGET_IP" ]; do
        log "${RED}IP地址不能为空${NC}"
        read -p "请输入远程服务器IP地址: " TARGET_IP
    done

    read -p "请输入远程服务器用户名 [默认: $TARGET_USER]: " INPUT
    TARGET_USER=${INPUT:-$TARGET_USER}

    read -p "请输入SSH端口 [默认: $SSH_PORT]: " INPUT
    SSH_PORT=${INPUT:-$SSH_PORT}
    echo

    # 备份源配置
    log "${YELLOW}📁 备份源配置:${NC}"
    log "当前备份目录: $BACKUP_SOURCE_DIRS"
    read -p "是否修改备份目录列表？[y/N]: " MODIFY_DIRS
    if [[ "$MODIFY_DIRS" =~ ^[Yy]$ ]]; then
        read -p "请输入要备份的目录（空格分隔）: " INPUT
        BACKUP_SOURCE_DIRS=${INPUT:-$BACKUP_SOURCE_DIRS}
    fi

    log "当前排除模式: $BACKUP_EXCLUDE_PATTERNS"
    read -p "是否修改排除模式？[y/N]: " MODIFY_EXCLUDE
    if [[ "$MODIFY_EXCLUDE" =~ ^[Yy]$ ]]; then
        read -p "请输入排除模式（空格分隔）: " INPUT
        BACKUP_EXCLUDE_PATTERNS=${INPUT:-$BACKUP_EXCLUDE_PATTERNS}
    fi

    read -p "请输入本地备份目录 [默认: $LOCAL_BACKUP_DIR]: " INPUT
    LOCAL_BACKUP_DIR=${INPUT:-$LOCAL_BACKUP_DIR}

    read -p "是否启用压缩传输？[Y/n]: " INPUT
    ENABLE_COMPRESSION=${INPUT:-$ENABLE_COMPRESSION}

    read -p "是否使用增量备份？[Y/n]: " INPUT
    INCREMENTAL_BACKUP=${INPUT:-$INCREMENTAL_BACKUP}
    echo

    # 远程目录配置
    log "${YELLOW}🗄️ 远程存储配置:${NC}"
    read -p "请输入远程基础备份目录 [默认: $TARGET_BASE_DIR]: " INPUT
    TARGET_BASE_DIR=${INPUT:-$TARGET_BASE_DIR}

    HOSTNAME=$(hostname)
    if [ -z "$REMOTE_DIR_NAME" ]; then
        REMOTE_DIR_NAME="$HOSTNAME"
        log "\n${CYAN}ℹ️ 本机将在远程创建目录: $TARGET_BASE_DIR/$REMOTE_DIR_NAME${NC}"
        read -p "是否使用此默认目录名 '$REMOTE_DIR_NAME'? [Y/n]: " USE_DEFAULT_HOSTNAME
        if [[ "$USE_DEFAULT_HOSTNAME" =~ ^[Nn]$ ]]; then
            read -p "请输入自定义目录名: " CUSTOM_HOSTNAME
            while [ -z "$CUSTOM_HOSTNAME" ]; do
                log "${RED}目录名不能为空${NC}"
                read -p "请输入自定义目录名: " CUSTOM_HOSTNAME
            done
            REMOTE_DIR_NAME="$CUSTOM_HOSTNAME"
        fi
    fi

    FULL_REMOTE_PATH="$TARGET_BASE_DIR/$REMOTE_DIR_NAME"
    log "${GREEN}✓ 远程完整路径: $FULL_REMOTE_PATH${NC}"
    echo

    # 保留策略配置
    log "${YELLOW}🕒 备份保留策略:${NC}"
    read -p "请输入本地备份保留天数 [默认: $LOCAL_BACKUP_KEEP_DAYS]: " INPUT
    LOCAL_BACKUP_KEEP_DAYS=${INPUT:-$LOCAL_BACKUP_KEEP_DAYS}

    read -p "请输入远程备份保留天数 [默认: $REMOTE_BACKUP_KEEP_DAYS]: " INPUT
    REMOTE_BACKUP_KEEP_DAYS=${INPUT:-$REMOTE_BACKUP_KEEP_DAYS}
    echo

    # 自动执行间隔配置
    log "${YELLOW}⏰ 自动执行配置:${NC}"
    read -p "请输入备份间隔小时数 (1-168) [默认: $BACKUP_INTERVAL_HOURS]: " INPUT
    BACKUP_INTERVAL_HOURS=${INPUT:-$BACKUP_INTERVAL_HOURS}
    while [[ ! "$BACKUP_INTERVAL_HOURS" =~ ^[0-9]+$ ]] || [ "$BACKUP_INTERVAL_HOURS" -lt 1 ] || [ "$BACKUP_INTERVAL_HOURS" -gt 168 ]; do
        log "${RED}请输入1-168之间的数字${NC}"
        read -p "请输入备份间隔小时数 [默认: 24]: " INPUT
        BACKUP_INTERVAL_HOURS=${INPUT:-24}
    done

    # 带宽限制配置
    read -p "是否设置rsync带宽限制？[y/N]: " SET_BANDWIDTH
    if [[ "$SET_BANDWIDTH" =~ ^[Yy]$ ]]; then
        read -p "请输入带宽限制(KB/s) [默认: 无限制]: " INPUT
        RSYNC_BANDWIDTH_LIMIT=${INPUT}
    fi

    read -p "是否需要立即执行一次备份测试？[Y/n]: " INPUT
    RUN_NOW=${INPUT:-$RUN_NOW}
    echo

    # 验证配置
    validate_config

    # 配置预览
    show_title "配置预览"
    log "${CYAN}远程服务器:${NC} $TARGET_USER@$TARGET_IP:$SSH_PORT"
    log "${CYAN}远程路径:${NC} $FULL_REMOTE_PATH"
    log "${CYAN}本地路径:${NC} $LOCAL_BACKUP_DIR"
    log "${CYAN}备份源:${NC} $BACKUP_SOURCE_DIRS"
    log "${CYAN}保留策略:${NC} 本地${LOCAL_BACKUP_KEEP_DAYS}天，远程${REMOTE_BACKUP_KEEP_DAYS}天"
    log "${CYAN}自动执行:${NC} 每${BACKUP_INTERVAL_HOURS}小时一次"
    log "${CYAN}压缩传输:${NC} $ENABLE_COMPRESSION"
    log "${CYAN}增量备份:${NC} $INCREMENTAL_BACKUP"
    if [ -n "$RSYNC_BANDWIDTH_LIMIT" ]; then
        log "${CYAN}带宽限制:${NC} ${RSYNC_BANDWIDTH_LIMIT}KB/s"
    fi
    echo

    read -p "确认以上配置并继续？[Y/n]: " CONFIRM_CONFIG
    if [[ "$CONFIRM_CONFIG" =~ ^[Nn]$ ]]; then
        log "\n${YELLOW}配置已取消，请重新运行脚本进行配置${NC}"
        exit 0
    fi
}

# SSH密钥配置
setup_ssh_key() {
    show_title "SSH密钥配置 (Ed25519)"
    
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    
    if [ ! -f "/root/.ssh/id_ed25519" ]; then
        log "${YELLOW}生成新的 Ed25519 SSH 密钥...${NC}"
        ssh-keygen -t ed25519 -N "" -f /root/.ssh/id_ed25519 -q
    fi
    
    log "${YELLOW}请将以下公钥添加到远程服务器的 ~/.ssh/authorized_keys 文件中:${NC}"
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    cat /root/.ssh/id_ed25519.pub
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    read -p "已将公钥添加到远程服务器？继续测试连接... [Y/n]: " SSH_OK
    if [[ ! "$SSH_OK" =~ ^[Nn]$ ]]; then
        log "${YELLOW}测试SSH连接...${NC}"
        if ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/root/.ssh/known_hosts "$TARGET_USER@$TARGET_IP" "echo 'SSH连接测试成功'" 2>/dev/null; then
            log "${GREEN}✓ SSH连接测试成功！${NC}\n"
            
            log "${YELLOW}创建远程目录结构...${NC}"
            ssh -p "$SSH_PORT" "$TARGET_USER@$TARGET_IP" "mkdir -p $FULL_REMOTE_PATH/current $FULL_REMOTE_PATH/history $FULL_REMOTE_PATH/logs" 2>/dev/null
            
            if [ $? -eq 0 ]; then
                log "${GREEN}✓ 远程目录创建成功: $FULL_REMOTE_PATH${NC}\n"
            else
                log "${YELLOW}⚠ 远程目录创建可能失败，请手动检查${NC}\n"
            fi
        else
            log "${RED}✗ SSH连接失败。请检查配置后重试。${NC}"
            read -p "继续安装（将跳过远程备份）？[y/N]: " CONTINUE
            if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
}

# 测试Telegram通知
test_telegram() {
    show_title "Telegram通知测试"
    response=$(curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="🚀 *Rsync备份工具安装测试*

- 您正在使用Rsync备份工具
- 时间: \`$(date '+%F %T')\`
- 主机: \`$(hostname)\`
- 备份源: \`$(echo $BACKUP_SOURCE_DIRS | tr ' ' ', ')\`" \
        -d parse_mode="Markdown")
    if [[ $response == *"\"ok\":true"* ]]; then
        log "${GREEN}✓ Telegram通知测试成功！${NC}\n"
    else
        log "${RED}✗ Telegram通知发送失败，请检查配置${NC}\n"
    fi
}

# 创建配置文件和主脚本
create_script() {
    show_title "创建备份脚本"
    
    mkdir -p "$LOCAL_BACKUP_DIR" "$CONFIG_DIR" "$SCRIPT_DIR" "$LOG_DIR"
    
    log "${YELLOW}创建配置文件...${NC}"
    cat > "$CONFIG_FILE" << EOF
#!/bin/bash
# Rsync备份配置文件 (由安装脚本自动生成于: $(date '+%F %T'))

# Telegram配置
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"

# 远程服务器配置
TARGET_IP="$TARGET_IP"
TARGET_USER="$TARGET_USER"
SSH_PORT="$SSH_PORT"
TARGET_BASE_DIR="$TARGET_BASE_DIR"
REMOTE_DIR_NAME="$REMOTE_DIR_NAME"

# 备份配置
BACKUP_SOURCE_DIRS="$BACKUP_SOURCE_DIRS"
BACKUP_EXCLUDE_PATTERNS="$BACKUP_EXCLUDE_PATTERNS"
LOCAL_BACKUP_DIR="$LOCAL_BACKUP_DIR"
ENABLE_COMPRESSION="$ENABLE_COMPRESSION"
INCREMENTAL_BACKUP="$INCREMENTAL_BACKUP"
RSYNC_BANDWIDTH_LIMIT="$RSYNC_BANDWIDTH_LIMIT"

# 本地配置
HOSTNAME=\$(hostname)

# 保留策略
LOCAL_BACKUP_KEEP_DAYS=$LOCAL_BACKUP_KEEP_DAYS
REMOTE_BACKUP_KEEP_DAYS=$REMOTE_BACKUP_KEEP_DAYS

# 执行配置
BACKUP_INTERVAL_HOURS=$BACKUP_INTERVAL_HOURS

# 高级配置
DISK_SPACE_THRESHOLD="$DISK_SPACE_THRESHOLD"
MAX_RETRY_ATTEMPTS="$MAX_RETRY_ATTEMPTS"
LOAD_THRESHOLD_MULTIPLIER="$LOAD_THRESHOLD_MULTIPLIER"
MEMORY_THRESHOLD="$MEMORY_THRESHOLD"

# 日志文件
LOG_FILE="$BACKUP_LOG_FILE"
DEBUG_LOG="$DEBUG_LOG_FILE"
EOF

    log "${YELLOW}创建主备份脚本...${NC}"
    cat > "$SCRIPT_FILE" << 'EOF'
#!/bin/bash

# 加载配置
source "/etc/rsync_backup/config.conf" || { echo "配置文件未找到"; exit 1; }

# 变量设置
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FULL_REMOTE_PATH="$TARGET_BASE_DIR/$REMOTE_DIR_NAME"
LOCK_FILE="/tmp/rsync_backup.lock"
CURRENT_BACKUP_DIR="$LOCAL_BACKUP_DIR/current"
HISTORY_BACKUP_DIR="$LOCAL_BACKUP_DIR/history/$TIMESTAMP"

# 进程锁
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    echo "备份脚本已在运行"
    exit 1
fi
echo $$ >&200
trap 'flock -u 200' EXIT

# 日志函数
log_info() { 
    echo "$(date '+%F %T') [INFO] $1" | tee -a "$LOG_FILE"
    echo "$(date '+%F %T') [INFO] $1" >> "$DEBUG_LOG"
}
log_error() { 
    echo "$(date '+%F %T') [ERROR] $1" | tee -a "$LOG_FILE"
    echo "$(date '+%F %T') [ERROR] $1" >> "$DEBUG_LOG"
}
log_debug() { 
    echo "$(date '+%F %T') [DEBUG] $1" >> "$DEBUG_LOG"
}

# 重试机制
retry_command() {
    local max_attempts="$MAX_RETRY_ATTEMPTS"
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if eval "$*"; then 
            log_debug "命令执行成功: $*"
            return 0
        fi
        log_info "命令失败，第 $attempt 次重试: $*"
        sleep $((attempt * 3))
        ((attempt++))
    done
    log_error "命令最终失败: $*"
    return 1
}

# 字节格式化
format_bytes() {
    local bytes="$1"
    
    if [ -z "$bytes" ] || ! [[ "$bytes" =~ ^[0-9]+$ ]] || [ "$bytes" -eq 0 ]; then
        echo "0B"; return
    fi
    
    if [ "$bytes" -ge 1073741824 ]; then
        local gb=$((bytes / 1073741824))
        local remainder=$((bytes % 1073741824))
        local decimal=$((remainder * 10 / 1073741824))
        echo "${gb}.${decimal}GB"
    elif [ "$bytes" -ge 1048576 ]; then
        local mb=$((bytes / 1048576))
        local remainder=$((bytes % 1048576))
        local decimal=$((remainder * 10 / 1048576))
        echo "${mb}.${decimal}MB"
    elif [ "$bytes" -ge 1024 ]; then
        local kb=$((bytes / 1024))
        local remainder=$((bytes % 1024))
        local decimal=$((remainder * 10 / 1024))
        echo "${kb}.${decimal}KB"
    else
        echo "${bytes}B"
    fi
}

# 磁盘空间检查
check_disk_space() {
    local disk_info=$(df "$LOCAL_BACKUP_DIR" 2>/dev/null | tail -n 1)
    if [ -z "$disk_info" ]; then
        log_error "无法获取磁盘信息"
        return 1
    fi
    
    local disk_usage=$(echo "$disk_info" | awk '{print $5}' | sed 's/%//')
    if ! [[ "$disk_usage" =~ ^[0-9]+$ ]]; then
        log_error "无法解析磁盘使用率"
        return 1
    fi
    
    if [ "$disk_usage" -gt "$DISK_SPACE_THRESHOLD" ]; then
        log_error "磁盘空间不足: ${disk_usage}% > ${DISK_SPACE_THRESHOLD}%"
        send_telegram_notification "备份失败" "磁盘使用率过高 (${disk_usage}%)" "❌"
        return 1
    fi
    
    log_debug "磁盘使用率检查通过: ${disk_usage}%"
}

# 获取系统状态信息
get_system_status() {
    local system_load=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//' | cut -d',' -f1)
    local memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}' 2>/dev/null || echo "0")
    local cpu_cores=$(nproc 2>/dev/null || echo "1")
    local load_threshold=$(echo "$cpu_cores * $LOAD_THRESHOLD_MULTIPLIER" | bc -l 2>/dev/null || echo "$cpu_cores")
    
    echo "$system_load $memory_usage $load_threshold"
}

# 检查是否需要显示系统状态
should_show_system_status() {
    local load="$1"
    local memory="$2"
    local load_threshold="$3"
    
    local load_high=$(echo "$load > $load_threshold" | bc -l 2>/dev/null || echo "0")
    local memory_high=0
    
    if [[ "$memory" =~ ^[0-9]+$ ]] && [ "$memory" -gt "$MEMORY_THRESHOLD" ]; then
        memory_high=1
    fi
    
    if [ "$load_high" = "1" ] || [ "$memory_high" = "1" ]; then
        return 0
    else
        return 1
    fi
}

# Telegram通知
send_telegram_notification() {
    local title="$1"
    local message="$2"
    local emoji="$3"
    local formatted_message=$(echo -e "$message" | sed 's/^/- /')
    local current_time=$(date '+%F %T')
    local server_info="$REMOTE_DIR_NAME"
    
    # 获取系统状态
    read -r system_load memory_usage load_threshold <<< "$(get_system_status)"
    
    local system_info=""
    if should_show_system_status "$system_load" "$memory_usage" "$load_threshold"; then
        local cpu_cores=$(nproc 2>/dev/null || echo "1")
        system_info="\n- 负载: \`${system_load}\` (${cpu_cores}核) $(echo "$system_load > $load_threshold" | bc -l 2>/dev/null | grep -q 1 && echo "⚠️" || echo "")"
        system_info="${system_info}\n- 内存: \`${memory_usage}%\` $([ "$memory_usage" -gt "$MEMORY_THRESHOLD" ] && echo "⚠️" || echo "")"
    fi
    
    local payload="{\"chat_id\":\"$CHAT_ID\",\"text\":\"${emoji} *${title}* | \`$server_info\`\n\n${formatted_message}${system_info}\n- 时间: \`${current_time}\`\",\"parse_mode\":\"Markdown\"}"
    
    retry_command "curl -s -X POST 'https://api.telegram.org/bot$BOT_TOKEN/sendMessage' -H 'Content-Type: application/json' -d '$payload' >/dev/null"
}

# systemd定时器设置
setup_systemd_timer() {
    local service_file="/etc/systemd/system/rsync-backup.service"
    local timer_file="/etc/systemd/system/rsync-backup.timer"
    
    if [ -f "$timer_file" ]; then
        systemctl stop rsync-backup.timer 2>/dev/null || true
    fi

    cat > "$service_file" << EOFSERVICE
[Unit]
Description=Rsync Backup Service
After=network.target
[Service]
Type=oneshot
ExecStart=$(realpath "$0")
Environment="SYSTEMD_TIMER=1"
WorkingDirectory=/root
[Install]
WantedBy=multi-user.target
EOFSERVICE
    
    cat > "$timer_file" << EOFTIMER
[Unit]
Description=Run Rsync Backup Every $BACKUP_INTERVAL_HOURS Hours
[Timer]
OnActiveSec=30min
OnUnitActiveSec=${BACKUP_INTERVAL_HOURS}h
RandomizedDelaySec=1h
Persistent=true
[Install]
WantedBy=timers.target
EOFTIMER
    
    systemctl daemon-reload
    systemctl enable rsync-backup.timer
    systemctl start rsync-backup.timer
    
    local current_time=$(date +%s)
    local next_run_time=$((current_time + 1800))  # 当前时间 + 30分钟
    local next_run_cst=$(date -d "@$next_run_time" '+%Y年%m月%d日 %H:%M (CST)')
    
    log_info "定时器已设置: 30分钟后首次运行，之后每${BACKUP_INTERVAL_HOURS}小时执行一次"
    log_info "计算得出的下次运行时间: $next_run_cst"
    
    send_telegram_notification "定时任务更新" "频率: 30分钟后首次运行，之后每${BACKUP_INTERVAL_HOURS}小时一次\n下次运行: ${next_run_cst}" "⏰"
}

# 构建rsync命令
build_rsync_command() {
    local source="$1"
    local destination="$2"
    local rsync_opts="-av --stats --human-readable"
    
    # 添加压缩选项
    if [[ "$ENABLE_COMPRESSION" =~ ^[Yy]$ ]]; then
        rsync_opts="$rsync_opts -z"
    fi
    
    # 添加带宽限制
    if [ -n "$RSYNC_BANDWIDTH_LIMIT" ] && [[ "$RSYNC_BANDWIDTH_LIMIT" =~ ^[0-9]+$ ]]; then
        rsync_opts="$rsync_opts --bwlimit=$RSYNC_BANDWIDTH_LIMIT"
    fi
    
    # 添加增量备份选项
    if [[ "$INCREMENTAL_BACKUP" =~ ^[Yy]$ ]] && [ -d "$CURRENT_BACKUP_DIR" ]; then
        rsync_opts="$rsync_opts --link-dest=$CURRENT_BACKUP_DIR"
    fi
    
    # 添加排除模式
    for pattern in $BACKUP_EXCLUDE_PATTERNS; do
        rsync_opts="$rsync_opts --exclude=$pattern"
    done
    
    # SSH选项
    rsync_opts="$rsync_opts -e 'ssh -p $SSH_PORT -o ConnectTimeout=30 -o BatchMode=yes'"
    
    echo "rsync $rsync_opts $source $destination"
}

# 执行本地备份
perform_local_backup() {
    local start_time=$(date +%s)
    log_info "开始本地备份..."
    send_telegram_notification "开始本地备份" "任务已启动" "🔄"
    
    check_disk_space || return 1
    
    # 创建历史备份目录
    mkdir -p "$HISTORY_BACKUP_DIR"
    
    local total_size=0
    local backup_success=true
    
    # 备份每个源目录
    for source_dir in $BACKUP_SOURCE_DIRS; do
        if [ ! -d "$source_dir" ]; then
            log_error "源目录不存在: $source_dir"
            continue
        fi
        
        log_info "备份目录: $source_dir"
        local dest_dir="$HISTORY_BACKUP_DIR$(dirname $source_dir)"
        mkdir -p "$dest_dir"
        
        local rsync_cmd=$(build_rsync_command "$source_dir/" "$dest_dir/")
        log_debug "执行命令: $rsync_cmd"
        
        if eval "$rsync_cmd" 2>&1 | tee -a "$DEBUG_LOG"; then
            log_info "✓ 成功备份: $source_dir"
        else
            log_error "✗ 备份失败: $source_dir"
            backup_success=false
        fi
    done
    
    if [ "$backup_success" = true ]; then
        # 更新当前备份链接
        rm -rf "$CURRENT_BACKUP_DIR"
        ln -sf "$HISTORY_BACKUP_DIR" "$CURRENT_BACKUP_DIR"
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # 计算备份大小
        local backup_size_bytes=$(du -sb "$HISTORY_BACKUP_DIR" 2>/dev/null | cut -f1 || echo "0")
        local backup_size=$(format_bytes "$backup_size_bytes")
        
        log_info "本地备份完成: $backup_size, 耗时: ${duration}s"
        send_telegram_notification "本地备份完成" "备份大小: \`$backup_size\`\n备份耗时: \`${duration}秒\`" "💾"
        return 0
    else
        send_telegram_notification "本地备份失败" "部分目录备份失败，请检查日志" "❌"
        return 1
    fi
}

# 清理本地旧备份
cleanup_local() {
    log_info "清理本地旧备份..."
    find "$LOCAL_BACKUP_DIR/history" -maxdepth 1 -type d -mtime +$LOCAL_BACKUP_KEEP_DAYS -exec rm -rf {} \; 2>/dev/null || true
}

# 上传到远程服务器
upload_to_remote() {
    log_info "开始上传到远程服务器..."
    send_telegram_notification "开始远程同步" "任务已启动" "⬆️"
    
    if ! retry_command "ssh -p '$SSH_PORT' -o ConnectTimeout=10 -o BatchMode=yes '$TARGET_USER@$TARGET_IP' 'echo 连接测试' >/dev/null"; then
        log_error "无法连接到远程服务器"
        send_telegram_notification "远程同步失败" "原因: 无法连接到远程服务器" "⚠️"
        return 1
    fi
    
    local upload_start_time=$(date +%s)
    
    # 同步当前备份到远程
    local remote_current="$TARGET_USER@$TARGET_IP:$FULL_REMOTE_PATH/current/"
    local rsync_cmd=$(build_rsync_command "$CURRENT_BACKUP_DIR/" "$remote_current")
    
    if eval "$rsync_cmd" 2>&1 | tee -a "$DEBUG_LOG"; then
        # 在远程创建历史备份
        ssh -p "$SSH_PORT" "$TARGET_USER@$TARGET_IP" "
            cd $FULL_REMOTE_PATH
            if [ ! -d history/$TIMESTAMP ]; then
                cp -al current history/$TIMESTAMP 2>/dev/null || rsync -a current/ history/$TIMESTAMP/
            fi
        "
        
        local upload_end_time=$(date +%s)
        local upload_duration=$((upload_end_time - upload_start_time))
        
        log_info "远程同步完成"
        send_telegram_notification "远程同步成功" "同步耗时: \`${upload_duration}秒\`" "✅"
        
        # 清理远程旧备份
        ssh -p "$SSH_PORT" "$TARGET_USER@$TARGET_IP" "find $FULL_REMOTE_PATH/history -maxdepth 1 -type d -mtime +$REMOTE_BACKUP_KEEP_DAYS -exec rm -rf {} \; 2>/dev/null || true"
        
        return 0
    else
        log_error "远程同步失败"
        send_telegram_notification "远程同步失败" "错误: rsync传输失败" "❌"
        return 1
    fi
}

# 主执行流程
if [ -z "$SYSTEMD_TIMER" ]; then
    setup_systemd_timer
fi

# 执行备份流程
if perform_local_backup; then
    cleanup_local
    upload_to_remote
fi

log_info "Rsync备份操作完成"

# 统计信息
LOCAL_BACKUP_COUNT=$(find "$LOCAL_BACKUP_DIR/history" -maxdepth 1 -type d | wc -l)
LOCAL_BACKUP_COUNT=$((LOCAL_BACKUP_COUNT - 1))  # 减去history目录本身

if [ "$LOCAL_BACKUP_COUNT" -gt 0 ]; then
    LOCAL_TOTAL_SIZE_BYTES=$(du -sb "$LOCAL_BACKUP_DIR/history" 2>/dev/null | cut -f1 || echo "0")
else
    LOCAL_TOTAL_SIZE_BYTES=0
fi

LOCAL_TOTAL_SIZE=$(format_bytes "$LOCAL_TOTAL_SIZE_BYTES")

# 获取当前备份大小
if [ -d "$CURRENT_BACKUP_DIR" ]; then
    CURRENT_BACKUP_SIZE_BYTES=$(du -sb "$CURRENT_BACKUP_DIR" 2>/dev/null | cut -f1 || echo "0")
    CURRENT_BACKUP_SIZE=$(format_bytes "$CURRENT_BACKUP_SIZE_BYTES")
else
    CURRENT_BACKUP_SIZE="N/A"
fi

# 获取磁盘使用率
DISK_USAGE=$(df "$LOCAL_BACKUP_DIR" 2>/dev/null | tail -n 1 | awk '{print $5}' | sed 's/%//' || echo "N/A")

REPORT_MESSAGE="当前备份大小: \`${CURRENT_BACKUP_SIZE}\`\n本地备份数量: \`${LOCAL_BACKUP_COUNT}\`个\n本地总大小: \`${LOCAL_TOTAL_SIZE}\`\n磁盘使用率: \`${DISK_USAGE}%\`"

# 获取远程统计信息
if ssh -p "$SSH_PORT" -o ConnectTimeout=5 -o BatchMode=yes "$TARGET_USER@$TARGET_IP" "true" >/dev/null 2>&1; then
    REMOTE_STATS=$(ssh -p "$SSH_PORT" "$TARGET_USER@$TARGET_IP" "
        if [ -d '$FULL_REMOTE_PATH/history' ]; then
            cd '$FULL_REMOTE_PATH/history'
            COUNT=\$(find . -maxdepth 1 -type d | wc -l)
            COUNT=\$((COUNT - 1))
            if [ \"\$COUNT\" -gt 0 ]; then
                TOTAL_BYTES=\$(du -sb . 2>/dev/null | cut -f1 || echo '0')
            else
                TOTAL_BYTES=0
            fi
            echo \"\$COUNT \$TOTAL_BYTES\"
        else
            echo '0 0'
        fi
    " 2>/dev/null)
    
    read -r REMOTE_COUNT REMOTE_SIZE_BYTES <<< "$REMOTE_STATS"
    REMOTE_SIZE_FORMATTED=$(format_bytes "${REMOTE_SIZE_BYTES:-0}")
    
    REPORT_MESSAGE="${REPORT_MESSAGE}\n远程备份数量: \`${REMOTE_COUNT:-0}\`个\n远程总大小: \`${REMOTE_SIZE_FORMATTED}\`"
else
    REPORT_MESSAGE="${REPORT_MESSAGE}\n远程服务器无法连接"
fi

send_telegram_notification "Rsync备份操作完成" "$REPORT_MESSAGE" "✅"
EOF

    chmod +x "$SCRIPT_FILE"
    chmod 600 "$CONFIG_FILE"
    log "${GREEN}✓ 脚本创建完成！${NC}\n"
}

# 主流程
main() {
    clear
    show_title "Rsync备份工具安装向导"
    check_requirements
    collect_config
    setup_ssh_key
    test_telegram
    create_script
    
    if [[ "$RUN_NOW" =~ ^[Yy]$ ]]; then
        log "${YELLOW}正在执行首次测试运行...${NC}"
        bash "$SCRIPT_FILE"
    fi
    
    show_title "安装完成"
    log "${GREEN}✓ Rsync备份工具安装成功！${NC}\n"
    log "${CYAN}配置文件位置:${NC} $CONFIG_FILE"
    log "${CYAN}主脚本位置:${NC} $SCRIPT_FILE"
    log "${CYAN}本地备份目录:${NC} $LOCAL_BACKUP_DIR"
    echo
    log "${YELLOW}请使用以下命令管理定时任务:${NC}"
    log "  - 查看状态: ${CYAN}sudo systemctl status rsync-backup.timer${NC}"
    log "  - 立即运行: ${CYAN}sudo systemctl start rsync-backup.service${NC}"
    log "  - 停止/禁用: ${CYAN}sudo systemctl disable rsync-backup.timer${NC}"
    log "  - 查看日志: ${CYAN}sudo journalctl -u rsync-backup.service -f${NC}"
    echo
    log "${BLUE}备份特性说明:${NC}"
    log "  - 支持增量备份，节省存储空间"
    log "  - 自动清理过期备份"
    log "  - 实时系统监控和Telegram通知"
    log "  - 支持多目录备份和排除规则"
    log "  - 带宽限制和压缩传输"
    echo
    log "${BLUE}如需重新配置，编辑配置文件后手动运行一次主脚本即可自动更新定时器。${NC}"
    echo
}

# 运行主程序
main
