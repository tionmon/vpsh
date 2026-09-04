#!/bin/bash
# Codex配置脚本
# 默认方案：./setup-codex.sh --url https://your-domain.tld --key YOUR_KEY
# 中国大陆：./setup-codex.sh --mirror cn --url https://your-domain.tld --key YOUR_KEY

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
    local npm_args=(install -g @openai/codex --no-audit --no-fund --loglevel=error)

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

# 确保 Codex 已安装
ensure_codex() {
    print_info "正在检查 Codex 是否已安装..."

    # 检测 Codex 是否已安装
    if check_codex; then
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
BASE_URL=""
API_KEY=""
NETWORK_REGION="global"
TEST_ONLY=false
SHOW_SETTINGS=false

# 显示帮助的函数
show_help() {
    cat << EOF
Codex 配置脚本

用法：$0 [选项]

选项：
  --url URL        设置 API 地址（默认：$DEFAULT_BASE_URL）
  --key KEY        设置 API Key
  --mirror cn      启用中国大陆 Node.js/npm 镜像优化
  --test           只测试 API 连接（需要同时提供 --url 和 --key）
  --show           显示当前配置后退出
  --help           显示此帮助信息

示例：
  $0 --url https://your-domain.tld --key your-api-key-here
  $0 --mirror cn --url https://your-domain.tld --key your-api-key-here
  $0 --test --url https://your-domain.tld --key your-api-key-here
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
        --test)
            TEST_ONLY=true
            shift
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

validate_api_key() {
    local api_key="$1"

    if [[ "$api_key" =~ ^[A-Za-z0-9_-]+$ ]]; then
        return 0
    fi

    print_error "API Key 格式不正确，只能包含字母、数字、连字符和下划线。"
    return 1
}

# 备份现有配置的函数
backup_config() {
    local timestamp=$(date +%Y%m%d_%H%M%S)

    if [ -f "$HOME/.codex/config.toml" ]; then
        local backup_file="$HOME/.codex/config.toml.backup.$timestamp"
        cp "$HOME/.codex/config.toml" "$backup_file"
        print_info "已备份现有配置到：$backup_file"
    fi
}

# 测试API连接的函数
test_api_connection() {
    local base_url="$1"
    local api_key="$2"
    
    print_info "正在测试 API 连接..."
    
    # 根据是否为团队URL确定正确的端点
    local test_endpoint
    local balance_field
    test_endpoint="${base_url}/health"
    balance_field="status"
    
    # 尝试获取余额以验证API密钥
    local response
    if ! response=$(curl -s --connect-timeout 10 -o /dev/null -w "%{http_code}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        "$test_endpoint" 2>/dev/null); then
        response="000"
    fi
    
    if [ "$response" = "200" ]; then
        # 200 就是通了，api内部已经验证了余额，不需要再验证
        print_success "API 连接测试成功！"
        return 0
    fi
    
    if [ "$response" = "401" ]; then
        print_error "API Key 认证失败，请检查 API Key 是否正确。"
    else
        print_error "API 测试失败，HTTP 状态码：$response"
    fi
    
    return 1
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

        function emit_missing(    i, key) {
            for (i = 1; i <= key_count; i++) {
                key = keys[i]
                if (!updated[key]) {
                    print key " = " values[key]
                    updated[key] = 1
                }
            }
        }

        BEGIN {
            while ((getline line < settings_file) > 0) {
                key = line
                sub(/\t.*$/, "", key)
                value = line
                sub(/^[^\t]*\t/, "", value)
                keys[++key_count] = key
                values[key] = value
                updated[key] = 0
            }
            close(settings_file)

            in_section = (section == "")
            found_section = (section == "")
        }

        {
            line = $0
            if (is_section_header(line)) {
                if (in_section) {
                    emit_missing()
                }

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

            if (in_section) {
                for (i = 1; i <= key_count; i++) {
                    key = keys[i]
                    pattern = "^[[:space:]]*" key "[[:space:]]*="
                    if (line ~ pattern) {
                        match(line, /^[[:space:]]*/)
                        indent = substr(line, RSTART, RLENGTH)
                        print indent key " = " values[key]
                        updated[key] = 1
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

            if (!found_section) {
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

# 创建或合并 Codex 配置的函数
create_codex_config() {
    local base_url="$1"
    local config_dir="$HOME/.codex"
    local config_file="$config_dir/config.toml"

    mkdir -p "$config_dir"

    local root_settings
    local provider_settings
    local experimental_settings
    local feature_settings
    local sandbox_settings
    local source_file
    local target_file

    root_settings=$(mktemp "$config_dir/.root-settings.XXXXXX")
    provider_settings=$(mktemp "$config_dir/.provider-settings.XXXXXX")
    experimental_settings=$(mktemp "$config_dir/.experimental-settings.XXXXXX")
    feature_settings=$(mktemp "$config_dir/.feature-settings.XXXXXX")
    sandbox_settings=$(mktemp "$config_dir/.sandbox-settings.XXXXXX")
    source_file=$(mktemp "$config_dir/.config-source.XXXXXX")
    target_file=$(mktemp "$config_dir/.config-target.XXXXXX")

    if [ -f "$config_file" ]; then
        cp "$config_file" "$source_file"
    fi

    write_toml_settings_file "$root_settings" \
        "model_provider" "$(toml_quote "codex")" \
        "model" "$(toml_quote "gpt-5.6-sol")" \
        "model_reasoning_effort" "$(toml_quote "high")" \
        "disable_response_storage" "true" \
        "sandbox_mode" "$(toml_quote "danger-full-access")"

    write_toml_settings_file "$provider_settings" \
        "name" "$(toml_quote "codex")" \
        "base_url" "$(toml_quote "$base_url")" \
        "wire_api" "$(toml_quote "responses")" \
        "supports_websockets" "false" \
        "env_key" "$(toml_quote "CODEX_API_KEY")" \
        "http_headers" '{ "x-openai-actor-authorization" = "codex-compatible-image-generation" }'

    write_toml_settings_file "$experimental_settings" \
        "use_freeform_apply_patch" "true" \
        "use_unified_exec_tool" "true"

    write_toml_settings_file "$feature_settings" \
        "apply_patch_freeform" "true" \
        "plan_tool" "true" \
        "rmcp_client" "true" \
        "streamable_shell" "false" \
        "unified_exec" "false" \
        "view_image_tool" "true" \
        "image_generation" "true" \
        "experimental_windows_sandbox" "true" \
        "parallel" "true"

    write_toml_settings_file "$sandbox_settings" \
        "network_access" "true"

    merge_toml_section "$source_file" "$target_file" "" "$root_settings"
    mv "$target_file" "$source_file"

    target_file=$(mktemp "$config_dir/.config-target.XXXXXX")
    merge_toml_section "$source_file" "$target_file" "model_providers.codex" "$provider_settings"
    mv "$target_file" "$source_file"

    target_file=$(mktemp "$config_dir/.config-target.XXXXXX")
    merge_toml_section "$source_file" "$target_file" "experimental" "$experimental_settings"
    mv "$target_file" "$source_file"

    target_file=$(mktemp "$config_dir/.config-target.XXXXXX")
    merge_toml_section "$source_file" "$target_file" "features" "$feature_settings"
    mv "$target_file" "$source_file"

    target_file=$(mktemp "$config_dir/.config-target.XXXXXX")
    merge_toml_section "$source_file" "$target_file" "sandbox_workspace_write" "$sandbox_settings"
    mv "$target_file" "$config_file"

    rm -f "$root_settings" "$provider_settings" "$experimental_settings" "$feature_settings" "$sandbox_settings" "$source_file" "$target_file"

    print_success "Codex 配置已合并写入：$config_file"
    return 0
}

# 设置环境变量的函数
set_environment_variable() {
    local base_url="$1"
    local api_key="$2"

    # 为当前会话导出
    export OPENAI_BASE_URL="$base_url"
    export OPENAI_API_KEY="$api_key"
    export CODEX_API_KEY="$api_key"

    # 检测shell并添加到相应的配置文件
    local shell_config=""
    local shell_name=""

    # 首先检查$SHELL以确定用户的默认shell
    if [ -n "$SHELL" ]; then
        shell_name=$(basename "$SHELL")
        case "$shell_name" in
            bash)
                shell_config="$HOME/.bashrc"
                [ -f "$HOME/.bash_profile" ] && shell_config="$HOME/.bash_profile"
                ;;
            zsh)
                shell_config="$HOME/.zshrc"
                ;;
            fish)
                shell_config="$HOME/.config/fish/config.fish"
                ;;
            *)
                shell_config="$HOME/.profile"
                ;;
        esac
    # 如果$SHELL未设置，回退到检查版本变量
    elif [ -n "$BASH_VERSION" ]; then
        shell_config="$HOME/.bashrc"
        [ -f "$HOME/.bash_profile" ] && shell_config="$HOME/.bash_profile"
    elif [ -n "$ZSH_VERSION" ]; then
        shell_config="$HOME/.zshrc"
    elif [ -n "$FISH_VERSION" ]; then
        shell_config="$HOME/.config/fish/config.fish"
    else
        shell_config="$HOME/.profile"
    fi

    print_info "检测到的 Shell：${shell_name:-$(basename $SHELL 2>/dev/null || echo 'unknown')}"
    print_info "使用的配置文件：$shell_config"

    # 以不同方式处理Fish shell（使用'set -x'代替'export'）
    if [ "$shell_name" = "fish" ] || [[ "$shell_config" == *"fish"* ]]; then
        # Fish shell语法
        mkdir -p "$(dirname "$shell_config")"

        # 处理 OPENAI_BASE_URL
        if [ -f "$shell_config" ] && grep -q "set -x OPENAI_BASE_URL" "$shell_config"; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|set -x OPENAI_BASE_URL.*|set -x OPENAI_BASE_URL \"$base_url\"|" "$shell_config"
            else
                sed -i "s|set -x OPENAI_BASE_URL.*|set -x OPENAI_BASE_URL \"$base_url\"|" "$shell_config"
            fi
            print_info "已更新 $shell_config 中的 OPENAI_BASE_URL"
        else
            echo "" >> "$shell_config"
            echo "# Codex 环境变量" >> "$shell_config"
            echo "set -x OPENAI_BASE_URL \"$base_url\"" >> "$shell_config"
            print_info "已将 OPENAI_BASE_URL 写入 $shell_config"
        fi

        # 处理 OPENAI_API_KEY
        if [ -f "$shell_config" ] && grep -q "set -x OPENAI_API_KEY" "$shell_config"; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/set -x OPENAI_API_KEY.*/set -x OPENAI_API_KEY \"$api_key\"/" "$shell_config"
            else
                sed -i "s/set -x OPENAI_API_KEY.*/set -x OPENAI_API_KEY \"$api_key\"/" "$shell_config"
            fi
            print_info "已更新 $shell_config 中的 OPENAI_API_KEY"
        else
            echo "" >> "$shell_config"
            echo "# OpenAI API 密钥" >> "$shell_config"
            echo "set -x OPENAI_API_KEY \"$api_key\"" >> "$shell_config"
            print_info "已将 OPENAI_API_KEY 写入 $shell_config"
        fi

        # 处理 CODEX_API_KEY
        if [ -f "$shell_config" ] && grep -q "set -x CODEX_API_KEY" "$shell_config"; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/set -x CODEX_API_KEY.*/set -x CODEX_API_KEY \"$api_key\"/" "$shell_config"
            else
                sed -i "s/set -x CODEX_API_KEY.*/set -x CODEX_API_KEY \"$api_key\"/" "$shell_config"
            fi
            print_info "已更新 $shell_config 中的 CODEX_API_KEY"
        else
            echo "# Codex API 密钥" >> "$shell_config"
            echo "set -x CODEX_API_KEY \"$api_key\"" >> "$shell_config"
            print_info "已将 CODEX_API_KEY 写入 $shell_config"
        fi
    else
        # Bash/Zsh/sh语法
        # 处理 OPENAI_BASE_URL
        if [ -f "$shell_config" ] && grep -q "export OPENAI_BASE_URL=" "$shell_config"; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|export OPENAI_BASE_URL=.*|export OPENAI_BASE_URL=\"$base_url\"|" "$shell_config"
            else
                sed -i "s|export OPENAI_BASE_URL=.*|export OPENAI_BASE_URL=\"$base_url\"|" "$shell_config"
            fi
            print_info "已更新 $shell_config 中的 OPENAI_BASE_URL"
        else
            echo "" >> "$shell_config"
            echo "# Codex 环境变量" >> "$shell_config"
            echo "export OPENAI_BASE_URL=\"$base_url\"" >> "$shell_config"
            print_info "已将 OPENAI_BASE_URL 写入 $shell_config"
        fi

        # 处理 OPENAI_API_KEY
        if [ -f "$shell_config" ] && grep -q "export OPENAI_API_KEY=" "$shell_config"; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/export OPENAI_API_KEY=.*/export OPENAI_API_KEY=\"$api_key\"/" "$shell_config"
            else
                sed -i "s/export OPENAI_API_KEY=.*/export OPENAI_API_KEY=\"$api_key\"/" "$shell_config"
            fi
            print_info "已更新 $shell_config 中的 OPENAI_API_KEY"
        else
            echo "" >> "$shell_config"
            echo "# OpenAI API 密钥" >> "$shell_config"
            echo "export OPENAI_API_KEY=\"$api_key\"" >> "$shell_config"
            print_info "已将 OPENAI_API_KEY 写入 $shell_config"
        fi

        # 处理 CODEX_API_KEY
        if [ -f "$shell_config" ] && grep -q "export CODEX_API_KEY=" "$shell_config"; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/export CODEX_API_KEY=.*/export CODEX_API_KEY=\"$api_key\"/" "$shell_config"
            else
                sed -i "s/export CODEX_API_KEY=.*/export CODEX_API_KEY=\"$api_key\"/" "$shell_config"
            fi
            print_info "已更新 $shell_config 中的 CODEX_API_KEY"
        else
            echo "# Codex API 密钥" >> "$shell_config"
            echo "export CODEX_API_KEY=\"$api_key\"" >> "$shell_config"
            print_info "已将 CODEX_API_KEY 写入 $shell_config"
        fi
    fi

    print_success "环境变量 OPENAI_BASE_URL、OPENAI_API_KEY 和 CODEX_API_KEY 设置成功"
    return 0
}

# 显示当前设置的函数
show_current_settings() {
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
    print_info "环境变量："

    if [ ! -z "$OPENAI_BASE_URL" ]; then
        print_info "OPENAI_BASE_URL：$OPENAI_BASE_URL"
    else
        print_info "OPENAI_BASE_URL：未设置"
    fi

    if [ ! -z "$OPENAI_API_KEY" ]; then
        local masked_key="${OPENAI_API_KEY:0:8}...${OPENAI_API_KEY: -4}"
        print_info "OPENAI_API_KEY：$masked_key"
    else
        print_info "OPENAI_API_KEY：未设置"
    fi

    if [ ! -z "$CODEX_API_KEY" ]; then
        local masked_key="${CODEX_API_KEY:0:8}...${CODEX_API_KEY: -4}"
        print_info "CODEX_API_KEY：$masked_key"
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
    
    # 如果未提供URL或密钥则进入交互模式
    if [ -z "$BASE_URL" ] && [ -z "$API_KEY" ]; then
        print_info "进入交互配置模式"
        echo ""
        
        # 获取基础URL
        read -p "请输入 API 地址 [$DEFAULT_BASE_URL]: " input_url
        BASE_URL="${input_url:-$DEFAULT_BASE_URL}"
        
        # 获取API密钥
        while [ -z "$API_KEY" ]; do
            read -p "请输入 API Key: " API_KEY
            if [ -z "$API_KEY" ]; then
                print_warning "API Key 不能为空"
            fi
        done
    fi
    
    # 验证输入
    if [ -z "$BASE_URL" ] || [ -z "$API_KEY" ]; then
        print_error "API 地址和 API Key 都不能为空"
        print_info "可使用 --help 查看用法"
        exit 1
    fi

    if ! validate_api_key "$API_KEY"; then
        exit 1
    fi
    
    # 移除URL末尾的斜杠
    BASE_URL="${BASE_URL%/}"
    
    print_info "本次配置："
    print_info "  API 地址：$BASE_URL"
    print_info "  网络方案：$(network_region_label)"
    
    # 隐藏API密钥用于显示
    if [ ${#API_KEY} -gt 12 ]; then
        masked_key="${API_KEY:0:8}...${API_KEY: -4}"
    else
        masked_key="${API_KEY:0:4}..."
    fi
    print_info "  API Key：$masked_key"
    echo ""
    
    # 测试API连接
    if ! test_api_connection "$BASE_URL" "$API_KEY"; then
        if [ "$TEST_ONLY" = true ]; then
            exit 1
        fi
        print_warning "API 测试失败，仍将继续写入配置。"
    fi
    
    # 如果仅测试则退出
    if [ "$TEST_ONLY" = true ]; then
        print_success "API 测试已完成"
        exit 0
    fi
    
    # 备份现有配置
    backup_config
    
    # 创建Codex配置
    if ! create_codex_config "$BASE_URL"; then
        print_error "创建 Codex 配置失败"
        exit 1
    fi
    
    # 设置环境变量
    if ! set_environment_variable "$BASE_URL" "$API_KEY"; then
        print_warning "自动设置环境变量失败"
        print_info "请手动设置："
        print_info "  export OPENAI_BASE_URL=\"$BASE_URL\""
        print_info "  export OPENAI_API_KEY=\"$API_KEY\""
        print_info "  export CODEX_API_KEY=\"$API_KEY\""
    fi

    echo ""
    print_success "配置已保存"
    print_info "配置文件：$HOME/.codex/config.toml"
    echo

    # 检查 Codex 是否已安装，未安装时自动安装
    if ensure_codex; then
        print_success "Codex 已安装，可以开始使用！"
        print_info "可运行 'codex --version' 验证"
    else
        print_warning "Codex 未安装。如需手动安装："
        if [ "$NETWORK_REGION" = "cn" ]; then
            print_info "1. 从 $CN_NODE_DIST_URL 下载 Node.js latest LTS"
            print_info "2. 运行：npm install -g @openai/codex --registry $CN_NPM_REGISTRY"
        else
            print_info "1. 从 https://nodejs.org/ 安装 Node.js latest LTS"
            print_info "2. 运行：npm install -g @openai/codex --no-audit --no-fund --loglevel=error"
        fi
    fi

    echo
    print_info "如需在当前会话立即生效，请运行："

    # 根据检测到的shell提供正确的命令
    local current_shell=$(basename "$SHELL" 2>/dev/null || echo "bash")
    if [ "$current_shell" = "fish" ]; then
        print_info "  set -x OPENAI_BASE_URL \"$BASE_URL\""
        print_info "  set -x OPENAI_API_KEY \"$API_KEY\""
        print_info "  set -x CODEX_API_KEY \"$API_KEY\""
    else
        print_info "  export OPENAI_BASE_URL=\"$BASE_URL\""
        print_info "  export OPENAI_API_KEY=\"$API_KEY\""
        print_info "  export CODEX_API_KEY=\"$API_KEY\""
    fi
    print_info "或者重新打开终端。"

    # 显示当前设置
    echo ""
    show_current_settings
}

# 运行主函数
main
