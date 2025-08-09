#!/bin/bash

# Cloudflare DNS 记录管理脚本
# 支持批量添加、删除、查询 DNS 记录
# 作者: VPS脚本合集
# 版本: 1.0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置文件路径
CONFIG_FILE="$HOME/.cfdns_config"

# 显示帮助信息
show_help() {
    echo -e "${BLUE}Cloudflare DNS 记录管理脚本${NC}"
    echo -e "${GREEN}使用方法:${NC}"
    echo "  $0 [选项] [参数]"
    echo ""
    echo -e "${GREEN}选项:${NC}"
    echo "  -h, --help          显示帮助信息"
    echo "  -c, --config        配置 Cloudflare API 信息"
    echo "  -l, --list          列出所有 DNS 记录"
    echo "  -a, --add           添加 DNS 记录"
    echo "  -d, --delete        删除 DNS 记录"
    echo "  -b, --batch         批量操作模式"
    echo "  -z, --zone          指定域名区域"
    echo ""
    echo -e "${GREEN}示例:${NC}"
    echo "  $0 -c                           # 配置 API 信息"
    echo "  $0 -l -z example.com            # 列出 example.com 的所有记录"
    echo "  $0 -a -z example.com            # 交互式添加记录"
    echo "  $0 -b add records.txt           # 批量添加记录"
    echo "  $0 -b delete records.txt        # 批量删除记录"
    echo "  $0 -d -z example.com            # 交互式删除记录"
}

# 检查依赖
check_dependencies() {
    local deps=("curl" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "${RED}错误: 缺少依赖 $dep${NC}"
            echo -e "${YELLOW}请安装: sudo apt-get install $dep${NC}"
            exit 1
        fi
    done
}

# 配置 Cloudflare API
config_api() {
    echo -e "${BLUE}配置 Cloudflare API 信息${NC}"
    echo -e "${YELLOW}请在 Cloudflare 控制台获取以下信息:${NC}"
    echo "1. 登录 https://dash.cloudflare.com/"
    echo "2. 进入 'My Profile' -> 'API Tokens'"
    echo "3. 创建自定义令牌或使用全局 API 密钥"
    echo ""
    
    read -p "请输入您的 Cloudflare 邮箱: " email
    read -p "请输入您的 Global API Key 或 API Token: " -s api_key
    echo ""
    read -p "请输入默认域名 (可选): " default_zone
    
    # 保存配置
    cat > "$CONFIG_FILE" << EOF
CF_EMAIL="$email"
CF_API_KEY="$api_key"
DEFAULT_ZONE="$default_zone"
EOF
    
    chmod 600 "$CONFIG_FILE"
    echo -e "${GREEN}配置已保存到 $CONFIG_FILE${NC}"
}

# 加载配置
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}错误: 配置文件不存在${NC}"
        echo -e "${YELLOW}请先运行: $0 -c${NC}"
        exit 1
    fi
    source "$CONFIG_FILE"
    
    if [[ -z "$CF_EMAIL" || -z "$CF_API_KEY" ]]; then
        echo -e "${RED}错误: 配置信息不完整${NC}"
        echo -e "${YELLOW}请重新配置: $0 -c${NC}"
        exit 1
    fi
}

# 获取区域 ID
get_zone_id() {
    local zone_name="$1"
    local response
    
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" \
        -H "X-Auth-Email: $CF_EMAIL" \
        -H "X-Auth-Key: $CF_API_KEY" \
        -H "Content-Type: application/json")
    
    local success=$(echo "$response" | jq -r '.success')
    if [[ "$success" != "true" ]]; then
        echo -e "${RED}错误: 无法获取区域信息${NC}"
        echo "$response" | jq -r '.errors[].message' 2>/dev/null
        return 1
    fi
    
    local zone_id=$(echo "$response" | jq -r '.result[0].id')
    if [[ "$zone_id" == "null" ]]; then
        echo -e "${RED}错误: 找不到域名 $zone_name${NC}"
        return 1
    fi
    
    echo "$zone_id"
}

# 列出 DNS 记录
list_records() {
    local zone_name="$1"
    local zone_id
    
    zone_id=$(get_zone_id "$zone_name")
    [[ $? -ne 0 ]] && return 1
    
    echo -e "${BLUE}获取 $zone_name 的 DNS 记录...${NC}"
    
    local response
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
        -H "X-Auth-Email: $CF_EMAIL" \
        -H "X-Auth-Key: $CF_API_KEY" \
        -H "Content-Type: application/json")
    
    local success=$(echo "$response" | jq -r '.success')
    if [[ "$success" != "true" ]]; then
        echo -e "${RED}错误: 无法获取 DNS 记录${NC}"
        return 1
    fi
    
    echo -e "${GREEN}DNS 记录列表:${NC}"
    printf "%-5s %-20s %-10s %-30s %-10s\n" "ID" "名称" "类型" "内容" "TTL"
    echo "────────────────────────────────────────────────────────────────────────────"
    
    echo "$response" | jq -r '.result[] | [.id[0:8], .name, .type, .content, .ttl] | @tsv' | \
    while IFS=$'\t' read -r id name type content ttl; do
        printf "%-5s %-20s %-10s %-30s %-10s\n" "$id" "$name" "$type" "$content" "$ttl"
    done
}

# 添加 DNS 记录
add_record() {
    local zone_name="$1"
    local record_name="$2"
    local record_type="$3"
    local record_content="$4"
    local record_ttl="${5:-1}"
    local zone_id
    
    zone_id=$(get_zone_id "$zone_name")
    [[ $? -ne 0 ]] && return 1
    
    echo -e "${BLUE}添加 DNS 记录: $record_name.$zone_name${NC}"
    
    local data
    data=$(jq -n \
        --arg name "$record_name" \
        --arg type "$record_type" \
        --arg content "$record_content" \
        --arg ttl "$record_ttl" \
        '{
            "name": $name,
            "type": $type,
            "content": $content,
            "ttl": ($ttl | tonumber)
        }')
    
    local response
    response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
        -H "X-Auth-Email: $CF_EMAIL" \
        -H "X-Auth-Key: $CF_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$data")
    
    local success=$(echo "$response" | jq -r '.success')
    if [[ "$success" == "true" ]]; then
        echo -e "${GREEN}✓ 记录添加成功${NC}"
        local record_id=$(echo "$response" | jq -r '.result.id')
        echo -e "${YELLOW}记录 ID: $record_id${NC}"
    else
        echo -e "${RED}✗ 记录添加失败${NC}"
        echo "$response" | jq -r '.errors[].message' 2>/dev/null
        return 1
    fi
}

# 交互式添加记录
interactive_add() {
    local zone_name="$1"
    
    echo -e "${BLUE}交互式添加 DNS 记录${NC}"
    echo -e "${YELLOW}域名: $zone_name${NC}"
    echo ""
    
    read -p "记录名称 (如: www, api, @): " record_name
    echo "记录类型:"
    echo "  1) A (IPv4 地址)"
    echo "  2) AAAA (IPv6 地址)"
    echo "  3) CNAME (别名)"
    echo "  4) MX (邮件交换)"
    echo "  5) TXT (文本记录)"
    read -p "请选择记录类型 (1-5): " type_choice
    
    case $type_choice in
        1) record_type="A" ;;
        2) record_type="AAAA" ;;
        3) record_type="CNAME" ;;
        4) record_type="MX" ;;
        5) record_type="TXT" ;;
        *) echo -e "${RED}无效选择${NC}"; return 1 ;;
    esac
    
    read -p "记录内容: " record_content
    read -p "TTL (秒，默认为1即自动): " record_ttl
    record_ttl=${record_ttl:-1}
    
    add_record "$zone_name" "$record_name" "$record_type" "$record_content" "$record_ttl"
}

# 批量删除记录
batch_delete() {
    local file="$1"
    local zone_name="$2"
    
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}错误: 文件 $file 不存在${NC}"
        return 1
    fi
    
    echo -e "${BLUE}批量删除 DNS 记录${NC}"
    echo -e "${YELLOW}文件: $file${NC}"
    echo -e "${YELLOW}域名: $zone_name${NC}"
    echo ""
    
    local count=0
    local success=0
    
    while IFS=',' read -r identifier type || [[ -n "$identifier" ]]; do
        # 跳过注释行和空行
        [[ "$identifier" =~ ^#.*$ ]] && continue
        [[ -z "$identifier" ]] && continue
        
        # 去除空格
        identifier=$(echo "$identifier" | xargs)
        type=$(echo "${type:-}" | xargs)
        
        ((count++))
        
        # 如果 identifier 看起来像记录 ID (8位或更长的字母数字)
        if [[ "$identifier" =~ ^[a-zA-Z0-9]{8,}$ ]]; then
            echo -e "${YELLOW}[$count] 删除记录 ID: $identifier${NC}"
            if delete_record "$zone_name" "$identifier"; then
                ((success++))
            fi
        else
            # 否则按名称和类型查找记录
            echo -e "${YELLOW}[$count] 查找并删除记录: $identifier (类型: ${type:-所有})${NC}"
            if delete_record_by_name "$zone_name" "$identifier" "$type"; then
                ((success++))
            fi
        fi
        
        sleep 1  # 避免 API 限制
    done < "$file"
    
    echo ""
    echo -e "${GREEN}批量删除完成${NC}"
    echo -e "${YELLOW}总计: $count 条记录，成功: $success 条${NC}"
}

# 根据名称删除记录
delete_record_by_name() {
    local zone_name="$1"
    local record_name="$2"
    local record_type="$3"
    local zone_id
    
    zone_id=$(get_zone_id "$zone_name")
    [[ $? -ne 0 ]] && return 1
    
    # 构建查询参数
    local query_params="name=$record_name"
    if [[ -n "$record_type" ]]; then
        query_params="$query_params&type=$record_type"
    fi
    
    # 获取匹配的记录
    local response
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?$query_params" \
        -H "X-Auth-Email: $CF_EMAIL" \
        -H "X-Auth-Key: $CF_API_KEY" \
        -H "Content-Type: application/json")
    
    local success=$(echo "$response" | jq -r '.success')
    if [[ "$success" != "true" ]]; then
        echo -e "${RED}✗ 查询记录失败${NC}"
        return 1
    fi
    
    local records=$(echo "$response" | jq -r '.result[]')
    if [[ -z "$records" || "$records" == "null" ]]; then
        echo -e "${YELLOW}  未找到匹配的记录${NC}"
        return 1
    fi
    
    # 删除所有匹配的记录
    local deleted=0
    echo "$response" | jq -r '.result[].id' | while read -r record_id; do
        if delete_record "$zone_name" "$record_id"; then
            ((deleted++))
        fi
        sleep 0.5
    done
    
    if [[ $deleted -gt 0 ]]; then
        echo -e "${GREEN}  删除了 $deleted 条匹配记录${NC}"
        return 0
    else
        return 1
    fi
}

# 批量添加记录
batch_add() {
    local file="$1"
    local zone_name="$2"
    
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}错误: 文件 $file 不存在${NC}"
        return 1
    fi
    
    echo -e "${BLUE}批量添加 DNS 记录${NC}"
    echo -e "${YELLOW}文件: $file${NC}"
    echo -e "${YELLOW}域名: $zone_name${NC}"
    echo ""
    
    local count=0
    local success=0
    
    while IFS=',' read -r name type content ttl || [[ -n "$name" ]]; do
        # 跳过注释行和空行
        [[ "$name" =~ ^#.*$ ]] && continue
        [[ -z "$name" ]] && continue
        
        # 去除空格
        name=$(echo "$name" | xargs)
        type=$(echo "$type" | xargs)
        content=$(echo "$content" | xargs)
        ttl=$(echo "${ttl:-1}" | xargs)
        
        ((count++))
        echo -e "${YELLOW}[$count] 添加记录: $name.$zone_name${NC}"
        
        if add_record "$zone_name" "$name" "$type" "$content" "$ttl"; then
            ((success++))
        fi
        
        sleep 1  # 避免 API 限制
    done < "$file"
    
    echo ""
    echo -e "${GREEN}批量操作完成${NC}"
    echo -e "${YELLOW}总计: $count 条记录，成功: $success 条${NC}"
}

# 删除 DNS 记录
delete_record() {
    local zone_name="$1"
    local record_id="$2"
    local zone_id
    
    zone_id=$(get_zone_id "$zone_name")
    [[ $? -ne 0 ]] && return 1
    
    echo -e "${BLUE}删除 DNS 记录: $record_id${NC}"
    
    local response
    response=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
        -H "X-Auth-Email: $CF_EMAIL" \
        -H "X-Auth-Key: $CF_API_KEY" \
        -H "Content-Type: application/json")
    
    local success=$(echo "$response" | jq -r '.success')
    if [[ "$success" == "true" ]]; then
        echo -e "${GREEN}✓ 记录删除成功${NC}"
    else
        echo -e "${RED}✗ 记录删除失败${NC}"
        echo "$response" | jq -r '.errors[].message' 2>/dev/null
        return 1
    fi
}

# 交互式删除记录
interactive_delete() {
    local zone_name="$1"
    
    echo -e "${BLUE}交互式删除 DNS 记录${NC}"
    echo -e "${YELLOW}域名: $zone_name${NC}"
    echo ""
    
    # 先列出记录
    list_records "$zone_name"
    echo ""
    
    read -p "请输入要删除的记录 ID (前8位即可): " record_id
    
    if [[ -z "$record_id" ]]; then
        echo -e "${RED}记录 ID 不能为空${NC}"
        return 1
    fi
    
    read -p "确认删除记录 $record_id? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        delete_record "$zone_name" "$record_id"
    else
        echo -e "${YELLOW}操作已取消${NC}"
    fi
}

# 创建示例批量文件
create_example() {
    local file="dns_records_example.csv"
    
    cat > "$file" << 'EOF'
# DNS 记录批量添加示例文件
# 格式: 记录名称,记录类型,记录内容,TTL(可选)
# 注释行以 # 开头

# A 记录示例
www,A,192.168.1.100,3600
api,A,192.168.1.101,3600
ftp,A,192.168.1.102,3600

# CNAME 记录示例
blog,CNAME,www.example.com,3600
mail,CNAME,mail.example.com,3600

# MX 记录示例
@,MX,10 mail.example.com,3600

# TXT 记录示例
@,TXT,"v=spf1 include:_spf.example.com ~all",3600
_dmarc,TXT,"v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com",3600
EOF
    
    echo -e "${GREEN}示例文件已创建: $file${NC}"
    echo -e "${YELLOW}请编辑此文件后使用批量添加功能${NC}"
}

# 主函数
main() {
    # 检查依赖
    check_dependencies
    
    # 解析参数
    local action=""
    local zone_name=""
    local batch_file=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--config)
                config_api
                exit 0
                ;;
            -l|--list)
                action="list"
                shift
                ;;
            -a|--add)
                action="add"
                shift
                ;;
            -d|--delete)
                action="delete"
                shift
                ;;
            -b|--batch)
                action="batch"
                shift
                if [[ $# -gt 0 && $1 == "add" ]]; then
                    action="batch_add"
                    shift
                    if [[ $# -gt 0 ]]; then
                        batch_file="$1"
                        shift
                    fi
                elif [[ $# -gt 0 && $1 == "delete" ]]; then
                    action="batch_delete"
                    shift
                    if [[ $# -gt 0 ]]; then
                        batch_file="$1"
                        shift
                    fi
                elif [[ $# -gt 0 && $1 == "example" ]]; then
                    create_example
                    exit 0
                fi
                ;;
            -z|--zone)
                shift
                if [[ $# -gt 0 ]]; then
                    zone_name="$1"
                    shift
                fi
                ;;
            *)
                echo -e "${RED}未知参数: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 如果没有指定操作，显示帮助
    if [[ -z "$action" ]]; then
        show_help
        exit 0
    fi
    
    # 加载配置
    load_config
    
    # 如果没有指定域名，使用默认域名或提示输入
    if [[ -z "$zone_name" ]]; then
        if [[ -n "$DEFAULT_ZONE" ]]; then
            zone_name="$DEFAULT_ZONE"
            echo -e "${YELLOW}使用默认域名: $zone_name${NC}"
        else
            read -p "请输入域名: " zone_name
        fi
    fi
    
    if [[ -z "$zone_name" ]]; then
        echo -e "${RED}错误: 必须指定域名${NC}"
        exit 1
    fi
    
    # 执行操作
    case $action in
        "list")
            list_records "$zone_name"
            ;;
        "add")
            interactive_add "$zone_name"
            ;;
        "delete")
            interactive_delete "$zone_name"
            ;;
        "batch_add")
            if [[ -z "$batch_file" ]]; then
                echo -e "${RED}错误: 批量添加需要指定文件${NC}"
                echo -e "${YELLOW}使用方法: $0 -b add <文件名> -z <域名>${NC}"
                exit 1
            fi
            batch_add "$batch_file" "$zone_name"
            ;;
        "batch_delete")
            if [[ -z "$batch_file" ]]; then
                echo -e "${RED}错误: 批量删除需要指定文件${NC}"
                echo -e "${YELLOW}使用方法: $0 -b delete <文件名> -z <域名>${NC}"
                echo -e "${YELLOW}创建示例: $0 -b example${NC}"
                exit 1
            fi
            batch_delete "$batch_file" "$zone_name"
            ;;
    esac
}

# 运行主函数
main "$@"