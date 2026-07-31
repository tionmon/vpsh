#!/usr/bin/env bash
#
# Hermes Agent 一键安装与基础配置脚本
#
# 支持常见 Linux 发行版：Debian/Ubuntu、Fedora/RHEL、Arch、openSUSE、Alpine。
# 所有交互都集中在脚本前段；安装、配置和启动网关阶段不会再询问用户。
#
# 用法：
#   chmod +x install-hermes.sh
#   ./install-hermes.sh
#
# 注意：脚本会把 API key 和 Telegram bot token 写入 ~/.hermes/.env，并设置为
#       仅当前用户可读（权限 600）。
#

set -Eeuo pipefail
umask 077

readonly HERMES_INSTALL_URL="https://hermes-agent.nousresearch.com/install.sh"
readonly HERMES_HOME="${HERMES_HOME:-${HOME}/.hermes}"
export HERMES_HOME

log() {
    printf '[Hermes] %s\n' "$*"
}

warn() {
    printf '[Hermes][WARN] %s\n' "$*" >&2
}

die() {
    printf '[Hermes][ERROR] %s\n' "$*" >&2
    exit 1
}

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

# 如果脚本通过 curl | bash 执行，stdin 可能是脚本内容，因此优先从 /dev/tty 读取。
INPUT_FD=0
if [[ ! -t 0 && -r /dev/tty ]]; then
    exec 3</dev/tty
    INPUT_FD=3
fi

read_value() {
    local prompt="$1"
    if ! IFS= read -r -u "$INPUT_FD" -p "$prompt" REPLY; then
        die "无法读取输入。请在交互式终端中运行此脚本。"
    fi
    REPLY="$(trim "$REPLY")"
}

read_secret() {
    local prompt="$1"
    if ! IFS= read -r -s -u "$INPUT_FD" -p "$prompt" REPLY; then
        printf '\n' >&2
        die "无法读取秘密输入。请在交互式终端中运行此脚本。"
    fi
    printf '\n'
    REPLY="$(trim "$REPLY")"
}

printf '%s\n' \
    'Hermes Agent 一键安装与配置' \
    '请在下面一次性输入配置；之后脚本将自动完成安装、写配置并启动 Telegram 网关。' \
    ''

# -----------------------------------------------------------------------------
# 0. 一次性收集全部用户输入
# -----------------------------------------------------------------------------
while :; do
    read_value '自定义接口 name（仅允许字母、数字、_、-）：'
    PROVIDER_NAME="$REPLY"
    if [[ "$PROVIDER_NAME" =~ ^[A-Za-z0-9_-]+$ ]]; then
        break
    fi
    printf '%s\n' 'name 不合法，请使用例如 openai-proxy、my_api 这样的值。' >&2
done

while :; do
    read_value '自定义接口 url（例如 https://api.example.com/v1）：'
    PROVIDER_URL="$REPLY"
    if [[ "$PROVIDER_URL" =~ ^https?://[^[:space:]]+$ ]]; then
        break
    fi
    printf '%s\n' 'url 必须以 http:// 或 https:// 开头，且不能包含空格。' >&2
done

read_secret '自定义接口 apikey（本地免密接口可直接回车）：'
PROVIDER_API_KEY="$REPLY"

while :; do
    read_value '默认模型：'
    DEFAULT_MODEL="$REPLY"
    if [[ -n "$DEFAULT_MODEL" && "$DEFAULT_MODEL" != *[[:space:]]* ]]; then
        break
    fi
    printf '%s\n' '默认模型不能为空或包含空格。' >&2
done

while :; do
    read_value '模型 reasoning（可直接回车使用 Hermes 默认值；可选 none/minimal/low/medium/high/xhigh/max/ultra）：'
    REASONING_EFFORT="$REPLY"
    if [[ -z "$REASONING_EFFORT" || "$REASONING_EFFORT" =~ ^(none|minimal|low|medium|high|xhigh|max|ultra)$ ]]; then
        break
    fi
    printf '%s\n' 'reasoning 值不合法，请按提示输入，或直接回车。' >&2
done

while :; do
    read_secret 'Telegram bot token：'
    TELEGRAM_BOT_TOKEN="$REPLY"
    if [[ "$TELEGRAM_BOT_TOKEN" =~ ^[0-9]+:[^[:space:]]+$ ]]; then
        break
    fi
    printf '%s\n' 'Telegram token 格式看起来不正确，应类似 123456789:AA...。' >&2
done

while :; do
    read_value 'Telegram chat ID（私聊为正数，群组/超级群组通常为 -100...）：'
    TELEGRAM_CHAT_ID="$REPLY"
    if [[ "$TELEGRAM_CHAT_ID" =~ ^-?[0-9]+$ && "$TELEGRAM_CHAT_ID" != 0 ]]; then
        break
    fi
    printf '%s\n' 'chat ID 必须是非零整数。' >&2
done

if [[ -n "$PROVIDER_API_KEY" ]]; then
    # 仅用于 .env 的变量名，不把用户输入原样作为环境变量名。
    PROVIDER_ENV_SUFFIX="${PROVIDER_NAME^^}"
    PROVIDER_ENV_SUFFIX="${PROVIDER_ENV_SUFFIX//-/_}"
    PROVIDER_KEY_ENV="HERMES_CUSTOM_${PROVIDER_ENV_SUFFIX}_API_KEY"
else
    PROVIDER_KEY_ENV=""
fi

printf '\n%s\n' '输入完成，开始执行无人值守安装。'
printf '  接口：%s\n  模型：%s\n  Telegram chat：%s\n' \
    "$PROVIDER_NAME" "$DEFAULT_MODEL" "$TELEGRAM_CHAT_ID"
if [[ -n "$REASONING_EFFORT" ]]; then
    printf '  reasoning：%s\n' "$REASONING_EFFORT"
else
    printf '  reasoning：Hermes 默认值\n'
fi

if [[ "$INPUT_FD" == 3 ]]; then
    exec 3<&-
    INPUT_FD=0
fi

# sudo 密码如果需要，提前在所有配置输入结束后一次性完成缓存，避免安装过程中再提示。
if (( EUID != 0 )); then
    command -v sudo >/dev/null 2>&1 || die '当前用户不是 root，且系统没有 sudo。请安装 sudo 或以 root 运行。'
    sudo -v || die 'sudo 授权失败，无法安装系统依赖。'
fi

run_root() {
    if (( EUID == 0 )); then
        "$@"
    else
        sudo -n "$@"
    fi
}

# -----------------------------------------------------------------------------
# 1. 刷新系统软件包索引并安装基础工具
# -----------------------------------------------------------------------------
PACKAGE_MANAGER=''
if command -v apt-get >/dev/null 2>&1; then
    PACKAGE_MANAGER='apt'
elif command -v dnf >/dev/null 2>&1; then
    PACKAGE_MANAGER='dnf'
elif command -v yum >/dev/null 2>&1; then
    PACKAGE_MANAGER='yum'
elif command -v pacman >/dev/null 2>&1; then
    PACKAGE_MANAGER='pacman'
elif command -v zypper >/dev/null 2>&1; then
    PACKAGE_MANAGER='zypper'
elif command -v apk >/dev/null 2>&1; then
    PACKAGE_MANAGER='apk'
fi

if [[ -z "$PACKAGE_MANAGER" ]]; then
    warn '未识别包管理器，将只检查已有命令。'
else
    log "刷新 $PACKAGE_MANAGER 软件包索引（不强制升级整个系统）..."
    case "$PACKAGE_MANAGER" in
        apt)
            run_root apt-get update
            run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
                ca-certificates curl git xz-utils nodejs npm
            ;;
        dnf)
            run_root dnf -y makecache --refresh
            run_root dnf install -y ca-certificates curl git xz nodejs npm
            ;;
        yum)
            run_root yum makecache -y
            run_root yum install -y ca-certificates curl git xz nodejs npm
            ;;
        pacman)
            run_root pacman -Sy --noconfirm --needed ca-certificates curl git xz nodejs npm
            ;;
        zypper)
            run_root zypper --non-interactive refresh
            run_root zypper --non-interactive install --no-recommends \
                ca-certificates curl git xz nodejs npm
            ;;
        apk)
            run_root apk update
            run_root apk add --no-cache ca-certificates curl git xz nodejs npm
            ;;
    esac
fi

for required_command in curl git npm xz; do
    command -v "$required_command" >/dev/null 2>&1 || \
        die "缺少必要命令 $required_command，且自动安装未能提供它。"
done
if ! command -v node >/dev/null 2>&1 && ! command -v nodejs >/dev/null 2>&1; then
    die '缺少必要命令 node/nodejs，且自动安装未能提供它。'
fi

log "系统工具检查通过：$(node --version 2>/dev/null || nodejs --version 2>/dev/null || true)"

# -----------------------------------------------------------------------------
# 2. 安装 Hermes
# -----------------------------------------------------------------------------
INSTALLER_TMP="$(mktemp "${TMPDIR:-/tmp}/hermes-install.XXXXXX.sh")"
PREINSTALL_ENV_BACKUP=""

restore_preinstall_env() {
    if [[ -z "$PREINSTALL_ENV_BACKUP" || ! -f "$PREINSTALL_ENV_BACKUP" ]]; then
        return 0
    fi

    # 如果官方安装器自己新建了 .env，不覆盖它，先保留为旁路备份。
    if [[ -f "$HERMES_HOME/.env" ]]; then
        local generated_env_backup
        generated_env_backup="$(mktemp "$HERMES_HOME/.env.generated.XXXXXX")"
        mv -f -- "$HERMES_HOME/.env" "$generated_env_backup"
        chmod 600 "$generated_env_backup"
        warn "官方安装器生成了新的 .env，已保留为：$generated_env_backup"
    fi

    mv -f -- "$PREINSTALL_ENV_BACKUP" "$HERMES_HOME/.env"
    chmod 600 "$HERMES_HOME/.env"
    PREINSTALL_ENV_BACKUP=""
}

cleanup() {
    if [[ -n "${INSTALLER_TMP:-}" && -f "$INSTALLER_TMP" ]]; then
        rm -f -- "$INSTALLER_TMP"
    fi
    restore_preinstall_env
}
trap cleanup EXIT

# 官方安装器的最后阶段会扫描已有 .env；如果里面已经有 Telegram token，
# 它会自行安装 gateway 并再次进入交互式启动流程。暂时移走旧 .env，
# 安装完成后立即恢复，由本脚本统一写入配置和启动 gateway。
mkdir -p "$HERMES_HOME"
if [[ -f "$HERMES_HOME/.env" ]]; then
    PREINSTALL_ENV_BACKUP="$(mktemp "$HERMES_HOME/.env.preinstall.XXXXXX")"
    mv -f -- "$HERMES_HOME/.env" "$PREINSTALL_ENV_BACKUP"
    log '暂时隔离已有 .env，避免官方安装器重复配置 gateway...'
fi

log '下载 Hermes 官方安装器...'
curl -fsSL "$HERMES_INSTALL_URL" -o "$INSTALLER_TMP"
chmod 700 "$INSTALLER_TMP"

# Hermes 官方安装器会在缺少本地 Playwright 包时调用 npx 临时安装它。
# npm 的 yes 配置会让 npx 自动确认安装，避免在浏览器依赖阶段再次停下来询问。
export npm_config_yes=true
export NPM_CONFIG_YES=true

log '安装 Hermes（官方安装器，跳过其交互式 setup）...'
bash "$INSTALLER_TMP" --skip-setup --non-interactive
restore_preinstall_env

export PATH="${HOME}/.local/bin:${HERMES_HOME}/bin:/usr/local/bin:${PATH}"
HERMES_BIN="$(command -v hermes || true)"
if [[ -z "$HERMES_BIN" ]]; then
    for candidate in "${HOME}/.local/bin/hermes" "${HERMES_HOME}/hermes-agent/venv/bin/hermes" \
        /usr/local/bin/hermes; do
        if [[ -x "$candidate" ]]; then
            HERMES_BIN="$candidate"
            break
        fi
    done
fi
[[ -n "$HERMES_BIN" ]] || die 'Hermes 安装完成但找不到 hermes 命令。'

log "Hermes 可用：$HERMES_BIN"

# -----------------------------------------------------------------------------
# 3. 写入自定义 OpenAI-compatible provider 与 Telegram 配置
# -----------------------------------------------------------------------------
mkdir -p "$HERMES_HOME" "$HERMES_HOME/logs"
ENV_FILE="$HERMES_HOME/.env"
CONFIG_FILE="$HERMES_HOME/config.yaml"

timestamp="$(date +%Y%m%d-%H%M%S)"
if [[ -f "$ENV_FILE" ]]; then
    cp -a -- "$ENV_FILE" "${ENV_FILE}.bak.${timestamp}"
fi
if [[ -f "$CONFIG_FILE" ]]; then
    cp -a -- "$CONFIG_FILE" "${CONFIG_FILE}.bak.${timestamp}"
fi

touch "$ENV_FILE"
chmod 600 "$ENV_FILE"

set_env_var() {
    local key="$1"
    local value="$2"
    local tmp_file
    tmp_file="$(mktemp "${ENV_FILE}.tmp.XXXXXX")"
    if [[ -f "$ENV_FILE" ]]; then
        awk -v key="$key" '
            index($0, key "=") != 1 && index($0, "export " key "=") != 1 { print }
        ' "$ENV_FILE" > "$tmp_file"
    fi
    printf '%s=%s\n' "$key" "$value" >> "$tmp_file"
    chmod 600 "$tmp_file"
    mv -f -- "$tmp_file" "$ENV_FILE"
}

unset_env_var() {
    local key="$1"
    local tmp_file
    tmp_file="$(mktemp "${ENV_FILE}.tmp.XXXXXX")"
    awk -v key="$key" '
        index($0, key "=") != 1 && index($0, "export " key "=") != 1 { print }
    ' "$ENV_FILE" > "$tmp_file"
    chmod 600 "$tmp_file"
    mv -f -- "$tmp_file" "$ENV_FILE"
}

config_set() {
    "$HERMES_BIN" config set "$1" "$2" >/dev/null
}

config_unset() {
    "$HERMES_BIN" config unset "$1" >/dev/null 2>&1 || true
}

log '写入自定义 OpenAI-compatible provider...'
PROVIDER_PATH="providers.${PROVIDER_NAME}"
config_set "${PROVIDER_PATH}.name" "$PROVIDER_NAME"
config_set "${PROVIDER_PATH}.api" "$PROVIDER_URL"
config_set "${PROVIDER_PATH}.transport" 'chat_completions'
config_set "${PROVIDER_PATH}.default_model" "$DEFAULT_MODEL"
config_set "${PROVIDER_PATH}.discover_models" 'true'

# 使用 key_env，避免把 API key 直接放进 config.yaml。
config_unset "${PROVIDER_PATH}.api_key"
if [[ -n "$PROVIDER_API_KEY" ]]; then
    config_set "${PROVIDER_PATH}.key_env" "$PROVIDER_KEY_ENV"
    set_env_var "$PROVIDER_KEY_ENV" "$PROVIDER_API_KEY"
else
    config_unset "${PROVIDER_PATH}.key_env"
fi

config_set 'model.provider' "custom:${PROVIDER_NAME}"
config_set 'model.default' "$DEFAULT_MODEL"
if [[ -n "$REASONING_EFFORT" ]]; then
    config_set 'agent.reasoning_effort' "$REASONING_EFFORT"
else
    # 空输入代表删除用户覆盖，让 Hermes 使用默认 reasoning。
    config_unset 'agent.reasoning_effort'
fi

log '写入 Telegram bot 与 home channel...'
set_env_var 'TELEGRAM_BOT_TOKEN' "$TELEGRAM_BOT_TOKEN"
set_env_var 'TELEGRAM_HOME_CHANNEL' "$TELEGRAM_CHAT_ID"

# 私聊 chat ID 通常就是用户 ID；群组/超级群组则使用 chat-scoped allowlist。
if [[ "$TELEGRAM_CHAT_ID" == -* ]]; then
    set_env_var 'TELEGRAM_GROUP_ALLOWED_CHATS' "$TELEGRAM_CHAT_ID"
    unset_env_var 'TELEGRAM_ALLOWED_USERS'
else
    set_env_var 'TELEGRAM_ALLOWED_USERS' "$TELEGRAM_CHAT_ID"
    unset_env_var 'TELEGRAM_GROUP_ALLOWED_CHATS'
fi

chmod 600 "$ENV_FILE"

log '检查 Hermes 配置...'
if ! "$HERMES_BIN" config check; then
    warn 'Hermes config check 返回非零状态，请查看上方提示；脚本仍会继续启动网关。'
fi

# -----------------------------------------------------------------------------
# 4. 安装并启动 Telegram gateway
# -----------------------------------------------------------------------------
start_gateway_fallback() {
    local pid_file="$HERMES_HOME/gateway.pid"
    local gateway_log="$HERMES_HOME/logs/gateway.log"

    if [[ -f "$pid_file" ]]; then
        local old_pid
        old_pid="$(cat "$pid_file" 2>/dev/null || true)"
        if [[ "$old_pid" =~ ^[0-9]+$ ]] && kill -0 "$old_pid" 2>/dev/null; then
            log "Telegram gateway 已在运行（PID $old_pid）。"
            return 0
        fi
    fi

    log 'systemd user service 不可用，改用后台进程启动 gateway...'
    nohup "$HERMES_BIN" gateway >> "$gateway_log" 2>&1 < /dev/null &
    local gateway_pid=$!
    printf '%s\n' "$gateway_pid" > "$pid_file"
    chmod 600 "$pid_file"
    sleep 2
    if kill -0 "$gateway_pid" 2>/dev/null; then
        log "Telegram gateway 已在后台启动（PID $gateway_pid）。日志：$gateway_log"
    else
        warn "Telegram gateway 可能启动失败，请查看日志：$gateway_log"
    fi
}

if command -v systemctl >/dev/null 2>&1 && \
    systemctl --user show-environment >/dev/null 2>&1; then
    # 显式传参，避免 Hermes 在交互式终端中询问是否立即启动/开机启动。
    # 脚本随后用 gateway start 启动服务。
    if "$HERMES_BIN" gateway install --no-start-now --start-on-login; then
        if "$HERMES_BIN" gateway start; then
            # 让 user service 在退出登录后仍能运行；失败不影响当前启动。
            if command -v loginctl >/dev/null 2>&1 && [[ "$(id -un)" != 'root' ]]; then
                if run_root loginctl enable-linger "$(id -un)"; then
                    log '已启用 user service linger，重启/退出登录后 gateway 仍会自动运行。'
                else
                    warn '无法启用 systemd linger；当前 gateway 仍已启动。'
                fi
            fi
            log 'Telegram gateway 已安装并启动。'
        else
            warn 'gateway service 已安装，但启动失败；请查看 systemd 日志。'
        fi
    else
        warn 'Hermes user service 安装失败。'
        start_gateway_fallback
    fi
else
    start_gateway_fallback
fi

printf '\n%s\n' 'Hermes 安装与配置完成。'
printf '配置文件：%s\n密钥文件：%s\n' "$CONFIG_FILE" "$ENV_FILE"
printf '模型：custom:%s:%s\nTelegram home channel：%s\n' \
    "$PROVIDER_NAME" "$DEFAULT_MODEL" "$TELEGRAM_CHAT_ID"
printf '%s\n' '如 Telegram 未响应，可查看：hermes gateway status 或 ~/.hermes/logs/gateway.log'
