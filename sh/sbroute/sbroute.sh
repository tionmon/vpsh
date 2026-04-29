#!/bin/bash
#
# SBRoute — VPS 流量分流管理工具
# 基于 sing-box 的轻量级出站代理和路由规则管理器
# 适用于 Debian 12
#
set -euo pipefail

# ==================== 全局变量 ====================
SBROUTE_DIR="/etc/sbroute"
SINGBOX_CONFIG="$SBROUTE_DIR/config.json"
OUTBOUNDS_FILE="$SBROUTE_DIR/outbounds.json"
ROUTES_FILE="$SBROUTE_DIR/routes.json"
RULESETS_FILE="$SBROUTE_DIR/rulesets.json"
SETTINGS_FILE="$SBROUTE_DIR/settings.json"
BACKUP_DIR="$SBROUTE_DIR/backups"
SERVICE_NAME="sbroute"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
VERSION="1.1.0"

# ==================== 颜色定义 ====================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ==================== 工具函数 ====================
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*"; }
die()   { err "$@"; exit 1; }
title() { echo -e "\n${BOLD}${CYAN}══ $* ══${NC}\n"; }

# 通用 jq 写入: _jq_write <file> <jq_args...>
_jq_write() { local f="$1"; shift; local t; t=$(mktemp); jq "$@" "$f" > "$t" && mv "$t" "$f"; }

check_root() {
    [[ $EUID -eq 0 ]] || die "请以 root 权限运行此脚本"
}

check_jq() {
    if ! command -v jq &>/dev/null; then
        warn "jq 未安装，正在安装..."
        apt-get update -qq && apt-get install -y -qq jq >/dev/null 2>&1
        info "jq 安装完成"
    fi
}

ensure_files() {
    mkdir -p "$SBROUTE_DIR" "$BACKUP_DIR"
    [[ -f "$OUTBOUNDS_FILE" ]] || echo '[]' > "$OUTBOUNDS_FILE"
    [[ -f "$ROUTES_FILE" ]]    || echo '[]' > "$ROUTES_FILE"
    [[ -f "$RULESETS_FILE" ]]  || echo '[]' > "$RULESETS_FILE"
    [[ -f "$SETTINGS_FILE" ]]  || cat > "$SETTINGS_FILE" <<'EJSON'
{"default_outbound":"direct","dns_mode":"basic","tun_enabled":false}
EJSON
}

# ==================== 安装模块 ====================
_create_service() {
    local singbox_bin
    singbox_bin=$(command -v sing-box 2>/dev/null) || die "sing-box 二进制未找到"
    cat > "$SERVICE_FILE" <<ESERVICE
[Unit]
Description=SBRoute sing-box Service
After=network.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${singbox_bin} run -c ${SINGBOX_CONFIG}
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
ESERVICE
    systemctl daemon-reload
    info "已创建独立服务: $SERVICE_NAME"
}

cmd_install() {
    title "安装 SBRoute"
    check_root; check_jq

    # 检查 sing-box 二进制
    if ! command -v sing-box &>/dev/null; then
        info "sing-box 未安装，正在安装..."
        apt-get update -qq && apt-get install -y -qq curl gpg >/dev/null 2>&1
        curl -fsSL https://sing-box.app/gpg.key | gpg --dearmor -o /usr/share/keyrings/sagernet-archive-keyring.gpg 2>/dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/sagernet-archive-keyring.gpg] https://deb.sagernet.org/ * *" \
            > /etc/apt/sources.list.d/sagernet.list
        apt-get update -qq && apt-get install -y -qq sing-box >/dev/null 2>&1
        command -v sing-box &>/dev/null || die "sing-box 安装失败"
    fi
    info "sing-box 版本: $(sing-box version 2>/dev/null | head -1)"

    # 检测已有 sing-box 服务
    if systemctl is-active sing-box &>/dev/null; then
        info "检测到已有 sing-box 服务正在运行（不会影响它）"
    fi

    ensure_files

    # 创建独立 systemd 服务
    _create_service
    generate_config
    systemctl enable "$SERVICE_NAME" >/dev/null 2>&1 || true
    systemctl restart "$SERVICE_NAME" >/dev/null 2>&1 || true
    info "SBRoute 已启动并设为开机自启"
    info "配置文件: $SINGBOX_CONFIG"
    info "服务名称: $SERVICE_NAME (与原 sing-box 服务互不影响)"
}

cmd_uninstall() {
    title "卸载 SBRoute"
    check_root
    read -rp "确定要卸载 SBRoute 吗？(不会影响原 sing-box 服务) (y/N): " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { warn "取消卸载"; return; }

    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    info "SBRoute 服务已移除"

    read -rp "是否同时删除 SBRoute 配置和数据? (y/N): " del_conf
    [[ "$del_conf" =~ ^[Yy]$ ]] && rm -rf "$SBROUTE_DIR" && info "配置已删除"
    info "卸载完成（原 sing-box 服务未受影响）"
}

# ==================== 出站管理 ====================
out_add() {
    local type="${1:-}"; shift 2>/dev/null || true
    case "$type" in
        ss)     out_add_ss "$@" ;;
        socks)  out_add_socks "$@" ;;
        http)   out_add_http "$@" ;;
        vless)  out_add_vless "$@" ;;
        vmess)  out_add_vmess "$@" ;;
        direct) out_add_simple "direct" "${1:-direct}" ;;
        block)  out_add_simple "block" "${1:-block}" ;;
        url)    out_add_url "$@" ;;
        *)      die "未知出站类型: $type\n支持: ss, socks, http, vless, vmess, direct, block, url" ;;
    esac
}

out_add_ss() {
    [[ $# -ge 5 ]] || die "用法: sbroute out add ss <tag> <server> <port> <method> <password>"
    local tag="$1" server="$2" port="$3" method="$4" password="$5"
    _check_tag_unique "$tag"
    local obj
    obj=$(jq -n --arg t "$tag" --arg s "$server" --argjson p "$port" \
        --arg m "$method" --arg pw "$password" \
        '{type:"shadowsocks",tag:$t,server:$s,server_port:$p,method:$m,password:$pw}')
    _append_outbound "$obj"
    info "已添加 Shadowsocks 出站: $tag ($server:$port, $method)"
}

# socks 和 http 共用（仅 type 不同）
_out_add_proxy() {
    local type="$1"; shift
    [[ $# -ge 3 ]] || die "用法: sbroute out add $type <tag> <server> <port> [user] [pass]"
    local tag="$1" server="$2" port="$3" user="${4:-}" pass="${5:-}"
    _check_tag_unique "$tag"
    local obj
    obj=$(jq -n --arg tp "$type" --arg t "$tag" --arg s "$server" --argjson p "$port" \
        '{type:$tp,tag:$t,server:$s,server_port:$p}')
    [[ -n "$user" ]] && obj=$(echo "$obj" | jq --arg u "$user" '. + {username:$u}')
    [[ -n "$pass" ]] && obj=$(echo "$obj" | jq --arg p "$pass" '. + {password:$p}')
    _append_outbound "$obj"
    info "已添加 ${type^^} 出站: $tag ($server:$port)"
}
out_add_socks() { _out_add_proxy socks "$@"; }
out_add_http()  { _out_add_proxy http "$@"; }

out_add_vless() {
    [[ $# -ge 4 ]] || die "用法: sbroute out add vless <tag> <server> <port> <uuid> [flow] [sni]"
    local tag="$1" server="$2" port="$3" uuid="$4" flow="${5:-}" sni="${6:-}"
    _check_tag_unique "$tag"
    local obj
    obj=$(jq -n --arg t "$tag" --arg s "$server" --argjson p "$port" --arg u "$uuid" \
        '{type:"vless",tag:$t,server:$s,server_port:$p,uuid:$u}')
    if [[ -n "$flow" ]]; then
        obj=$(echo "$obj" | jq --arg f "$flow" '. + {flow:$f}')
    fi
    if [[ -n "$sni" ]]; then
        obj=$(echo "$obj" | jq --arg sn "$sni" '. + {tls:{enabled:true,server_name:$sn,reality:{enabled:true}}}')
    fi
    _append_outbound "$obj"
    info "已添加 VLESS 出站: $tag ($server:$port)"
}

out_add_vmess() {
    [[ $# -ge 4 ]] || die "用法: sbroute out add vmess <tag> <server> <port> <uuid> [security]"
    local tag="$1" server="$2" port="$3" uuid="$4" security="${5:-auto}"
    _check_tag_unique "$tag"
    local obj
    obj=$(jq -n --arg t "$tag" --arg s "$server" --argjson p "$port" \
        --arg u "$uuid" --arg sec "$security" \
        '{type:"vmess",tag:$t,server:$s,server_port:$p,uuid:$u,security:$sec}')
    _append_outbound "$obj"
    info "已添加 VMess 出站: $tag ($server:$port)"
}

out_add_simple() {
    local type="$1" tag="$2"
    _check_tag_unique "$tag"
    local obj
    obj=$(jq -n --arg t "$type" --arg tag "$tag" '{type:$t,tag:$tag}')
    _append_outbound "$obj"
    info "已添加 $type 出站: $tag"
}

# ==================== 分享链接解析 ====================
_urldecode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

_parse_query() {
    # 解析 query string 为关联数组，调用前需 declare -A params
    local query="$1"
    local IFS='&'
    for kv in $query; do
        local key="${kv%%=*}"
        local val="${kv#*=}"
        val=$(_urldecode "$val")
        eval "params[\"$key\"]=\"$val\""
    done
}

out_add_url() {
    [[ $# -ge 1 ]] || die "用法: sbroute out url <分享链接>\n支持: ss://, vless://"
    local url="$1"
    if [[ "$url" == ss://* ]]; then
        _parse_ss_url "$url"
    elif [[ "$url" == vless://* ]]; then
        _parse_vless_url "$url"
    elif [[ "$url" == vmess://* ]]; then
        die "VMess 分享链接暂不支持，请手动添加"
    else
        die "不支持的链接格式，目前支持: ss://, vless://"
    fi
}

_parse_ss_url() {
    local url="$1"
    # ss://base64(method:password)@server:port#tag
    # 或 ss://base64(method:password@server:port)#tag (SIP002)
    local body="${url#ss://}"

    # 提取 tag (fragment)
    local tag=""
    if [[ "$body" == *"#"* ]]; then
        tag=$(_urldecode "${body##*#}")
        body="${body%%#*}"
    fi
    [[ -n "$tag" ]] || die "SS 链接缺少 tag (# 后的名称)"

    local server port method password

    if [[ "$body" == *"@"* ]]; then
        # 格式: base64(method:password)@server:port
        local userinfo_b64="${body%%@*}"
        local server_part="${body##*@}"
        # 处理 base64 padding
        local padded="$userinfo_b64"
        local mod=$((${#padded} % 4))
        if [[ $mod -eq 2 ]]; then padded+="=="; elif [[ $mod -eq 3 ]]; then padded+="="; fi
        local userinfo
        userinfo=$(echo -n "$padded" | base64 -d 2>/dev/null) || die "SS 链接 base64 解码失败"
        method="${userinfo%%:*}"
        password="${userinfo#*:}"
        server="${server_part%%:*}"
        port="${server_part##*:}"
    else
        # 整体 base64 编码
        local padded="$body"
        local mod=$((${#padded} % 4))
        if [[ $mod -eq 2 ]]; then padded+="=="; elif [[ $mod -eq 3 ]]; then padded+="="; fi
        local decoded
        decoded=$(echo -n "$padded" | base64 -d 2>/dev/null) || die "SS 链接 base64 解码失败"
        method="${decoded%%:*}"
        local rest="${decoded#*:}"
        password="${rest%%@*}"
        local server_part="${rest##*@}"
        server="${server_part%%:*}"
        port="${server_part##*:}"
    fi

    [[ -n "$server" && -n "$port" && -n "$method" && -n "$password" ]] || die "SS 链接解析失败"
    info "解析 SS 链接: $tag ($server:$port, $method)"
    out_add_ss "$tag" "$server" "$port" "$method" "$password"
}

_parse_vless_url() {
    local url="$1"
    # vless://uuid@server:port?params#tag
    local body="${url#vless://}"

    # 提取 tag
    local tag=""
    if [[ "$body" == *"#"* ]]; then
        tag=$(_urldecode "${body##*#}")
        body="${body%%#*}"
    fi
    [[ -n "$tag" ]] || die "VLESS 链接缺少 tag (# 后的名称)"

    # 提取 query
    local query=""
    if [[ "$body" == *"?"* ]]; then
        query="${body##*?}"
        body="${body%%\?*}"
    fi

    # 提取 uuid@server:port
    local uuid="${body%%@*}"
    local server_part="${body##*@}"
    local server="${server_part%%:*}"
    local port="${server_part##*:}"

    [[ -n "$uuid" && -n "$server" && -n "$port" ]] || die "VLESS 链接解析失败"

    # 解析 query 参数
    declare -A params
    _parse_query "$query"

    local flow="${params[flow]:-}"
    local security="${params[security]:-}"
    local sni="${params[sni]:-}"
    local fp="${params[fp]:-}"
    local pbk="${params[pbk]:-}"
    local sid="${params[sid]:-}"
    local net_type="${params[type]:-tcp}"
    local alpn="${params[alpn]:-}"

    _check_tag_unique "$tag"

    # 构建基础对象
    local obj
    obj=$(jq -n --arg t "$tag" --arg s "$server" --argjson p "$port" --arg u "$uuid" \
        '{type:"vless",tag:$t,server:$s,server_port:$p,uuid:$u}')

    # flow
    [[ -n "$flow" ]] && obj=$(echo "$obj" | jq --arg f "$flow" '. + {flow:$f}')

    # TLS / Reality (unified)
    if [[ "$security" == "reality" || "$security" == "tls" ]]; then
        local tls_args=(--argjson enabled true)
        local tls_expr='{enabled:$enabled}'
        if [[ -n "$sni" ]]; then tls_args+=(--arg sni "$sni"); tls_expr+=' + {server_name:$sni}'; fi
        if [[ -n "$fp" ]]; then tls_args+=(--arg fp "$fp"); tls_expr+=' + {utls:{enabled:true,fingerprint:$fp}}'; fi
        if [[ -n "$alpn" ]]; then tls_args+=(--arg alpn "$alpn"); tls_expr+=' + {alpn:($alpn|split(","))}'; fi
        if [[ "$security" == "reality" ]]; then
            local r_expr='{enabled:true}'
            [[ -n "$pbk" ]] && { tls_args+=(--arg pbk "$pbk"); r_expr+=' + {public_key:$pbk}'; }
            [[ -n "$sid" ]] && { tls_args+=(--arg sid "$sid"); r_expr+=' + {short_id:$sid}'; }
            tls_expr+=" + {reality:($r_expr)}"
        fi
        local tls_obj; tls_obj=$(jq -n "${tls_args[@]}" "$tls_expr")
        obj=$(echo "$obj" | jq --argjson tls "$tls_obj" '. + {tls:$tls}')
    fi

    # transport (ws/grpc/h2)
    if [[ "$net_type" == "ws" ]]; then
        local ws_path="${params[path]:-/}"
        local ws_host="${params[host]:-}"
        local transport='{"type":"ws"}'
        transport=$(echo "$transport" | jq --arg p "$ws_path" '. + {path:$p}')
        [[ -n "$ws_host" ]] && transport=$(echo "$transport" | jq --arg h "$ws_host" '. + {headers:{Host:$h}}')
        obj=$(echo "$obj" | jq --argjson t "$transport" '. + {transport:$t}')
    elif [[ "$net_type" == "grpc" ]]; then
        local sn="${params[serviceName]:-}"
        local transport='{"type":"grpc"}'
        [[ -n "$sn" ]] && transport=$(echo "$transport" | jq --arg s "$sn" '. + {service_name:$s}')
        obj=$(echo "$obj" | jq --argjson t "$transport" '. + {transport:$t}')
    fi

    _append_outbound "$obj"
    info "已添加 VLESS 出站: $tag ($server:$port, security=$security)"
}

_check_tag_unique() {
    local tag="$1"
    local exists
    exists=$(jq -r --arg t "$tag" '[.[]|select(.tag==$t)]|length' "$OUTBOUNDS_FILE")
    [[ "$exists" -eq 0 ]] || die "Tag '$tag' 已存在，请使用其他名称"
}

_append_outbound() {
    _jq_write "$OUTBOUNDS_FILE" --argjson o "$1" '. + [$o]'
}

out_list() {
    title "出站列表"
    local count
    count=$(jq 'length' "$OUTBOUNDS_FILE")
    if [[ "$count" -eq 0 ]]; then
        warn "暂无自定义出站（direct 和 dns 为内置出站）"
        return
    fi
    printf "${BOLD}%-4s %-20s %-12s %-30s${NC}\n" "#" "Tag" "类型" "服务器"
    echo "──────────────────────────────────────────────────────────────────"
    jq -r 'to_entries[]|[.key+1,.value.tag,.value.type,
        (if .value.server then "\(.value.server):\(.value.server_port)" else "-" end)]
        |@tsv' "$OUTBOUNDS_FILE" | while IFS=$'\t' read -r idx tag type srv; do
        printf "%-4s %-20s %-12s %-30s\n" "$idx" "$tag" "$type" "$srv"
    done
}

out_del() {
    [[ $# -ge 1 ]] || die "用法: sbroute out del <tag>"
    local tag="$1"
    local exists
    exists=$(jq -r --arg t "$tag" '[.[]|select(.tag==$t)]|length' "$OUTBOUNDS_FILE")
    [[ "$exists" -gt 0 ]] || die "出站 '$tag' 不存在"
    _jq_write "$OUTBOUNDS_FILE" --arg t "$tag" '[.[]|select(.tag!=$t)]'
    _jq_write "$ROUTES_FILE" --arg t "$tag" '[.[]|select(.outbound!=$t)]'
    info "已删除出站: $tag（关联路由规则已清理）"
}

out_show() {
    [[ $# -ge 1 ]] || die "用法: sbroute out show <tag>"
    local tag="$1"
    jq --arg t "$tag" '.[]|select(.tag==$t)' "$OUTBOUNDS_FILE" | jq '.' || die "出站 '$tag' 不存在"
}

# ==================== 路由规则管理 ====================
route_add() {
    [[ $# -ge 2 ]] || die "用法: sbroute route add <outbound_tag> --domain/--suffix/--keyword/... <values>"
    local outbound="$1"; shift
    # 验证 outbound tag 存在
    local tag_ok
    tag_ok=$(jq -r --arg t "$outbound" '[.[]|select(.tag==$t)]|length' "$OUTBOUNDS_FILE")
    if [[ "$tag_ok" -eq 0 && "$outbound" != "direct" && "$outbound" != "block" ]]; then
        die "出站 '$outbound' 不存在，请先添加出站"
    fi

    local rule; rule=$(jq -n --arg o "$outbound" '{action:"route",outbound:$o}')

    # 参数名 → jq key 映射
    local -A _rk=([--domain]=domain [--suffix]=domain_suffix [--keyword]=domain_keyword
        [--regex]=domain_regex [--ip-cidr]=ip_cidr [--process]=process_name)

    while [[ $# -gt 0 ]]; do
        if [[ -n "${_rk[$1]:-}" ]]; then
            local key="${_rk[$1]}"; shift; [[ $# -gt 0 ]] || die "--${key} 需要参数"
            rule=$(echo "$rule" | jq --arg k "$key" --arg v "$1" '. + {($k):($v|split(","))}')
        elif [[ "$1" == "--port" ]]; then
            shift; [[ $# -gt 0 ]] || die "--port 需要参数"
            rule=$(echo "$rule" | jq --arg v "$1" '. + {port:($v|split(",")|map(tonumber))}')
        elif [[ "$1" == "--ruleset" ]]; then
            shift; [[ $# -gt 0 ]] || die "--ruleset 需要参数"
            local url="$1" rs_tag rs_exists
            rs_exists=$(jq -r --arg u "$url" '[.[]|select(.url==$u)]|length' "$RULESETS_FILE")
            if [[ "$rs_exists" -eq 0 ]]; then
                rs_tag="rs-$(echo "$url" | md5sum | head -c 8)"
                local fmt="binary"; [[ "$url" == *.json ]] && fmt="source"
                local rs_obj; rs_obj=$(jq -n --arg t "$rs_tag" --arg u "$url" --arg f "$fmt" \
                    --arg d "$(_get_download_detour)" '{type:"remote",tag:$t,format:$f,url:$u,download_detour:$d}')
                _jq_write "$RULESETS_FILE" --argjson o "$rs_obj" '. + [$o]'
            else
                rs_tag=$(jq -r --arg u "$url" '.[]|select(.url==$u)|.tag' "$RULESETS_FILE")
            fi
            rule=$(echo "$rule" | jq --arg rs "$rs_tag" \
                'if .rule_set then .rule_set += [$rs] else . + {rule_set:[$rs]} end')
        else
            die "未知路由参数: $1"
        fi
        shift
    done

    _jq_write "$ROUTES_FILE" --argjson r "$rule" '. + [$r]'
    info "已添加路由规则 → $outbound"
    echo "$rule" | jq '.'
}

route_list() {
    title "路由规则列表"
    local count
    count=$(jq 'length' "$ROUTES_FILE")
    if [[ "$count" -eq 0 ]]; then
        warn "暂无自定义路由规则"
        return
    fi
    printf "${BOLD}%-4s %-15s %-50s${NC}\n" "#" "出站" "匹配条件"
    echo "──────────────────────────────────────────────────────────────────────"
    jq -r 'to_entries[]|[.key+1, .value.outbound,
        ([if .value.domain then "domain:\(.value.domain|join(","))" else empty end,
          if .value.domain_suffix then "suffix:\(.value.domain_suffix|join(","))" else empty end,
          if .value.domain_keyword then "keyword:\(.value.domain_keyword|join(","))" else empty end,
          if .value.domain_regex then "regex:\(.value.domain_regex|join(","))" else empty end,
          if .value.ip_cidr then "ip:\(.value.ip_cidr|join(","))" else empty end,
          if .value.port then "port:\(.value.port|map(tostring)|join(","))" else empty end,
          if .value.process_name then "proc:\(.value.process_name|join(","))" else empty end,
          if .value.rule_set then "ruleset:\(.value.rule_set|join(","))" else empty end
        ]|join(" | "))]|@tsv' "$ROUTES_FILE" | while IFS=$'\t' read -r idx out conds; do
        printf "%-4s %-15s %-50s\n" "$idx" "$out" "$conds"
    done
}

route_del() {
    [[ $# -ge 1 ]] || die "用法: sbroute route del <index>"
    local idx="$1"
    local count; count=$(jq 'length' "$ROUTES_FILE")
    [[ "$idx" -ge 1 && "$idx" -le "$count" ]] 2>/dev/null || die "索引超出范围 (1-$count)"
    _jq_write "$ROUTES_FILE" --argjson i "$((idx-1))" 'del(.[$i])'
    info "已删除路由规则 #$idx"
}

route_default() {
    [[ $# -ge 1 ]] || die "用法: sbroute route default <outbound_tag>"
    _jq_write "$SETTINGS_FILE" --arg t "$1" '.default_outbound=$t'
    info "默认出站已设置为: $1"
}

# ==================== DNS 模块 ====================
cmd_dns() {
    local mode="${1:-}"
    case "$mode" in
        basic|split)
            _jq_write "$SETTINGS_FILE" --arg m "$mode" '.dns_mode=$m'
            local -A desc=([basic]="基础 (Google DNS 8.8.8.8)" [split]="国内分流 (AliDNS + Google DNS)")
            info "DNS 模式: ${desc[$mode]}"
            ;;
        *)
            echo "用法: sbroute dns <basic|split>"
            echo "  basic  — Google DNS (8.8.8.8)"
            echo "  split  — 国内域名用 AliDNS，其余用 Google DNS"
            ;;
    esac
}

# ==================== 预设模板 ====================
cmd_preset() {
    local preset="${1:-}"
    case "$preset" in
        cn-direct)
            title "应用预设: 国内直连"
            _preset_ensure_direct
            # geoip-cn
            _add_ruleset_if_missing "geoip-cn" \
                "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs" "binary"
            # geosite-cn
            _add_ruleset_if_missing "geosite-cn" \
                "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs" "binary"
            # 添加路由规则
            local rule
            rule=$(jq -n '{action:"route",outbound:"direct",rule_set:["geoip-cn","geosite-cn"]}')
            _add_route_if_missing "$rule" "geoip-cn"
            info "已添加: 国内 IP + 国内域名 → direct"
            ;;
        ads-block)
            title "应用预设: 广告拦截"
            _add_ruleset_if_missing "geosite-category-ads-all" \
                "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs" "binary"
            # 确保 block 出站存在
            local block_exists
            block_exists=$(jq '[.[]|select(.tag=="block")]|length' "$OUTBOUNDS_FILE")
            [[ "$block_exists" -gt 0 ]] || out_add_simple "block" "block"
            local rule
            rule=$(jq -n '{action:"route",outbound:"block",rule_set:["geosite-category-ads-all"]}')
            _add_route_if_missing "$rule" "geosite-category-ads-all"
            info "已添加: 广告域名 → block"
            ;;
        *)
            echo "用法: sbroute preset <cn-direct|ads-block>"
            echo "  cn-direct  — 国内 IP + 域名 直连"
            echo "  ads-block  — 广告域名 拦截"
            ;;
    esac
}

_preset_ensure_direct() {
    local exists
    exists=$(jq '[.[]|select(.tag=="direct")]|length' "$OUTBOUNDS_FILE")
    [[ "$exists" -gt 0 ]] || out_add_simple "direct" "direct"
}

# 获取 rule-set 下载使用的 detour: 优先用第一个代理出站，否则用 direct
_get_download_detour() {
    local first_proxy
    first_proxy=$(jq -r '[.[]|select(.type!="direct" and .type!="block")][0].tag // empty' "$OUTBOUNDS_FILE" 2>/dev/null)
    if [[ -n "$first_proxy" ]]; then
        echo "$first_proxy"
    else
        echo "direct"
    fi
}

_add_ruleset_if_missing() {
    local tag="$1" url="$2" fmt="$3"
    local exists; exists=$(jq -r --arg t "$tag" '[.[]|select(.tag==$t)]|length' "$RULESETS_FILE")
    if [[ "$exists" -eq 0 ]]; then
        local obj; obj=$(jq -n --arg t "$tag" --arg u "$url" --arg f "$fmt" \
            --arg d "$(_get_download_detour)" '{type:"remote",tag:$t,format:$f,url:$u,download_detour:$d}')
        _jq_write "$RULESETS_FILE" --argjson o "$obj" '. + [$o]'
    fi
}

_add_route_if_missing() {
    local rule="$1" check_key="$2"
    local exists; exists=$(jq -r --arg k "$check_key" '[.[]|select(.rule_set? and (.rule_set[]|select(.==$k)))]|length' "$ROUTES_FILE")
    [[ "$exists" -eq 0 ]] && _jq_write "$ROUTES_FILE" --argjson r "$rule" '. + [$r]'
}

# ==================== 配置生成 ====================
generate_config() {
    ensure_files
    local dns_mode default_out tun_enabled
    dns_mode=$(jq -r '.dns_mode // "basic"' "$SETTINGS_FILE")
    default_out=$(jq -r '.default_outbound // "direct"' "$SETTINGS_FILE")
    tun_enabled=$(jq -r '.tun_enabled // true' "$SETTINGS_FILE")

    # DNS 基础配置，split 模式额外加 rules
    local dns_config
    dns_config=$(jq -n '{
        servers:[
            {tag:"google-dns",type:"tls",server:"8.8.8.8"},
            {tag:"google-dns6",type:"tls",server:"2001:4860:4860::8888"},
            {tag:"ali-dns",type:"udp",server:"223.5.5.5"},
            {tag:"ali-dns6",type:"udp",server:"2400:3200::1"}
        ],
        strategy:"prefer_ipv4"
    }')
    [[ "$dns_mode" == "split" ]] && dns_config=$(echo "$dns_config" | jq '. + {rules:[{rule_set:["geosite-cn"],server:"ali-dns"}]}')

    # 构建入站
    local inbounds='[]'
    if [[ "$tun_enabled" == "true" ]]; then
        inbounds=$(cat <<'EINB'
[{"type":"tun","tag":"tun-in","address":["172.19.0.1/30","fdfe:dcba:9876::1/126"],"auto_route":true,"strict_route":true}]
EINB
)
    fi

    # 构建出站: 内置 direct + dns + 用户自定义
    local builtin_outs='[{"type":"direct","tag":"direct"},{"type":"block","tag":"block"}]'
    local user_outs; user_outs=$(cat "$OUTBOUNDS_FILE")
    # 移除用户定义中与内置重名的
    user_outs=$(echo "$user_outs" | jq '[.[]|select(.tag!="direct" and .tag!="block" and .tag!="dns-out")]')
    local all_outs
    all_outs=$(jq -n --argjson b "$builtin_outs" --argjson u "$user_outs" '$u + $b')

    # 构建路由规则: 内置规则 + 用户规则
    local builtin_rules='[{"action":"sniff"},{"protocol":"dns","action":"hijack-dns"},{"ip_is_private":true,"action":"route","outbound":"direct"}]'
    local user_rules; user_rules=$(cat "$ROUTES_FILE")
    local all_rules
    all_rules=$(jq -n --argjson b "$builtin_rules" --argjson u "$user_rules" '$b + $u')

    # 规则集
    local rule_sets; rule_sets=$(cat "$RULESETS_FILE")

    # 更新 rule_set 中的 download_detour 为当前可用代理
    local detour; detour=$(_get_download_detour)
    rule_sets=$(echo "$rule_sets" | jq --arg d "$detour" '[.[]|.download_detour=$d]')

    # 组装完整配置
    local config
    config=$(jq -n \
        --argjson dns "$dns_config" \
        --argjson inb "$inbounds" \
        --argjson out "$all_outs" \
        --argjson rules "$all_rules" \
        --argjson rsets "$rule_sets" \
        --arg final "$default_out" \
        '{
            log:{level:"warn",timestamp:true},
            dns:$dns,
            inbounds:$inb,
            outbounds:$out,
            route:{
                rules:$rules,
                rule_set:$rsets,
                final:$final,
                auto_detect_interface:true,
                default_domain_resolver:"google-dns"
            },
            experimental:{
                cache_file:{enabled:true}
            }
        }')

    # 如果 dns_mode 是 split 但 geosite-cn 规则集不存在于 rulesets，dns 规则中移除 rule_set 引用
    if [[ "$dns_mode" == "split" ]]; then
        local has_geosite
        has_geosite=$(echo "$rule_sets" | jq '[.[]|select(.tag=="geosite-cn")]|length')
        if [[ "$has_geosite" -eq 0 ]]; then
            config=$(echo "$config" | jq '.dns.rules=[]')
        fi
    fi

    mkdir -p "$(dirname "$SINGBOX_CONFIG")"
    echo "$config" | jq '.' > "$SINGBOX_CONFIG"
}

cmd_apply() {
    title "应用配置"
    check_root
    generate_config
    info "配置已生成: $SINGBOX_CONFIG"

    # 校验
    if command -v sing-box &>/dev/null; then
        if sing-box check -c "$SINGBOX_CONFIG" 2>/dev/null; then
            info "配置校验通过 ✓"
        else
            err "配置校验失败，请检查配置"
            sing-box check -c "$SINGBOX_CONFIG" 2>&1 || true
            return 1
        fi
        # 确保服务文件存在
        [[ -f "$SERVICE_FILE" ]] || _create_service
        systemctl restart "$SERVICE_NAME" 2>/dev/null && info "$SERVICE_NAME 已重启" || warn "重启失败"
    else
        warn "sing-box 未安装，仅生成了配置文件"
    fi
}

# ==================== 备份/恢复 ====================
cmd_backup() {
    local file="${1:-$BACKUP_DIR/sbroute-$(date +%Y%m%d-%H%M%S).tar.gz}"
    tar -czf "$file" -C / "etc/sbroute" 2>/dev/null
    info "备份已保存: $file"
    echo "  大小: $(du -h "$file" | cut -f1)"
}

cmd_restore() {
    [[ $# -ge 1 ]] || die "用法: sbroute restore <file.tar.gz>"
    local file="$1"
    [[ -f "$file" ]] || die "文件不存在: $file"
    check_root
    tar -xzf "$file" -C / 2>/dev/null
    info "配置已恢复自: $file"
    warn "请运行 'sbroute apply' 使配置生效"
}

cmd_export() {
    [[ -f "$SINGBOX_CONFIG" ]] || generate_config
    jq '.' "$SINGBOX_CONFIG"
}

cmd_import() {
    [[ $# -ge 1 ]] || die "用法: sbroute import <config.json>"
    local file="$1"
    [[ -f "$file" ]] || die "文件不存在: $file"
    check_root; ensure_files

    # 从完整配置中提取出站和路由
    local outs routes rsets
    outs=$(jq '[.outbounds[]|select(.type!="direct" and .type!="block" and .type!="dns")]' "$file" 2>/dev/null) || outs='[]'
    routes=$(jq '[.route.rules[]|select(.action=="route" and .outbound and .outbound!="direct" and .protocol==null and .ip_is_private==null)]' "$file" 2>/dev/null) || routes='[]'
    rsets=$(jq '.route.rule_set // []' "$file" 2>/dev/null) || rsets='[]'

    echo "$outs" | jq '.' > "$OUTBOUNDS_FILE"
    echo "$routes" | jq '.' > "$ROUTES_FILE"
    echo "$rsets" | jq '.' > "$RULESETS_FILE"

    local out_count route_count
    out_count=$(echo "$outs" | jq 'length')
    route_count=$(echo "$routes" | jq 'length')
    info "已导入: $out_count 个出站, $route_count 条路由规则"
    warn "请运行 'sbroute apply' 使配置生效"
}

# ==================== 服务管理 ====================
cmd_status() {
    title "SBRoute 状态"
    if command -v sing-box &>/dev/null; then
        echo -e "sing-box 版本: ${CYAN}$(sing-box version 2>/dev/null | head -1)${NC}"
    else
        warn "sing-box 未安装"
        return
    fi
    echo -e "配置文件: ${CYAN}$SINGBOX_CONFIG${NC}"
    echo -e "服务名称: ${CYAN}$SERVICE_NAME${NC}"
    echo ""
    systemctl status "$SERVICE_NAME" --no-pager -l 2>/dev/null || warn "SBRoute 服务未运行"
    # 显示原 sing-box 状态
    if systemctl is-active sing-box &>/dev/null 2>&1; then
        echo ""
        echo -e "${GREEN}[i]${NC} 原 sing-box 服务也在运行中（互不影响）"
    fi
}

cmd_log() {
    local lines="${1:-50}"
    journalctl -u "$SERVICE_NAME" -n "$lines" --no-pager 2>/dev/null || warn "无法读取日志"
}

cmd_test() {
    local tag="${1:-}" url="${2:-https://www.google.com}"
    [[ -n "$tag" ]] || die "用法: sbroute test <outbound_tag> [url]"
    info "测试出站 '$tag' 连接到 $url ..."
    # 查找出站的 server 和 port
    local out_info
    out_info=$(jq --arg t "$tag" '.[]|select(.tag==$t)' "$OUTBOUNDS_FILE")
    [[ -n "$out_info" ]] || die "出站 '$tag' 不存在"
    local type server port
    type=$(echo "$out_info" | jq -r '.type')
    server=$(echo "$out_info" | jq -r '.server // empty')
    port=$(echo "$out_info" | jq -r '.server_port // empty')

    if [[ "$type" == "socks" && -n "$server" ]]; then
        curl -x "socks5://$server:$port" -o /dev/null -s -w "HTTP %{http_code} | 耗时 %{time_total}s\n" "$url" \
            && info "连接成功" || err "连接失败"
    elif [[ "$type" == "http" && -n "$server" ]]; then
        curl -x "http://$server:$port" -o /dev/null -s -w "HTTP %{http_code} | 耗时 %{time_total}s\n" "$url" \
            && info "连接成功" || err "连接失败"
    else
        warn "仅支持 SOCKS5/HTTP 出站的直接连通性测试"
        warn "其他类型请在 apply 后检查 sing-box 日志"
    fi
}

# ==================== 交互式菜单 ====================
interactive_menu() {
    while true; do
        echo ""
        echo -e "${BOLD}${CYAN}╔══════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${CYAN}║   SBRoute — VPS 流量分流管理 v${VERSION}  ║${NC}"
        echo -e "${BOLD}${CYAN}╚══════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} 安装 sing-box"
        echo -e "  ${GREEN}2)${NC} 添加出站"
        echo -e "  ${GREEN}3)${NC} 查看出站列表"
        echo -e "  ${GREEN}4)${NC} 删除出站"
        echo -e "  ${GREEN}5)${NC} 添加路由规则"
        echo -e "  ${GREEN}6)${NC} 查看路由规则"
        echo -e "  ${GREEN}7)${NC} 删除路由规则"
        echo -e "  ${GREEN}8)${NC} 设置默认出站"
        echo -e "  ${GREEN}9)${NC} DNS 设置"
        echo -e "  ${GREEN}10)${NC} 应用预设模板"
        echo -e "  ${GREEN}11)${NC} 应用配置并重启"
        echo -e "  ${GREEN}12)${NC} 备份配置"
        echo -e "  ${GREEN}13)${NC} 恢复配置"
        echo -e "  ${GREEN}14)${NC} 导出配置 (JSON)"
        echo -e "  ${GREEN}15)${NC} 导入配置 (JSON)"
        echo -e "  ${GREEN}16)${NC} 查看 sing-box 状态"
        echo -e "  ${GREEN}17)${NC} 查看日志"
        echo -e "  ${GREEN}18)${NC} 卸载"
        echo -e "  ${GREEN}0)${NC} 退出"
        echo ""
        read -rp "请选择 [0-18]: " choice

        case "$choice" in
            1) cmd_install ;;
            2) _menu_add_outbound ;;
            3) out_list ;;
            4) _menu_del_outbound ;;
            5) _menu_add_route ;;
            6) route_list ;;
            7) _menu_del_route ;;
            8) _menu_set_default ;;
            9) _menu_dns ;;
            10) _menu_preset ;;
            11) cmd_apply ;;
            12) cmd_backup ;;
            13) _menu_restore ;;
            14) cmd_export ;;
            15) _menu_import ;;
            16) cmd_status ;;
            17) cmd_log ;;
            18) cmd_uninstall ;;
            0) echo "再见！"; exit 0 ;;
            *) warn "无效选择" ;;
        esac
        echo ""
        read -rp "按回车继续..."
    done
}

_menu_add_outbound() {
    echo ""
    echo -e "  出站类型:"
    echo -e "  ${CYAN}1)${NC} Shadowsocks (ss)"
    echo -e "  ${CYAN}2)${NC} SOCKS5"
    echo -e "  ${CYAN}3)${NC} HTTP"
    echo -e "  ${CYAN}4)${NC} VLESS"
    echo -e "  ${CYAN}5)${NC} VMess"
    echo -e "  ${CYAN}6)${NC} Direct"
    echo -e "  ${CYAN}7)${NC} Block"
    echo -e "  ${CYAN}8)${NC} 粘贴分享链接 (ss:// / vless://)"
    echo ""
    read -rp "选择类型 [1-8]: " t
    case "$t" in
        1)
            read -rp "Tag: " tag; read -rp "Server: " srv; read -rp "Port: " port
            read -rp "Method (aes-128-gcm): " method; method=${method:-aes-128-gcm}
            read -rp "Password: " pw
            out_add_ss "$tag" "$srv" "$port" "$method" "$pw"
            ;;
        2|3)
            local ptype; [[ "$t" == 2 ]] && ptype=socks || ptype=http
            read -rp "Tag: " tag; read -rp "Server: " srv; read -rp "Port: " port
            read -rp "User (可选): " user; read -rp "Password (可选): " pw
            _out_add_proxy "$ptype" "$tag" "$srv" "$port" "$user" "$pw"
            ;;
        4)
            read -rp "Tag: " tag; read -rp "Server: " srv; read -rp "Port: " port
            read -rp "UUID: " uuid; read -rp "Flow (可选, 如 xtls-rprx-vision): " flow
            read -rp "SNI (可选, 启用 TLS+Reality): " sni
            out_add_vless "$tag" "$srv" "$port" "$uuid" "$flow" "$sni"
            ;;
        5)
            read -rp "Tag: " tag; read -rp "Server: " srv; read -rp "Port: " port
            read -rp "UUID: " uuid; read -rp "Security (auto): " sec; sec=${sec:-auto}
            out_add_vmess "$tag" "$srv" "$port" "$uuid" "$sec"
            ;;
        6) read -rp "Tag (direct): " tag; out_add_simple "direct" "${tag:-direct}" ;;
        7) read -rp "Tag (block): " tag; out_add_simple "block" "${tag:-block}" ;;
        8)
            echo -e "  粘贴分享链接 (支持 ss:// 和 vless://):"
            read -rp "  链接: " share_url
            [[ -n "$share_url" ]] && out_add_url "$share_url"
            ;;
        *) warn "无效选择" ;;
    esac
}

_menu_del_outbound() {
    out_list
    echo ""
    read -rp "输入要删除的 Tag: " tag
    [[ -n "$tag" ]] && out_del "$tag"
}

_menu_add_route() {
    out_list
    echo ""
    read -rp "目标出站 Tag: " out_tag
    [[ -n "$out_tag" ]] || return

    echo -e "\n  匹配条件 (留空跳过):"
    read -rp "  Domain (逗号分隔): " domains
    read -rp "  Domain Suffix (逗号分隔): " suffixes
    read -rp "  Domain Keyword (逗号分隔): " keywords
    read -rp "  Rule Set URL: " ruleset

    local args=("$out_tag")
    [[ -n "$domains" ]]  && args+=(--domain "$domains")
    [[ -n "$suffixes" ]] && args+=(--suffix "$suffixes")
    [[ -n "$keywords" ]] && args+=(--keyword "$keywords")
    [[ -n "$ruleset" ]]  && args+=(--ruleset "$ruleset")

    if [[ ${#args[@]} -le 1 ]]; then
        warn "至少需要指定一个匹配条件"
        return
    fi
    route_add "${args[@]}"
}

_menu_del_route() {
    route_list
    echo ""
    read -rp "输入要删除的序号: " idx
    [[ -n "$idx" ]] && route_del "$idx"
}

_menu_set_default() {
    out_list
    echo ""
    local cur; cur=$(jq -r '.default_outbound // "direct"' "$SETTINGS_FILE")
    echo -e "当前默认出站: ${CYAN}$cur${NC}"
    read -rp "新的默认出站 Tag: " tag
    [[ -n "$tag" ]] && route_default "$tag"
}

_menu_dns() {
    local cur; cur=$(jq -r '.dns_mode // "basic"' "$SETTINGS_FILE")
    echo -e "\n当前 DNS 模式: ${CYAN}$cur${NC}"
    echo -e "  ${CYAN}1)${NC} basic  — Google DNS"
    echo -e "  ${CYAN}2)${NC} split  — 国内分流"
    read -rp "选择 [1-2]: " c
    case "$c" in
        1) cmd_dns basic ;;
        2) cmd_dns split ;;
        *) warn "无效选择" ;;
    esac
}

_menu_preset() {
    echo -e "\n  预设模板:"
    echo -e "  ${CYAN}1)${NC} cn-direct  — 国内直连"
    echo -e "  ${CYAN}2)${NC} ads-block  — 广告拦截"
    read -rp "选择 [1-2]: " c
    case "$c" in
        1) cmd_preset cn-direct ;;
        2) cmd_preset ads-block ;;
        *) warn "无效选择" ;;
    esac
}

_menu_restore() {
    echo ""; ls -la "$BACKUP_DIR"/ 2>/dev/null || warn "无备份文件"
    echo ""
    read -rp "输入备份文件路径: " file
    [[ -n "$file" ]] && cmd_restore "$file"
}

_menu_import() {
    read -rp "输入 JSON 配置文件路径: " file
    [[ -n "$file" ]] && cmd_import "$file"
}

# ==================== 帮助信息 ====================
show_help() {
    cat <<EOF
${BOLD}SBRoute v${VERSION}${NC} — VPS 流量分流管理工具

${BOLD}用法:${NC}
  sbroute                              交互式菜单
  sbroute install                      安装 sing-box
  sbroute uninstall                    卸载

${BOLD}出站管理:${NC}
  sbroute out add ss <tag> <server> <port> <method> <password>
  sbroute out add socks <tag> <server> <port> [user] [pass]
  sbroute out add http <tag> <server> <port> [user] [pass]
  sbroute out add vless <tag> <server> <port> <uuid> [flow] [sni]
  sbroute out add vmess <tag> <server> <port> <uuid> [security]
  sbroute out add direct [tag]
  sbroute out add block [tag]
  sbroute out add url <分享链接>        解析 ss:// / vless:// 链接添加
  sbroute out list                     列出所有出站
  sbroute out del <tag>                删除出站
  sbroute out show <tag>               查看出站详情

${BOLD}路由规则:${NC}
  sbroute route add <tag> --domain/--suffix/--keyword/--regex/--ip-cidr/--port/--process/--ruleset <v>
  sbroute route list                   列出路由规则
  sbroute route del <index>            删除路由规则
  sbroute route default <tag>          设置默认出站

${BOLD}DNS:${NC}
  sbroute dns basic                    Google DNS
  sbroute dns split                    国内分流 DNS

${BOLD}预设:${NC}
  sbroute preset cn-direct             国内直连规则集
  sbroute preset ads-block             广告拦截规则集

${BOLD}配置:${NC}
  sbroute apply                        生成配置并重启
  sbroute backup [file]                备份
  sbroute restore <file>               恢复
  sbroute export                       导出 JSON
  sbroute import <file>                导入 JSON

${BOLD}服务:${NC}
  sbroute status                       查看状态
  sbroute start|stop|restart           服务控制
  sbroute log [lines]                  查看日志
  sbroute test <tag> [url]             连通性测试
EOF
}

# ==================== 主入口 ====================
main() {
    local cmd="${1:-}"
    [[ -n "$cmd" ]] && shift

    # 非 help/version 命令需要 root 和初始化
    case "$cmd" in
        ""|-h|--help|help|version|-v|--version) ;;
        *) check_root; check_jq; ensure_files ;;
    esac

    case "$cmd" in
        "") interactive_menu ;;
        install)   cmd_install ;;
        uninstall) cmd_uninstall ;;
        out|outbound)
            local sub="${1:-}"; shift 2>/dev/null || true
            case "$sub" in
                add)  out_add "$@" ;;
                list) out_list ;;
                del)  out_del "$@" ;;
                show) out_show "$@" ;;
                *)    die "用法: sbroute out <add|list|del|show>" ;;
            esac
            ;;
        route)
            local sub="${1:-}"; shift 2>/dev/null || true
            case "$sub" in
                add)     route_add "$@" ;;
                list)    route_list ;;
                del)     route_del "$@" ;;
                default) route_default "$@" ;;
                *)       die "用法: sbroute route <add|list|del|default>" ;;
            esac
            ;;
        dns)    cmd_dns "$@" ;;
        preset) cmd_preset "$@" ;;
        apply)  cmd_apply ;;
        backup) cmd_backup "$@" ;;
        restore) cmd_restore "$@" ;;
        export) cmd_export ;;
        import) cmd_import "$@" ;;
        status) cmd_status ;;
        start)  check_root; [[ -f "$SERVICE_FILE" ]] || _create_service; systemctl start "$SERVICE_NAME" && info "$SERVICE_NAME 已启动" ;;
        stop)   check_root; systemctl stop "$SERVICE_NAME" && info "$SERVICE_NAME 已停止" ;;
        restart) check_root; [[ -f "$SERVICE_FILE" ]] || _create_service; systemctl restart "$SERVICE_NAME" && info "$SERVICE_NAME 已重启" ;;
        log)    cmd_log "$@" ;;
        test)   cmd_test "$@" ;;
        -h|--help|help) show_help ;;
        -v|--version|version) echo "SBRoute v${VERSION}" ;;
        *) err "未知命令: $cmd"; show_help; exit 1 ;;
    esac
}

main "$@"
