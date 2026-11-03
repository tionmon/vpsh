#!/usr/bin/env bash
# AI CLI Linux bootstrap - Debian / Ubuntu
# Installs Node.js, npm, Python3, uv, and developer tools.
# Optional: Codex, Claude Code, Gemini CLI, OpenCode 2, Aider, Cline, Command Code.
set -Eeuo pipefail

ALL_TOOLS=(codex claude gemini opencode aider cline commandcode)
declare -A WANT=()
NODE_MAJOR=24
CHINA_MIRRORS=0
FAILED=()
WORK_DIR=

usage() {
  cat <<'HELP'
AI CLI Linux 环境初始化（Debian / Ubuntu）

用法：
  bash ai-cli-bootstrap.sh                 只安装基础开发环境（默认）
  bash ai-cli-bootstrap.sh --all           基础环境 + 7 个 AI CLI
  bash ai-cli-bootstrap.sh --codex --claude
  bash ai-cli-bootstrap.sh --gemini --opencode --aider
  bash ai-cli-bootstrap.sh --cline --commandcode
  bash ai-cli-bootstrap.sh --china --all   npm / uv 包索引使用国内镜像
  bash ai-cli-bootstrap.sh --node 26       选择 Node.js 26 LTS
  bash <(curl -fsSL https://raw.githubusercontent.com/tionmon/vpsh/main/run/ai-cli-bootstrap.sh) --all

参数：
  --all        安装所有 7 个 CLI（包含 Cline、Command Code）
  --codex      安装 Codex CLI
  --claude     安装 Claude Code（官方原生安装器）
  --gemini     安装 Gemini CLI
  --opencode   安装 OpenCode 2
  --aider      安装 Aider（独立 Python 3.12 环境）
  --cline      安装 Cline CLI（npm，运行命令 cline）
  --commandcode, --command-code
               安装 Command Code（npm，Linux 命令 cmd / command-code）
  --china      仅 npm 安装 / uv 包索引使用国内镜像；不改变 apt 源
  --node N     Node.js 主要版本，支持 24（默认）或 26
  -h, --help   查看帮助

提示：请直接用普通用户运行，不要 sudo bash；脚本需要时会调用 sudo。
官方安装脚本和软件包需要联网；运行前可先阅读脚本内容。
HELP
}

log() { printf '\n\033[1;36m[AI-CLI]\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m[提示]\033[0m %s\n' "$*" >&2; }
die() { printf '[错误] %s\n' "$1" >&2; exit "${2:-1}"; }
have() { command -v "$1" >/dev/null 2>&1; }
want() { [[ -n ${WANT[$1]:-} ]]; }
run_root() { if (( EUID == 0 )); then "$@"; else sudo "$@"; fi; }
fetch() { curl --fail --location --silent --show-error --retry 3 --connect-timeout 15 "$1" -o "$2"; }
node_major() { node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0; }

parse_args() {
  while (( $# )); do
    case "$1" in
      --node) (( $# >= 2 )) || die '--node 缺少版本号' 2; NODE_MAJOR=$2; shift ;;
      --all) for t in "${ALL_TOOLS[@]}"; do WANT[$t]=1; done ;;
      --codex|--claude|--gemini|--opencode|--aider|--cline|--commandcode) WANT[${1#--}]=1 ;;
      --command-code) WANT[commandcode]=1 ;;
      --china) CHINA_MIRRORS=1 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "[错误] 未识别参数: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
  done
  [[ $NODE_MAJOR == 24 || $NODE_MAJOR == 26 ]] || die '仅支持 --node 24 或 --node 26' 2
}

preflight() {
  if (( EUID == 0 )) && [[ -n ${SUDO_USER:-} && $SUDO_USER != root ]]; then
    die '请退出 sudo 运行：bash ai-cli-bootstrap.sh ...（脚本会自行提权安装系统依赖）' 2
  fi
  [[ -r /etc/os-release ]] || die '找不到 /etc/os-release，无法识别系统。'
  # shellcheck source=/dev/null
  source /etc/os-release
  [[ " ${ID:-} ${ID_LIKE:-} " =~ [[:space:]](debian|ubuntu)[[:space:]] ]] \
    || die "当前系统 ${PRETTY_NAME:-unknown} 暂不支持。该版本专门针对 Debian / Ubuntu。"
  have apt-get || die '找不到 apt-get。'
  (( EUID == 0 )) || have sudo || die '需要 sudo 权限来安装系统依赖，请安装 sudo 或以 root 账号执行。'
}

install_base() {
  log '1/5 安装系统基础工具（不会执行系统全量升级）'
  run_root apt-get update
  run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates curl wget git gnupg \
    unzip zip xz-utils tar \
    build-essential pkg-config \
    python3 python3-venv python3-pip \
    jq ripgrep tmux
}

install_node() {
  log "2/5 检查 Node.js ${NODE_MAJOR}.x 和 npm"
  local cur=0
  have node && cur=$(node_major)
  [[ $cur =~ ^[0-9]+$ ]] || cur=0
  if (( cur >= NODE_MAJOR )) && have npm; then
    log "已有 Node.js $(node --version) / npm $(npm --version)，不修改现有安装。"
    return 0
  fi
  if (( cur > 0 )); then
    warn "现有 Node.js v${cur} 低于目标 v${NODE_MAJOR}，将升级系统 nodejs 包。"
  fi
  # NodeSource official APT setup script configures signed repository.
  fetch "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" "$WORK_DIR/nodesource-setup.sh"
  run_root env DEBIAN_FRONTEND=noninteractive bash "$WORK_DIR/nodesource-setup.sh"
  run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
  hash -r
  cur=$(node_major)
  if (( cur < NODE_MAJOR )) || ! have npm; then
    die "安装后 PATH 中的 node 仍是 v${cur}（$(command -v node || echo 无)），可能被 nvm / fnm 等版本管理器覆盖，请切换后重试。"
  fi
}

setup_paths() {
  log '3/5 配置用户级 CLI 路径（避免 sudo npm -g）'
  local mark='# >>> ai-cli-bootstrap PATH >>>' rc block
  # Idempotent: .profile often sources .bashrc, so never prepend the same dir twice.
  block=$(cat <<'EOF'
# >>> ai-cli-bootstrap PATH >>>
for _d in "$HOME/.local/bin" "$HOME/.local/npm/bin"; do
  case ":$PATH:" in *":$_d:"*) ;; *) PATH="$_d:$PATH" ;; esac
done
unset _d; export PATH
# <<< ai-cli-bootstrap PATH <<<
EOF
)
  for rc in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ $rc == */.zshrc && ! -f $rc ]]; then continue; fi
    grep -Fqs "$mark" "$rc" || printf '\n%s\n' "$block" >> "$rc"
  done
  mkdir -p "$HOME/.local/bin"
  export PATH="$HOME/.local/npm/bin:$HOME/.local/bin:$PATH"

  # uv and native Claude Code use ~/.local/bin; npm CLIs use ~/.local/npm/bin.
  # Persist the prefix in ~/.npmrc so later `npm i -g` / upgrades also work without sudo.
  # Skip it for nvm / fnm / volta, which already keep globals under $HOME and reject a prefix.
  local node_bin
  node_bin=$(command -v node)
  if [[ $node_bin == "$HOME"/* ]]; then
    log "Node.js 由用户目录下的版本管理器提供（${node_bin}），沿用其 npm 全局目录。"
  else
    mkdir -p "$HOME/.local/npm"
    npm config set prefix "$HOME/.local/npm"
  fi

  if (( CHINA_MIRRORS )); then
    export npm_config_registry='https://registry.npmmirror.com'
    export UV_DEFAULT_INDEX='https://pypi.tuna.tsinghua.edu.cn/simple'
    warn '已对本次 npm / uv 包安装启用国内镜像；NodeSource、uv/Claude 官方安装器仍访问其官方域名。'
  fi
}

install_uv() {
  log '4/5 安装 Python 工具管理器 uv'
  if have uv; then
    log "已有 $(uv --version)，跳过。"
  else
    fetch https://astral.sh/uv/install.sh "$WORK_DIR/uv-install.sh"
    UV_NO_MODIFY_PATH=1 sh "$WORK_DIR/uv-install.sh"
    hash -r
  fi
  have uv || die 'uv 安装成功但 PATH 中找不到。'
}

install_claude() {
  fetch https://claude.ai/install.sh "$WORK_DIR/claude-install.sh"
  bash "$WORK_DIR/claude-install.sh"
}

# install_cli <key> <bin> <title> <command...>: skip if not selected or already on PATH.
# A failed CLI is recorded and reported at the end instead of aborting the others.
install_cli() {
  local key=$1 bin=$2 title=$3
  shift 3
  want "$key" || return 0
  if have "$bin"; then
    log "${title} 已存在 ($(command -v "$bin"))，跳过安装。"
    return 0
  fi
  log "安装 ${title}：$*"
  if ! "$@"; then
    warn "${title} 安装失败，继续安装其余 CLI。"
    FAILED+=("$title")
  fi
  hash -r
}

install_ai_clis() {
  log '5/5 安装选定的 AI CLI（未选择则跳过）'
  if want opencode && ! have opencode2 && have opencode; then
    warn "检测到旧版 opencode（$(command -v opencode)）；若 OpenCode 2 安装报 EEXIST，请先 npm rm -g opencode-ai。"
  fi
  install_cli codex       codex        'Codex CLI'    npm install -g @openai/codex
  install_cli gemini      gemini       'Gemini CLI'   npm install -g @google/gemini-cli
  install_cli opencode    opencode2    'OpenCode 2'   npm install -g @opencode/cli
  install_cli claude      claude       'Claude Code'  install_claude
  install_cli cline       cline        'Cline CLI'    npm install -g cline@latest
  # Command Code exposes command-code and the Linux shortcut cmd. Requires Node.js >= 22.
  install_cli commandcode command-code 'Command Code' npm install -g command-code@latest
  install_cli aider       aider        'Aider'        uv tool install --python 3.12 --with pip aider-chat@latest
}

summary() {
  local c
  printf '\n========== 版本检查 ==========\n'
  for c in node npm python3 uv git tmux rg jq; do
    printf '%-11s' "$c"
    # awk reads all input, so a multi-line --version never hits SIGPIPE under pipefail.
    if ! have "$c"; then echo '未找到'
    elif [[ $c == tmux ]]; then tmux -V
    else "$c" --version 2>&1 | awk 'NR == 1'
    fi
  done
  printf '\nAI CLI 检测：\n'
  for c in codex claude gemini opencode aider cline command-code; do
    if have "$c"; then
      printf '  [OK] %-12s %s\n' "$c" "$(command -v "$c")"
    else
      printf '  [--] %-12s 未安装\n' "$c"
    fi
  done
  if have command-code && have cmd; then
    printf '  [OK] %-12s %s\n' cmd "$(command -v cmd)"
  fi
  if (( ${#FAILED[@]} )); then
    printf '\n[错误] 以下 CLI 安装失败：%s\n' "${FAILED[*]}" >&2
    return 1
  fi
  printf '\n完成！重新登录 SSH，或执行：source ~/.bashrc\n'
  printf '说明：CLI 登录、API Key、网络代理需要在安装后自行配置。\n'
}

main() {
  parse_args "$@"
  preflight
  WORK_DIR=$(mktemp -d)
  trap 'rm -rf "$WORK_DIR"' EXIT
  trap 'printf "\n[错误] 第 %s 行执行失败，退出码 %s。已完成的安装不会自动回滚。\n" "$LINENO" "$?" >&2' ERR

  log "检测到 ${PRETTY_NAME:-Linux}，当前用户 $(id -un)"
  if (( EUID == 0 )); then
    warn '目前使用 root 账号：用户级 AI CLI 将安装在 /root 目录下。'
  fi

  install_base
  install_node
  setup_paths
  install_uv
  install_ai_clis
  summary || exit 1
}

# Everything runs from main, so `curl ... | bash` reads the whole file before executing.
main "$@"
