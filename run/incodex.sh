#!/bin/bash
# Codex配置脚本（适配 Codex CLI 0.16x 及以上版本）
# 默认方案：./setup-codex.sh --url https://your-domain.tld --key YOUR_KEY
# 中国大陆：./setup-codex.sh --mirror cn --url https://your-domain.tld --key YOUR_KEY
#
# API Key 写入 ~/.codex/auth.json（与 codex login --with-api-key 相同格式），
# 不再依赖 shell 环境变量，安装完成后任何终端都可以直接运行 codex。

set -e
set -o pipefail

# 输出的颜色函数
print_info() {
    echo -e "\033[34m[信息]\033[0m $1"
}

print_success() {
    echo -e "\033[32m[成功]\033[0m $1"
}

print_warning() {
    echo -e "\033[33m[警告]\033[0m $1"
}

print_error() {
    echo -e "\033[31m[错误]\033[0m $1"
}

has_admin_privilege() {
    if [ "$(id -u)" -eq 0 ]; then
        return 0
    fi

    if command -v sudo &> /dev/null; then
        sudo -v
        return $?
    fi

    return 1
}

run_as_admin() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

OFFICIAL_NODE_DIST_URL="https://nodejs.org/dist"
CN_NODE_DIST_URL="https://npmmirror.com/mirrors/node"
CN_NPM_REGISTRY="https://registry.npmmirror.com"

get_latest_node_lts_major() {
    local releases
    local source_url
    local version
    local major
    local sources=("$OFFICIAL_NODE_DIST_URL")

    if [ "$NETWORK_REGION" = "cn" ]; then
        sources=("$CN_NODE_DIST_URL" "$OFFICIAL_NODE_DIST_URL")
    fi

    releases=""
    for source_url in "${sources[@]}"; do
        print_info "正在获取 Node.js 最新 LTS 版本信息：$source_url"
        if releases=$(curl -fsSL --connect-timeout 10 --max-time 60 --retry 2 \
            "$source_url/index.json" 2>/dev/null); then
            LATEST_NODE_DOWNLOAD_BASE="$source_url"
            break
        fi

        if [ "$source_url" = "$CN_NODE_DIST_URL" ]; then
            print_warning "国内 Node.js 镜像暂时不可用，正在回退到官方源..."
        fi
    done

    if [ -z "$releases" ]; then
        print_error "获取 Node.js 最新 LTS 版本失败，请检查网络连接。"
        return 1
    fi

    version=$(awk '
        BEGIN { RS = "}," }
        $0 ~ /"lts":[[:space:]]*("[^"]+"|true)/ {
            version = $0
            sub(/^.*"version":[[:space:]]*"v/, "", version)
            sub(/".*$/, "", version)
            print version
            exit
        }
    ' <<< "$releases")

    if [ -z "$version" ]; then
        print_error "未能识别 Node.js 最新 LTS 版本。"
        return 1
    fi

    major="${version%%.*}"
    LATEST_NODE_LTS_VERSION="$version"
    LATEST_NODE_LTS_MAJOR="$major"
}

get_shell_config_path() {
    local shell_name=""

    if [ -n "$SHELL" ]; then
        shell_name=$(basename "$SHELL")
    elif [ -n "$BASH_VERSION" ]; then
        shell_name="bash"
    elif [ -n "$ZSH_VERSION" ]; then
        shell_name="zsh"
    elif [ -n "$FISH_VERSION" ]; then
        shell_name="fish"
    fi

    case "$shell_name" in
        bash)
            DETECTED_SHELL_CONFIG="$HOME/.bashrc"
            [ -f "$HOME/.bash_profile" ] && DETECTED_SHELL_CONFIG="$HOME/.bash_profile"
            ;;
        zsh)
            DETECTED_SHELL_CONFIG="$HOME/.zshrc"
            ;;
        fish)
            DETECTED_SHELL_CONFIG="$HOME/.config/fish/config.fish"
            ;;
        *)
            DETECTED_SHELL_CONFIG="$HOME/.profile"
            ;;
    esac

    DETECTED_SHELL_NAME="$shell_name"
}

persist_local_bin_path() {
    local shell_config
    local shell_name

    export PATH="$HOME/.local/bin:$PATH"
    get_shell_config_path
    shell_config="$DETECTED_SHELL_CONFIG"
    shell_name="$DETECTED_SHELL_NAME"
    mkdir -p "$(dirname "$shell_config")"

    if [ -f "$shell_config" ] && grep -Fq '$HOME/.local/bin' "$shell_config"; then
        return 0
    fi

    if [ "$shell_name" = "fish" ]; then
        printf '\n# Codex 本地命令路径\nset -gx PATH "$HOME/.local/bin" $PATH\n' >> "$shell_config"
    else
        printf '\n# Codex 本地命令路径\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$shell_config"
    fi

    print_info "已将 $HOME/.local/bin 加入 $shell_config"
}

install_nodejs_from_archive() {
    local node_version="$LATEST_NODE_LTS_VERSION"
    local os_type
    local platform
    local machine_arch
    local node_arch
    local archive_base
    local archive_name
    local temp_dir
    local archive_file
    local checksum_file
    local download_base
    local expected_checksum
    local actual_checksum
    local downloaded=false
    local install_root="$HOME/.local/lib/nodejs"
    local install_dir
    local executable
    local download_sources=("$LATEST_NODE_DOWNLOAD_BASE")

    if [ "$LATEST_NODE_DOWNLOAD_BASE" != "$OFFICIAL_NODE_DIST_URL" ]; then
        download_sources+=("$OFFICIAL_NODE_DIST_URL")
    fi

    if ! command -v tar &> /dev/null; then
        print_warning "未找到 tar，无法从 Node.js 压缩包安装。"
        return 1
    fi

    os_type=$(uname -s)
    case "$os_type" in
        Darwin) platform="darwin" ;;
        Linux) platform="linux" ;;
        *)
            print_warning "国内镜像安装暂不支持当前系统：$os_type"
            return 1
            ;;
    esac

    machine_arch=$(uname -m)
    case "$machine_arch" in
        x86_64|amd64) node_arch="x64" ;;
        arm64|aarch64) node_arch="arm64" ;;
        armv7l) node_arch="armv7l" ;;
        ppc64le) node_arch="ppc64le" ;;
        s390x) node_arch="s390x" ;;
        *)
            print_warning "国内镜像安装暂不支持当前架构：$machine_arch"
            return 1
            ;;
    esac

    archive_base="node-v${node_version}-${platform}-${node_arch}"
    archive_name="${archive_base}.tar.gz"
    temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/codex-node.XXXXXX")
    archive_file="$temp_dir/$archive_name"
    checksum_file="$temp_dir/SHASUMS256.txt"

    for download_base in "${download_sources[@]}"; do
        print_info "正在下载 Node.js v$node_version：$download_base"
        rm -f "$archive_file" "$checksum_file"

        if ! curl -fL --connect-timeout 10 --max-time 600 --retry 3 \
            "$download_base/v$node_version/$archive_name" -o "$archive_file"; then
            print_warning "Node.js 安装包下载失败：$download_base"
            continue
        fi

        if ! curl -fsSL --connect-timeout 10 --max-time 60 --retry 2 \
            "$download_base/v$node_version/SHASUMS256.txt" -o "$checksum_file"; then
            print_warning "无法下载 Node.js 校验文件：$download_base"
            continue
        fi

        expected_checksum=$(awk -v name="$archive_name" '$2 == name { print $1; exit }' "$checksum_file")
        if [ -z "$expected_checksum" ]; then
            print_warning "校验文件中未找到 $archive_name"
            continue
        fi

        if command -v sha256sum &> /dev/null; then
            actual_checksum=$(sha256sum "$archive_file" | awk '{print $1}')
        elif command -v shasum &> /dev/null; then
            actual_checksum=$(shasum -a 256 "$archive_file" | awk '{print $1}')
        else
            print_warning "未找到 SHA-256 校验工具，将回退到系统包管理器。"
            rm -rf "$temp_dir"
            return 1
        fi

        if [ "$actual_checksum" != "$expected_checksum" ]; then
            print_warning "Node.js 安装包校验失败：$download_base"
            continue
        fi

        downloaded=true
        break
    done

    if [ "$downloaded" != true ]; then
        rm -rf "$temp_dir"
        return 1
    fi

    if ! tar -xzf "$archive_file" -C "$temp_dir"; then
        print_warning "Node.js 安装包解压失败。"
        rm -rf "$temp_dir"
        return 1
    fi

    install_dir="$install_root/$archive_base"
    mkdir -p "$install_root" "$HOME/.local/bin"

    if [ -d "$install_dir" ]; then
        if [ ! -x "$install_dir/bin/node" ]; then
            print_warning "现有 Node.js 目录不完整：$install_dir"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        mv "$temp_dir/$archive_base" "$install_dir"
    fi

    for executable in node npm npx corepack; do
        if [ -e "$install_dir/bin/$executable" ]; then
            ln -sfn "$install_dir/bin/$executable" "$HOME/.local/bin/$executable"
        fi
    done

    rm -rf "$temp_dir"
    persist_local_bin_path

    if command -v node &> /dev/null; then
        print_success "Node.js 安装成功：$(node --version)"
        return 0
    fi

    return 1
}

# 检测 Codex 是否已安装
check_codex() {
    if command -v codex &> /dev/null; then
        local version=$(codex --version 2>/dev/null || echo "unknown")
        print_success "Codex 已安装：$version"
        return 0
    else
        return 1
    fi
}

# 检测 Node.js 是否已安装
check_nodejs() {
    if command -v node &> /dev/null; then
        local version=$(node --version 2>/dev/null || echo "unknown")
        # 检查版本是否 >= 18
        if [[ "$version" =~ ^v?([0-9]+) ]]; then
            local major_version="${BASH_REMATCH[1]}"
            if [ "$major_version" -ge 18 ]; then
                print_success "Node.js 已安装：$version"
                return 0
            else
                print_warning "Node.js 版本过旧：$version（需要 18.0.0 或更高版本）"
                return 1
            fi
        fi
    fi
    return 1
}

# 安装 Node.js
install_nodejs() {
    print_info "未检测到可用的 Node.js，或版本过旧，正在安装 Node.js latest LTS..."

    if ! get_latest_node_lts_major; then
        return 1
    fi

    local node_major="$LATEST_NODE_LTS_MAJOR"
    print_info "将安装 Node.js LTS 主版本：$node_major"

    if [ "$NETWORK_REGION" = "cn" ]; then
        print_info "中国大陆模式：优先使用国内镜像安装 Node.js。"
        if install_nodejs_from_archive; then
            return 0
        fi
        print_warning "镜像安装失败，正在回退到现有的系统安装方案..."
    fi

    # 检测操作系统
    local os_type="$(uname -s)"

    if [ "$os_type" = "Darwin" ]; then
        # macOS
        if command -v brew &> /dev/null; then
            print_info "正在使用 Homebrew 安装 Node.js LTS：node@$node_major"
            if brew install "node@$node_major"; then
                local node_prefix
                node_prefix=$(brew --prefix "node@$node_major" 2>/dev/null || true)
                if [ -n "$node_prefix" ] && [ -d "$node_prefix/bin" ]; then
                    export PATH="$node_prefix/bin:$PATH"
                fi
                return 0
            fi

            print_warning "Homebrew 安装 node@$node_major 失败，请从 https://nodejs.org/ 手动安装 Node.js latest LTS。"
            return 1
        else
            print_warning "未找到 Homebrew，请从 https://nodejs.org/ 手动安装 Node.js latest LTS。"
            return 1
        fi
    elif [ "$os_type" = "Linux" ]; then
        if ! has_admin_privilege; then
            print_error "自动安装 Node.js 需要管理员权限。请使用具备 sudo 权限的用户重新运行本脚本。"
            return 1
        fi

        # Linux
        if command -v apt-get &> /dev/null; then
            # Debian/Ubuntu
            print_info "正在使用 apt 安装 Node.js LTS..."
            curl -fsSL "https://deb.nodesource.com/setup_${node_major}.x" | run_as_admin bash -
            run_as_admin apt-get install -y nodejs
            return $?
        elif command -v dnf &> /dev/null; then
            # Fedora/RHEL
            print_info "正在使用 dnf 安装 Node.js LTS..."
            curl -fsSL "https://rpm.nodesource.com/setup_${node_major}.x" | run_as_admin bash -
            run_as_admin dnf install -y nodejs
            return $?
        elif command -v yum &> /dev/null; then
            # RHEL/CentOS
            print_info "正在使用 yum 安装 Node.js LTS..."
            curl -fsSL "https://rpm.nodesource.com/setup_${node_major}.x" | run_as_admin bash -
            run_as_admin yum install -y nodejs
            return $?
        else
            print_warning "未找到支持的包管理器，请从 https://nodejs.org/ 手动安装 Node.js latest LTS。"
            return 1
        fi
    else
        print_warning "不支持当前系统，请从 https://nodejs.org/ 手动安装 Node.js latest LTS。"
        return 1
    fi
}

run_codex_npm_install() {
    local use_admin="$1"
    local registry_url="$2"
    local npm_args=(install -g @openai/codex@latest --no-audit --no-fund --loglevel=error)

    if [ -n "$registry_url" ]; then
        npm_args+=(--registry "$registry_url")
    fi

    if [ "$NETWORK_REGION" = "cn" ]; then
        npm_args+=(--prefix "$HOME/.local")
    fi

    if [ "$use_admin" = true ]; then
        run_as_admin npm "${npm_args[@]}"
    else
        npm "${npm_args[@]}"
    fi
}

try_codex_npm_sources() {
    local use_admin="$1"

    if [ "$NETWORK_REGION" = "cn" ]; then
        print_info "正在使用国内 npm 镜像安装 Codex CLI：$CN_NPM_REGISTRY"
        if run_codex_npm_install "$use_admin" "$CN_NPM_REGISTRY"; then
            return 0
        fi
        print_warning "国内 npm 镜像安装失败，正在回退到 npm 官方源..."
    fi

    run_codex_npm_install "$use_admin" ""
}

# 安装 Codex
install_codex() {
    print_info "正在安装 Codex CLI..."

    # 检查 npm 是否可用
    if ! command -v npm &> /dev/null; then
        print_error "npm 当前不可用。请在 Node.js 安装完成后重新打开终端，再运行本脚本。"
        return 1
    fi

    local npm_version=$(npm --version 2>/dev/null || echo "unknown")
    local npm_prefix

    if [ "$NETWORK_REGION" = "cn" ]; then
        npm_prefix="$HOME/.local"
        mkdir -p "$npm_prefix/bin"
        persist_local_bin_path
    else
        npm_prefix=$(npm config get prefix 2>/dev/null || true)
    fi

    print_info "npm 版本：$npm_version"

    if [ -n "$npm_prefix" ] && [ -d "$npm_prefix/bin" ]; then
        export PATH="$npm_prefix/bin:$PATH"
    fi

    local use_admin=false
    if [ -n "$npm_prefix" ] && [ ! -w "$npm_prefix" ]; then
        use_admin=true
        if ! has_admin_privilege; then
            print_error "自动安装 Codex CLI 需要管理员权限。请使用具备 sudo 权限的用户重新运行本脚本。"
            return 1
        fi
    fi

    local install_status=1
    print_info "正在安装：@openai/codex"
    if [ "$use_admin" = true ]; then
        if try_codex_npm_sources true; then
            install_status=0
        else
            install_status=$?
        fi
    else
        if try_codex_npm_sources false; then
            install_status=0
        else
            install_status=$?
        fi
        if [ "$install_status" -ne 0 ] && has_admin_privilege; then
            print_warning "直接安装失败，正在尝试使用管理员权限重新安装 Codex CLI..."
            if try_codex_npm_sources true; then
                install_status=0
            else
                install_status=$?
            fi
        fi
    fi

    if [ "$install_status" -eq 0 ]; then
        if [ -n "$npm_prefix" ] && [ -d "$npm_prefix/bin" ]; then
            export PATH="$npm_prefix/bin:$PATH"
        fi

        # 验证安装
        if command -v codex &> /dev/null; then
            local version=$(codex --version 2>/dev/null || echo "unknown")
            print_success "Codex 安装成功：$version"
            return 0
        else
            print_warning "Codex 已安装，但当前终端暂时无法识别 codex 命令。请重新打开终端后运行 codex --version 验证。"
            return 0
        fi
    else
        print_error "安装 Codex 失败"
        return 1
    fi
}

get_installed_codex_version() {
    codex --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -n 1 || true
}

get_latest_codex_version() {
    local version=""

    if [ "$NETWORK_REGION" = "cn" ]; then
        version=$(npm view @openai/codex version --registry "$CN_NPM_REGISTRY" 2>/dev/null || true)
    fi
    if [ -z "$version" ]; then
        version=$(npm view @openai/codex version 2>/dev/null || true)
    fi

    printf '%s' "$version"
}

# 当前 codex 是否由本脚本会使用的 npm 前缀安装（只升级这种情况，避免与 brew 等安装方式重复）
codex_managed_by_script_npm() {
    local npm_prefix

    if [ "$NETWORK_REGION" = "cn" ]; then
        npm_prefix="$HOME/.local"
    else
        npm_prefix=$(npm config get prefix 2>/dev/null || true)
    fi

    [ -n "$npm_prefix" ] && [ -d "$npm_prefix/lib/node_modules/@openai/codex" ]
}

# 已安装时检查是否为最新版本，旧版本可能不兼容新的配置项
upgrade_codex_if_outdated() {
    local installed_version
    local latest_version

    if ! command -v npm &> /dev/null; then
        return 0
    fi

    installed_version=$(get_installed_codex_version)
    latest_version=$(get_latest_codex_version)

    if [ -z "$installed_version" ] || [ -z "$latest_version" ]; then
        print_warning "无法确认 Codex 最新版本，跳过升级检查。"
        return 0
    fi

    if [ "$installed_version" = "$latest_version" ]; then
        print_success "Codex 已是最新版本：$installed_version"
        return 0
    fi

    if ! codex_managed_by_script_npm; then
        print_warning "当前 Codex 版本 $installed_version，最新版本 $latest_version。"
        print_warning "检测到 Codex 不是通过 npm 安装的，请使用原安装方式手动升级。"
        return 0
    fi

    print_info "Codex 版本 $installed_version 较旧，正在升级到 $latest_version..."
    if ! install_codex; then
        print_warning "Codex 升级失败，将继续使用当前版本：$installed_version"
    fi
    return 0
}

# 确保 Codex 已安装
ensure_codex() {
    print_info "正在检查 Codex 是否已安装..."

    # 检测 Codex 是否已安装
    if check_codex; then
        upgrade_codex_if_outdated
        return 0
    fi

    print_warning "未检测到 Codex"

    # 检测 Node.js 是否已安装
    if ! check_nodejs; then
        # 尝试安装 Node.js
        if ! install_nodejs; then
            print_warning "自动安装 Node.js 失败"
            return 1
        fi
    fi

    # 安装 Codex
    if install_codex; then
        return 0
    else
        print_warning "自动安装 Codex 失败"
        return 1
    fi
}

# 默认值
DEFAULT_BASE_URL="http://localhost:8080"
DEFAULT_MODEL="gpt-5.6-sol"
BASE_URL=""
API_KEY=""
MODEL=""
NETWORK_REGION="global"
SHOW_SETTINGS=false

# 显示帮助的函数
show_help() {
    cat << EOF
Codex 配置脚本

用法：$0 [选项]

选项：
  --url URL        设置 API 地址（默认：$DEFAULT_BASE_URL）
                   Codex 会请求 <URL>/responses，如服务商要求 /v1 请一并填写
  --key KEY        设置 API Key
  --model MODEL    设置默认模型（默认：$DEFAULT_MODEL）
  --mirror cn      启用中国大陆 Node.js/npm 镜像优化
  --show           显示当前配置后退出
  --help           显示此帮助信息

示例：
  $0 --url https://your-domain.tld --key your-api-key-here
  $0 --mirror cn --url https://your-domain.tld --key your-api-key-here
  $0 --url https://your-domain.tld/v1 --key your-api-key-here --model gpt-5.6-sol
  $0 --show

交互模式（不传参数）：
  $0

默认使用原有官方源安装流程。只有显式传入 --mirror cn 时才启用国内镜像，
国内镜像失败时会自动回退到官方源。
EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --url)
            if [ "$#" -lt 2 ]; then
                print_error "--url 需要提供 URL"
                exit 1
            fi
            BASE_URL="$2"
            shift 2
            ;;
        --key)
            if [ "$#" -lt 2 ]; then
                print_error "--key 需要提供 API Key"
                exit 1
            fi
            API_KEY="$2"
            shift 2
            ;;
        --model)
            if [ "$#" -lt 2 ]; then
                print_error "--model 需要提供模型名称"
                exit 1
            fi
            MODEL="$2"
            shift 2
            ;;
        --mirror)
            if [ "$#" -lt 2 ]; then
                print_error "--mirror 需要提供 cn"
                exit 1
            fi
            NETWORK_REGION="$2"
            shift 2
            ;;
        # 兼容上一版脚本的参数，新用法请使用 --mirror cn。
        --region)
            if [ "$#" -lt 2 ]; then
                print_error "--region 需要提供 cn 或 global"
                exit 1
            fi
            NETWORK_REGION="$2"
            shift 2
            ;;
        --show)
            SHOW_SETTINGS=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            print_error "未知选项：$1"
            show_help
            exit 1
            ;;
    esac
done

normalize_network_region() {
    case "$NETWORK_REGION" in
        cn|CN|china|China|mainland)
            NETWORK_REGION="cn"
            ;;
        global|GLOBAL|Global|other|intl|international)
            NETWORK_REGION="global"
            ;;
        *)
            print_error "未知的镜像方案：$NETWORK_REGION（使用 --mirror cn，或省略该参数）"
            return 1
            ;;
    esac
}

network_region_label() {
    if [ "$NETWORK_REGION" = "cn" ]; then
        printf '中国大陆优化（国内镜像优先，官方源备用）'
    else
        printf '其他地区（原有官方源）'
    fi
}

# 只拦截会破坏 JSON / shell 配置的字符，不限制第三方服务商的 Key 格式
validate_api_key() {
    local api_key="$1"

    case "$api_key" in
        *[[:space:]]*|*\"*|*\'*|*\\*|*\`*|*\$*)
            print_error "API Key 不能包含空白字符、引号、反斜杠、反引号或 \$。"
            return 1
            ;;
    esac

    return 0
}

validate_simple_value() {
    local label="$1"
    local value="$2"

    case "$value" in
        *[[:space:]]*|*\"*|*\'*|*\\*|*\`*|*\$*)
            print_error "$label 不能包含空白字符、引号、反斜杠、反引号或 \$。"
            return 1
            ;;
    esac

    return 0
}

validate_base_url() {
    local base_url="$1"

    case "$base_url" in
        http://*|https://*) ;;
        *)
            print_error "API 地址必须以 http:// 或 https:// 开头：$base_url"
            return 1
            ;;
    esac

    validate_simple_value "API 地址" "$base_url"
}

# 从终端读取输入（兼容 curl ... | bash 的管道运行方式）
prompt_input() {
    local prompt="$1"
    local __var_name="$2"
    local __value=""

    # 注意：read -p 的提示输出到 stderr，不能对 read 本身重定向 2>/dev/null，否则提示不可见
    if [ -t 0 ]; then
        read -r -p "$prompt" __value || true
    elif (: < /dev/tty) 2>/dev/null; then
        read -r -p "$prompt" __value < /dev/tty || true
    else
        read -r -p "$prompt" __value || true
    fi

    printf -v "$__var_name" '%s' "$__value"
}

# 备份现有配置的函数
backup_config() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local file

    for file in config.toml auth.json; do
        if [ -f "$HOME/.codex/$file" ]; then
            local backup_file="$HOME/.codex/$file.backup.$timestamp"
            cp "$HOME/.codex/$file" "$backup_file"
            chmod 600 "$backup_file" 2>/dev/null || true
            print_info "已备份现有 $file 到：$backup_file"
        fi
    done
}

# 写入 Codex 认证文件（与 codex login --with-api-key 生成的格式一致）
write_codex_auth() {
    local api_key="$1"
    local config_dir="$HOME/.codex"
    local auth_file="$config_dir/auth.json"
    local temp_file

    mkdir -p "$config_dir"
    temp_file=$(mktemp "$config_dir/.auth.XXXXXX")
    chmod 600 "$temp_file"
    printf '{\n  "auth_mode": "apikey",\n  "OPENAI_API_KEY": "%s"\n}\n' "$api_key" > "$temp_file"
    mv "$temp_file" "$auth_file"
    chmod 600 "$auth_file" 2>/dev/null || true

    print_success "API Key 已写入：$auth_file"
}

toml_quote() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '"%s"' "$value"
}

write_toml_settings_file() {
    local file="$1"
    shift

    : > "$file"
    while [ "$#" -gt 0 ]; do
        printf '%s\t%s\n' "$1" "$2" >> "$file"
        shift 2
    done
}

merge_toml_section() {
    local source_file="$1"
    local target_file="$2"
    local section_name="$3"
    local settings_file="$4"

    awk -v section="$section_name" -v settings_file="$settings_file" '
        function trim(value) {
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            return value
        }

        function is_section_header(line) {
            return line ~ /^[[:space:]]*\[[^]]+\][[:space:]]*(#.*)?$/
        }

        function get_section_name(line, value) {
            value = line
            sub(/^[[:space:]]*\[/, "", value)
            sub(/\][[:space:]]*(#.*)?$/, "", value)
            return trim(value)
        }

        function flush_blanks() {
            while (pending_blanks > 0) {
                print ""
                pending_blanks--
            }
        }

        function emit_missing(    i, key) {
            for (i = 1; i <= key_count; i++) {
                key = keys[i]
                if (!updated[key] && values[key] != REMOVE) {
                    print key " = " values[key]
                    updated[key] = 1
                }
            }
        }

        BEGIN {
            # 值为 __REMOVE__ 的键会从该节中删除（用于清理新版 Codex 已废弃的配置）
            REMOVE = "__REMOVE__"
            has_values = 0
            while ((getline line < settings_file) > 0) {
                key = line
                sub(/\t.*$/, "", key)
                value = line
                sub(/^[^\t]*\t/, "", value)
                keys[++key_count] = key
                values[key] = value
                updated[key] = 0
                if (value != REMOVE) {
                    has_values = 1
                }
            }
            close(settings_file)

            in_section = (section == "")
            found_section = (section == "")
        }

        {
            line = $0

            # 暂存空行，保证补充的键写在节内容末尾、空行之前
            if (line ~ /^[[:space:]]*$/) {
                pending_blanks++
                next
            }

            if (is_section_header(line)) {
                if (in_section) {
                    emit_missing()
                }
                flush_blanks()

                current_section = get_section_name(line)
                if (section != "" && current_section == section) {
                    found_section = 1
                    in_section = 1
                } else {
                    in_section = 0
                }

                print line
                next
            }

            flush_blanks()

            if (in_section) {
                for (i = 1; i <= key_count; i++) {
                    key = keys[i]
                    pattern = "^[[:space:]]*" key "[[:space:]]*="
                    if (line ~ pattern) {
                        updated[key] = 1
                        if (values[key] == REMOVE) {
                            next
                        }
                        match(line, /^[[:space:]]*/)
                        indent = substr(line, RSTART, RLENGTH)
                        print indent key " = " values[key]
                        next
                    }
                }
            }

            print line
        }

        END {
            if (in_section) {
                emit_missing()
            }
            flush_blanks()

            if (!found_section && has_values) {
                if (NR > 0) {
                    print ""
                }
                if (section != "") {
                    print "[" section "]"
                }
                emit_missing()
            }
        }
    ' "$source_file" > "$target_file"
}

# 删除整个 TOML 节（新版 Codex 已不再识别的节）
drop_toml_section() {
    local source_file="$1"
    local target_file="$2"
    local section_name="$3"

    awk -v section="$section_name" '
        function trim(value) {
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            return value
        }

        /^[[:space:]]*\[[^]]+\][[:space:]]*(#.*)?$/ {
            name = $0
            sub(/^[[:space:]]*\[/, "", name)
            sub(/\][[:space:]]*(#.*)?$/, "", name)
            name = trim(name)
            skipping = (name == section || index(name, section ".") == 1)
        }

        !skipping { print }
    ' "$source_file" > "$target_file"
}

# 创建或合并 Codex 配置的函数
create_codex_config() {
    local base_url="$1"
    local model="$2"
    local config_dir="$HOME/.codex"
    local config_file="$config_dir/config.toml"

    mkdir -p "$config_dir"

    local root_settings
    local provider_settings
    local feature_settings
    local sandbox_settings
    local source_file
    local target_file

    root_settings=$(mktemp "$config_dir/.root-settings.XXXXXX")
    provider_settings=$(mktemp "$config_dir/.provider-settings.XXXXXX")
    feature_settings=$(mktemp "$config_dir/.feature-settings.XXXXXX")
    sandbox_settings=$(mktemp "$config_dir/.sandbox-settings.XXXXXX")
    source_file=$(mktemp "$config_dir/.config-source.XXXXXX")
    target_file=$(mktemp "$config_dir/.config-target.XXXXXX")

    if [ -f "$config_file" ]; then
        cp "$config_file" "$source_file"
    fi

    # disable_response_storage 已被新版 Codex 移除
    write_toml_settings_file "$root_settings" \
        "model_provider" "$(toml_quote "codex")" \
        "model" "$(toml_quote "$model")" \
        "model_reasoning_effort" "$(toml_quote "high")" \
        "sandbox_mode" "$(toml_quote "danger-full-access")" \
        "disable_response_storage" "__REMOVE__"

    # requires_openai_auth = true：使用 ~/.codex/auth.json 中的 Key 作为 Bearer Token，
    # 不再依赖 env_key 环境变量（新开终端、IDE 插件中未加载环境变量时会报 Missing environment variable）
    write_toml_settings_file "$provider_settings" \
        "name" "$(toml_quote "codex")" \
        "base_url" "$(toml_quote "$base_url")" \
        "wire_api" "$(toml_quote "responses")" \
        "requires_openai_auth" "true" \
        "supports_websockets" "false" \
        "http_headers" '{ "x-openai-actor-authorization" = "codex-compatible-image-generation" }' \
        "env_key" "__REMOVE__"

    # 以下特性开关在新版 Codex 中已移除或已默认启用，写入只会产生 "ignored" 警告
    write_toml_settings_file "$feature_settings" \
        "image_generation" "true" \
        "apply_patch_freeform" "__REMOVE__" \
        "plan_tool" "__REMOVE__" \
        "rmcp_client" "__REMOVE__" \
        "streamable_shell" "__REMOVE__" \
        "unified_exec" "__REMOVE__" \
        "view_image_tool" "__REMOVE__" \
        "experimental_windows_sandbox" "__REMOVE__" \
        "parallel" "__REMOVE__"

    write_toml_settings_file "$sandbox_settings" \
        "network_access" "true"

    merge_toml_section "$source_file" "$target_file" "" "$root_settings"
    mv "$target_file" "$source_file"

    target_file=$(mktemp "$config_dir/.config-target.XXXXXX")
    merge_toml_section "$source_file" "$target_file" "model_providers.codex" "$provider_settings"
    mv "$target_file" "$source_file"

    # [experimental] 节已被新版 Codex 移除
    target_file=$(mktemp "$config_dir/.config-target.XXXXXX")
    drop_toml_section "$source_file" "$target_file" "experimental"
    mv "$target_file" "$source_file"

    target_file=$(mktemp "$config_dir/.config-target.XXXXXX")
    merge_toml_section "$source_file" "$target_file" "features" "$feature_settings"
    mv "$target_file" "$source_file"

    target_file=$(mktemp "$config_dir/.config-target.XXXXXX")
    merge_toml_section "$source_file" "$target_file" "sandbox_workspace_write" "$sandbox_settings"
    mv "$target_file" "$config_file"

    rm -f "$root_settings" "$provider_settings" "$feature_settings" "$sandbox_settings" "$source_file" "$target_file"

    print_success "Codex 配置已合并写入：$config_file"
    return 0
}

# 在 shell 配置文件中新增或更新一行环境变量
# 使用 awk + ENVIRON 传值，Key 中的 & | / 等字符无需转义
upsert_shell_env() {
    local shell_config="$1"
    local is_fish="$2"
    local name="$3"
    local value="$4"
    local comment="$5"
    local match_prefix
    local new_line
    local temp_file

    if [ "$is_fish" = true ]; then
        match_prefix="set -x $name "
        new_line="set -x $name \"$value\""
    else
        match_prefix="export $name="
        new_line="export $name=\"$value\""
    fi

    if [ -f "$shell_config" ] && grep -q "^[[:space:]]*$match_prefix" "$shell_config"; then
        temp_file=$(mktemp "${TMPDIR:-/tmp}/codex-shellrc.XXXXXX")
        UPSERT_PREFIX="$match_prefix" UPSERT_LINE="$new_line" awk '
            {
                match($0, /^[[:space:]]*/)
                indent = substr($0, RSTART, RLENGTH)
                if (index(substr($0, RLENGTH + 1), ENVIRON["UPSERT_PREFIX"]) == 1) {
                    print indent ENVIRON["UPSERT_LINE"]
                    next
                }
                print
            }
        ' "$shell_config" > "$temp_file"
        # 用 cat 覆盖而不是 mv，保留原文件权限和软链接
        cat "$temp_file" > "$shell_config"
        rm -f "$temp_file"
        print_info "已更新 $shell_config 中的 $name"
    else
        printf '\n# %s\n%s\n' "$comment" "$new_line" >> "$shell_config"
        print_info "已将 $name 写入 $shell_config"
    fi
}

# 设置环境变量的函数
# Codex 本身已改为读取 ~/.codex/auth.json；这里同步环境变量，避免旧脚本写入的过期
# CODEX_API_KEY 覆盖 auth.json（codex exec 会优先使用 CODEX_API_KEY 环境变量）。
set_environment_variable() {
    local base_url="$1"
    local api_key="$2"
    local shell_config
    local shell_name
    local is_fish=false

    # 为当前会话导出
    export OPENAI_BASE_URL="$base_url"
    export OPENAI_API_KEY="$api_key"
    export CODEX_API_KEY="$api_key"

    get_shell_config_path
    shell_config="$DETECTED_SHELL_CONFIG"
    shell_name="$DETECTED_SHELL_NAME"

    print_info "检测到的 Shell：${shell_name:-unknown}"
    print_info "使用的配置文件：$shell_config"

    if [ "$shell_name" = "fish" ] || [[ "$shell_config" == *"fish"* ]]; then
        is_fish=true
    fi

    mkdir -p "$(dirname "$shell_config")"

    upsert_shell_env "$shell_config" "$is_fish" "OPENAI_BASE_URL" "$base_url" "Codex 环境变量"
    upsert_shell_env "$shell_config" "$is_fish" "OPENAI_API_KEY" "$api_key" "OpenAI API 密钥"
    upsert_shell_env "$shell_config" "$is_fish" "CODEX_API_KEY" "$api_key" "Codex API 密钥"

    print_success "环境变量 OPENAI_BASE_URL、OPENAI_API_KEY 和 CODEX_API_KEY 设置成功"
    return 0
}

mask_secret() {
    local value="$1"

    if [ ${#value} -gt 12 ]; then
        printf '%s' "${value:0:8}...${value: -4}"
    else
        printf '%s' "${value:0:4}..."
    fi
}

# 显示当前设置的函数
show_current_settings() {
    local auth_file="$HOME/.codex/auth.json"
    local auth_key

    print_info "当前 Codex 配置："
    echo "----------------------------------------"

    if [ -f "$HOME/.codex/config.toml" ]; then
        print_info "配置文件：$HOME/.codex/config.toml"
        echo ""
        cat "$HOME/.codex/config.toml"
        echo ""
    else
        print_info "未找到配置文件：$HOME/.codex/config.toml"
    fi

    echo "----------------------------------------"
    if [ -f "$auth_file" ]; then
        auth_key=$(sed -n 's/.*"OPENAI_API_KEY"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$auth_file" | head -n 1)
        if [ -n "$auth_key" ]; then
            print_info "认证文件：$auth_file（API Key：$(mask_secret "$auth_key")）"
        else
            print_info "认证文件：$auth_file（未包含 API Key，可能是 ChatGPT 登录）"
        fi
    else
        print_info "未找到认证文件：$auth_file"
    fi

    echo "----------------------------------------"
    print_info "环境变量："

    if [ -n "$OPENAI_BASE_URL" ]; then
        print_info "OPENAI_BASE_URL：$OPENAI_BASE_URL"
    else
        print_info "OPENAI_BASE_URL：未设置"
    fi

    if [ -n "$OPENAI_API_KEY" ]; then
        print_info "OPENAI_API_KEY：$(mask_secret "$OPENAI_API_KEY")"
    else
        print_info "OPENAI_API_KEY：未设置"
    fi

    if [ -n "$CODEX_API_KEY" ]; then
        print_info "CODEX_API_KEY：$(mask_secret "$CODEX_API_KEY")"
    else
        print_info "CODEX_API_KEY：未设置"
    fi

    echo "----------------------------------------"
}

# 主函数
main() {
    print_info "Codex 配置脚本"
    echo "======================================="
    echo ""

    if ! normalize_network_region; then
        exit 1
    fi

    # 如果要求则显示当前设置并退出
    if [ "$SHOW_SETTINGS" = true ]; then
        show_current_settings
        exit 0
    fi

    # 未提供URL或密钥时交互输入
    if [ -z "$BASE_URL" ] || [ -z "$API_KEY" ]; then
        print_info "进入交互配置模式"
        echo ""

        if [ -z "$BASE_URL" ]; then
            prompt_input "请输入 API 地址 [$DEFAULT_BASE_URL]: " input_url
            BASE_URL="${input_url:-$DEFAULT_BASE_URL}"
        fi

        if [ -z "$MODEL" ]; then
            prompt_input "请输入模型名称 [$DEFAULT_MODEL]: " input_model
            MODEL="${input_model:-$DEFAULT_MODEL}"
        fi

        local attempts=0
        while [ -z "$API_KEY" ] && [ "$attempts" -lt 5 ]; do
            prompt_input "请输入 API Key: " API_KEY
            attempts=$((attempts + 1))
            if [ -z "$API_KEY" ]; then
                print_warning "API Key 不能为空"
            fi
        done
    fi

    MODEL="${MODEL:-$DEFAULT_MODEL}"

    # 验证输入
    if [ -z "$BASE_URL" ] || [ -z "$API_KEY" ]; then
        print_error "API 地址和 API Key 都不能为空"
        print_info "可使用 --help 查看用法"
        exit 1
    fi

    # 移除URL末尾的斜杠
    BASE_URL="${BASE_URL%/}"

    if ! validate_base_url "$BASE_URL" || ! validate_api_key "$API_KEY" || ! validate_simple_value "模型名称" "$MODEL"; then
        exit 1
    fi

    print_info "本次配置："
    print_info "  API 地址：$BASE_URL（Codex 请求地址：$BASE_URL/responses）"
    print_info "  模型：$MODEL"
    print_info "  网络方案：$(network_region_label)"
    print_info "  API Key：$(mask_secret "$API_KEY")"
    echo ""

    # 备份现有配置
    backup_config

    # 创建Codex配置
    if ! create_codex_config "$BASE_URL" "$MODEL"; then
        print_error "创建 Codex 配置失败"
        exit 1
    fi

    # 写入认证文件（Codex 实际使用的 Key）
    if ! write_codex_auth "$API_KEY"; then
        print_error "写入 Codex 认证文件失败"
        exit 1
    fi

    # 同步环境变量（兼容旧配置，Codex 不再依赖它们）
    if ! set_environment_variable "$BASE_URL" "$API_KEY"; then
        print_warning "自动设置环境变量失败，不影响 Codex 使用。"
    fi

    echo ""
    print_success "配置已保存"
    print_info "配置文件：$HOME/.codex/config.toml"
    print_info "认证文件：$HOME/.codex/auth.json"
    echo

    # 检查 Codex 是否已安装，未安装时自动安装，已安装则检查升级
    if ensure_codex; then
        print_success "Codex 已安装，可以开始使用！"
        print_info "直接运行 'codex' 即可开始使用。"
        if [ "$NETWORK_REGION" = "cn" ]; then
            print_info "如提示 codex: command not found，请重新打开终端（已将 \$HOME/.local/bin 加入 PATH）。"
        fi
    else
        print_warning "Codex 未安装。如需手动安装："
        if [ "$NETWORK_REGION" = "cn" ]; then
            print_info "1. 从 $CN_NODE_DIST_URL 下载 Node.js latest LTS"
            print_info "2. 运行：npm install -g @openai/codex@latest --registry $CN_NPM_REGISTRY"
        else
            print_info "1. 从 https://nodejs.org/ 安装 Node.js latest LTS"
            print_info "2. 运行：npm install -g @openai/codex@latest --no-audit --no-fund --loglevel=error"
        fi
    fi

    # 显示当前设置
    echo ""
    show_current_settings
}

# 运行主函数
main
