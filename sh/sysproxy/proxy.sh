#!/usr/bin/env bash
# ============================================================
#  proxy.sh — 一键临时代理设置 / 清除脚本
#  用法:
#    source proxy.sh set  [代理地址] [选项]
#    source proxy.sh unset
#    bash proxy.sh docker-set  [代理地址]
#    bash proxy.sh docker-unset
#    bash proxy.sh all-set  [代理地址] [选项]
#    bash proxy.sh all-unset
#
#  代理地址格式 (任选其一):
#    http://127.0.0.1:8888   — 完整 URL
#    127.0.0.1:8888          — 自动补 http://
#    8888                    — 自动补 http://127.0.0.1:
#
#  选项:
#    --docker   同时配置 Docker 代理
#    --git      同时配置 Git 代理
#    --apt      同时配置 APT 代理
#    --npm      同时配置 NPM 代理
#    --pip      同时配置 PIP 代理
#    --wget     同时配置 Wget 代理
#    --all      同时配置以上全部
# ============================================================

set -euo pipefail

# ─── 颜色常量 ───────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ─── 辅助函数 ───────────────────────────────────────────────
info()    { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*"; }
section() { echo -e "\n${CYAN}${BOLD}── $* ──${NC}"; }

# ─── 解析代理地址 ───────────────────────────────────────────
parse_proxy() {
    local input="${1:-}"
    if [[ -z "$input" ]]; then
        echo "http://127.0.0.1:8888"
        return
    fi

    # 纯数字 → 端口号
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        echo "http://127.0.0.1:${input}"
        return
    fi

    # 已有协议头
    if [[ "$input" =~ ^https?:// ]]; then
        echo "$input"
        return
    fi

    # host:port 但无协议头
    echo "http://${input}"
}

# ─── Shell 环境变量代理 ─────────────────────────────────────
proxy_shell_set() {
    local proxy_url="$1"
    section "Shell 环境变量"

    export http_proxy="$proxy_url"
    export HTTP_PROXY="$proxy_url"
    export https_proxy="$proxy_url"
    export HTTPS_PROXY="$proxy_url"
    export ftp_proxy="$proxy_url"
    export FTP_PROXY="$proxy_url"
    export all_proxy="$proxy_url"
    export ALL_PROXY="$proxy_url"
    export no_proxy="localhost,127.0.0.1,::1,.local"
    export NO_PROXY="localhost,127.0.0.1,::1,.local"

    info "http_proxy  = $http_proxy"
    info "https_proxy = $https_proxy"
    info "ftp_proxy   = $ftp_proxy"
    info "all_proxy   = $all_proxy"
    info "no_proxy    = $no_proxy"
}

proxy_shell_unset() {
    section "Shell 环境变量"

    unset http_proxy HTTP_PROXY \
          https_proxy HTTPS_PROXY \
          ftp_proxy FTP_PROXY \
          all_proxy ALL_PROXY \
          no_proxy NO_PROXY 2>/dev/null || true

    info "已清除所有 Shell 代理环境变量"
}

# ─── Docker 守护进程代理 ────────────────────────────────────
proxy_docker_set() {
    local proxy_url="$1"
    section "Docker 守护进程"

    local conf_dir="/etc/systemd/system/docker.service.d"
    local conf_file="${conf_dir}/http-proxy.conf"

    sudo mkdir -p "$conf_dir"
    sudo tee "$conf_file" > /dev/null <<EOF
[Service]
Environment="HTTP_PROXY=${proxy_url}"
Environment="HTTPS_PROXY=${proxy_url}"
Environment="NO_PROXY=localhost,127.0.0.1,::1,.local"
EOF

    sudo systemctl daemon-reload
    sudo systemctl restart docker

    info "Docker 代理已写入: $conf_file"
    info "Docker 守护进程已重启"
}

proxy_docker_unset() {
    section "Docker 守护进程"

    local conf_file="/etc/systemd/system/docker.service.d/http-proxy.conf"
    local conf_dir="/etc/systemd/system/docker.service.d"

    if [[ -f "$conf_file" ]]; then
        sudo rm -f "$conf_file"
        info "已删除: $conf_file"
    else
        warn "文件不存在，跳过: $conf_file"
    fi

    # 如果目录为空则也删除
    if [[ -d "$conf_dir" ]] && [[ -z "$(ls -A "$conf_dir" 2>/dev/null)" ]]; then
        sudo rmdir "$conf_dir"
        info "已删除空目录: $conf_dir"
    fi

    sudo systemctl daemon-reload
    sudo systemctl restart docker

    info "Docker 守护进程已重启 (代理已移除)"
}

# ─── Git 代理 ───────────────────────────────────────────────
proxy_git_set() {
    local proxy_url="$1"
    section "Git"

    git config --global http.proxy "$proxy_url"
    git config --global https.proxy "$proxy_url"

    info "git http.proxy  = $proxy_url"
    info "git https.proxy = $proxy_url"
}

proxy_git_unset() {
    section "Git"

    git config --global --unset http.proxy 2>/dev/null || true
    git config --global --unset https.proxy 2>/dev/null || true

    info "已清除 Git 代理"
}

# ─── APT 代理 ──────────────────────────────────────────────
proxy_apt_set() {
    local proxy_url="$1"
    section "APT"

    local conf_file="/etc/apt/apt.conf.d/95proxy"
    sudo tee "$conf_file" > /dev/null <<EOF
Acquire::http::Proxy "${proxy_url}";
Acquire::https::Proxy "${proxy_url}";
EOF

    info "APT 代理已写入: $conf_file"
}

proxy_apt_unset() {
    section "APT"

    local conf_file="/etc/apt/apt.conf.d/95proxy"
    if [[ -f "$conf_file" ]]; then
        sudo rm -f "$conf_file"
        info "已删除: $conf_file"
    else
        warn "文件不存在，跳过: $conf_file"
    fi
}

# ─── NPM 代理 ──────────────────────────────────────────────
proxy_npm_set() {
    local proxy_url="$1"
    section "NPM"

    npm config set proxy "$proxy_url"
    npm config set https-proxy "$proxy_url"

    info "npm proxy       = $proxy_url"
    info "npm https-proxy = $proxy_url"
}

proxy_npm_unset() {
    section "NPM"

    npm config delete proxy 2>/dev/null || true
    npm config delete https-proxy 2>/dev/null || true

    info "已清除 NPM 代理"
}

# ─── PIP / Python 代理 ─────────────────────────────────────
proxy_pip_set() {
    local proxy_url="$1"
    section "PIP"

    local conf_dir="$HOME/.config/pip"
    local conf_file="${conf_dir}/pip.conf"
    mkdir -p "$conf_dir"

    cat > "$conf_file" <<EOF
[global]
proxy = ${proxy_url}
EOF

    info "PIP 代理已写入: $conf_file"
}

proxy_pip_unset() {
    section "PIP"

    local conf_file="$HOME/.config/pip/pip.conf"
    if [[ -f "$conf_file" ]]; then
        rm -f "$conf_file"
        info "已删除: $conf_file"
    else
        warn "文件不存在，跳过: $conf_file"
    fi
}

# ─── Wget 代理 ─────────────────────────────────────────────
proxy_wget_set() {
    local proxy_url="$1"
    section "Wget"

    local conf_file="$HOME/.wgetrc"

    # 备份已有配置
    if [[ -f "$conf_file" ]] && ! grep -q "# PROXY_SCRIPT_MANAGED" "$conf_file"; then
        cp "$conf_file" "${conf_file}.bak.proxy"
        warn "已备份原有 .wgetrc → .wgetrc.bak.proxy"
    fi

    cat > "$conf_file" <<EOF
# PROXY_SCRIPT_MANAGED — 由 proxy.sh 自动生成，清除代理时会删除此文件
use_proxy = on
http_proxy = ${proxy_url}
https_proxy = ${proxy_url}
ftp_proxy = ${proxy_url}
no_proxy = localhost,127.0.0.1,::1,.local
EOF

    info "Wget 代理已写入: $conf_file"
}

proxy_wget_unset() {
    section "Wget"

    local conf_file="$HOME/.wgetrc"
    local bak_file="${conf_file}.bak.proxy"

    if [[ -f "$conf_file" ]] && grep -q "# PROXY_SCRIPT_MANAGED" "$conf_file"; then
        rm -f "$conf_file"
        info "已删除: $conf_file"

        # 恢复备份
        if [[ -f "$bak_file" ]]; then
            mv "$bak_file" "$conf_file"
            info "已恢复原有 .wgetrc"
        fi
    else
        warn ".wgetrc 非本脚本管理或不存在，跳过"
    fi
}

# ─── 显示当前代理状态 ──────────────────────────────────────
proxy_status() {
    section "当前代理状态"

    echo -e "${BOLD}Shell 环境变量:${NC}"
    echo "  http_proxy  = ${http_proxy:-<未设置>}"
    echo "  https_proxy = ${https_proxy:-<未设置>}"
    echo "  all_proxy   = ${all_proxy:-<未设置>}"
    echo "  no_proxy    = ${no_proxy:-<未设置>}"

    echo ""
    echo -e "${BOLD}Docker:${NC}"
    local docker_conf="/etc/systemd/system/docker.service.d/http-proxy.conf"
    if [[ -f "$docker_conf" ]]; then
        echo "  配置文件: $docker_conf"
        sed 's/^/  /' "$docker_conf"
    else
        echo "  <未配置>"
    fi

    echo ""
    echo -e "${BOLD}Git:${NC}"
    local git_http; git_http=$(git config --global --get http.proxy 2>/dev/null || echo "<未设置>")
    local git_https; git_https=$(git config --global --get https.proxy 2>/dev/null || echo "<未设置>")
    echo "  http.proxy  = $git_http"
    echo "  https.proxy = $git_https"

    echo ""
    echo -e "${BOLD}APT:${NC}"
    local apt_conf="/etc/apt/apt.conf.d/95proxy"
    if [[ -f "$apt_conf" ]]; then
        sed 's/^/  /' "$apt_conf"
    else
        echo "  <未配置>"
    fi

    echo ""
    echo -e "${BOLD}NPM:${NC}"
    if command -v npm &>/dev/null; then
        local npm_p; npm_p=$(npm config get proxy 2>/dev/null || echo "<未设置>")
        local npm_hp; npm_hp=$(npm config get https-proxy 2>/dev/null || echo "<未设置>")
        echo "  proxy       = $npm_p"
        echo "  https-proxy = $npm_hp"
    else
        echo "  npm 未安装"
    fi

    echo ""
    echo -e "${BOLD}PIP:${NC}"
    local pip_conf="$HOME/.config/pip/pip.conf"
    if [[ -f "$pip_conf" ]]; then
        sed 's/^/  /' "$pip_conf"
    else
        echo "  <未配置>"
    fi

    echo ""
    echo -e "${BOLD}Wget:${NC}"
    local wget_conf="$HOME/.wgetrc"
    if [[ -f "$wget_conf" ]] && grep -q "# PROXY_SCRIPT_MANAGED" "$wget_conf"; then
        sed 's/^/  /' "$wget_conf"
    else
        echo "  <未配置 (或非本脚本管理)>"
    fi
}

# ─── 使用说明 ───────────────────────────────────────────────
usage() {
    cat <<'HELP'
╔══════════════════════════════════════════════════════════════╗
║                   proxy.sh — 一键代理管理                    ║
╚══════════════════════════════════════════════════════════════╝

用法:
  source proxy.sh set  [代理地址] [选项...]   设置代理
  source proxy.sh unset [选项...]             清除代理
  bash   proxy.sh status                     查看当前代理状态

代理地址格式 (不填默认 http://127.0.0.1:8888):
  http://127.0.0.1:8888     完整 URL
  socks5://127.0.0.1:1080   SOCKS5 代理
  127.0.0.1:8888            自动补 http://
  8888                      自动补 http://127.0.0.1:

选项 (可组合使用):
  --docker   Docker 守护进程 (需要 sudo)
  --git      Git 全局配置
  --apt      APT 包管理器 (需要 sudo)
  --npm      NPM 包管理器
  --pip      PIP / Python
  --wget     Wget
  --all      以上全部

快捷命令:
  bash proxy.sh docker-set   [代理地址]   仅设置 Docker 代理
  bash proxy.sh docker-unset             仅清除 Docker 代理

示例:
  source proxy.sh set 7890                    Shell 代理 → http://127.0.0.1:7890
  source proxy.sh set 10.0.0.1:1080 --docker  Shell + Docker 代理
  source proxy.sh set --all                   所有代理 → 默认地址
  source proxy.sh unset --all                 清除所有代理
  bash   proxy.sh status                      查看状态

⚠ 注意:
  • 设置/清除 Shell 环境变量需要用 source 执行，否则只在子进程中生效
  • Docker / APT 修改需要 sudo 权限
HELP
}

# ─── 主逻辑 ─────────────────────────────────────────────────
main() {
    local action="${1:-}"
    shift 2>/dev/null || true

    case "$action" in
        set)
            # 解析参数
            local proxy_addr=""
            local do_docker=false
            local do_git=false
            local do_apt=false
            local do_npm=false
            local do_pip=false
            local do_wget=false

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --docker) do_docker=true ;;
                    --git)    do_git=true ;;
                    --apt)    do_apt=true ;;
                    --npm)    do_npm=true ;;
                    --pip)    do_pip=true ;;
                    --wget)   do_wget=true ;;
                    --all)
                        do_docker=true; do_git=true; do_apt=true
                        do_npm=true; do_pip=true; do_wget=true
                        ;;
                    -*)
                        error "未知选项: $1"
                        usage
                        return 1
                        ;;
                    *)
                        proxy_addr="$1"
                        ;;
                esac
                shift
            done

            local proxy_url
            proxy_url=$(parse_proxy "$proxy_addr")

            echo -e "\n${BOLD}🔧 设置代理: ${CYAN}${proxy_url}${NC}\n"

            proxy_shell_set "$proxy_url"

            $do_docker && proxy_docker_set "$proxy_url"
            $do_git    && proxy_git_set    "$proxy_url"
            $do_apt    && proxy_apt_set    "$proxy_url"
            $do_npm    && proxy_npm_set    "$proxy_url"
            $do_pip    && proxy_pip_set    "$proxy_url"
            $do_wget   && proxy_wget_set   "$proxy_url"

            echo ""
            info "代理设置完毕 ✨"
            ;;

        unset)
            local do_docker=false
            local do_git=false
            local do_apt=false
            local do_npm=false
            local do_pip=false
            local do_wget=false

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --docker) do_docker=true ;;
                    --git)    do_git=true ;;
                    --apt)    do_apt=true ;;
                    --npm)    do_npm=true ;;
                    --pip)    do_pip=true ;;
                    --wget)   do_wget=true ;;
                    --all)
                        do_docker=true; do_git=true; do_apt=true
                        do_npm=true; do_pip=true; do_wget=true
                        ;;
                    -*)
                        error "未知选项: $1"
                        usage
                        return 1
                        ;;
                esac
                shift
            done

            echo -e "\n${BOLD}🧹 清除代理${NC}\n"

            proxy_shell_unset

            $do_docker && proxy_docker_unset
            $do_git    && proxy_git_unset
            $do_apt    && proxy_apt_unset
            $do_npm    && proxy_npm_unset
            $do_pip    && proxy_pip_unset
            $do_wget   && proxy_wget_unset

            echo ""
            info "代理已清除 ✨"
            ;;

        docker-set)
            local proxy_url
            proxy_url=$(parse_proxy "${1:-}")
            echo -e "\n${BOLD}🐳 设置 Docker 代理: ${CYAN}${proxy_url}${NC}\n"
            proxy_docker_set "$proxy_url"
            echo ""
            info "Docker 代理设置完毕 ✨"
            ;;

        docker-unset)
            echo -e "\n${BOLD}🐳 清除 Docker 代理${NC}\n"
            proxy_docker_unset
            echo ""
            info "Docker 代理已清除 ✨"
            ;;

        status)
            proxy_status
            ;;

        help|--help|-h)
            usage
            ;;

        *)
            usage
            return 1
            ;;
    esac
}

main "$@"
