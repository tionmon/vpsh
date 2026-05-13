#!/usr/bin/env bash

set -euo pipefail

PROJECT_NAME="metatube"
PROJECT_REPO="metatube-community/metatube-server-releases"
DEFAULT_DIRECT_BASE="/home/systemd"
DEFAULT_DOCKER_BASE="/home/docker"
DEFAULT_PORT="8080"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Please run as root, or use: sudo bash $0"
  exit 1
fi

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[36m%s\033[0m\n' "$*"; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    red "Missing required command: $1"
    exit 1
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

validate_app_name() {
  local value="$1"
  [[ "$value" =~ ^[A-Za-z0-9._-]+$ ]]
}

validate_port() {
  local value="$1"
  [[ "$value" =~ ^[0-9]+$ ]] && (( value >= 1 && value <= 65535 ))
}

prompt_default() {
  local prompt="$1"
  local default_value="$2"
  local value
  read -r -p "$prompt [$default_value]: " value
  if [[ -z "$value" ]]; then
    printf '%s\n' "$default_value"
  else
    printf '%s\n' "$value"
  fi
}

prompt_secret_optional() {
  local value
  read -r -s -p "Input TOKEN (press Enter to leave empty): " value
  printf '\n' >&2
  printf '%s\n' "$value"
}

ensure_basic_tools() {
  local tools=(curl tar grep sed uname systemctl)
  local missing=()
  local tool

  for tool in "${tools[@]}"; do
    if ! command_exists "$tool"; then
      missing+=("$tool")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    return
  fi

  yellow "Missing base packages: ${missing[*]}"
  install_os_packages "${missing[@]}"
}

detect_os_family() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "${ID_LIKE:-$ID}" in
      *debian*|*ubuntu*)
        echo "debian"
        return
        ;;
      *rhel*|*fedora*|*centos*|*rocky*|*almalinux*)
        echo "rhel"
        return
        ;;
      *suse*)
        echo "suse"
        return
        ;;
      *arch*)
        echo "arch"
        return
        ;;
    esac
  fi

  red "Unable to identify the OS package family automatically."
  exit 1
}

install_os_packages() {
  local os_family
  os_family="$(detect_os_family)"

  case "$os_family" in
    debian)
      apt-get update
      apt-get install -y "$@"
      ;;
    rhel)
      if command_exists dnf; then
        dnf install -y "$@"
      else
        yum install -y "$@"
      fi
      ;;
    suse)
      zypper install -y "$@"
      ;;
    arch)
      pacman -Sy --noconfirm "$@"
      ;;
  esac
}

cpu_supports_x86_64_v3() {
  local flags
  flags="$(grep -m1 -i '^flags' /proc/cpuinfo 2>/dev/null || true)"
  [[ "$flags" == *" avx "* ]] \
    && [[ "$flags" == *" avx2 "* ]] \
    && [[ "$flags" == *" bmi1 "* ]] \
    && [[ "$flags" == *" bmi2 "* ]] \
    && [[ "$flags" == *" f16c "* ]] \
    && [[ "$flags" == *" fma "* ]] \
    && [[ "$flags" == *" movbe "* ]]
}

detect_release_asset() {
  local arch api_json asset
  arch="$(uname -m)"
  api_json="$(curl -fsSL "https://api.github.com/repos/${PROJECT_REPO}/releases/latest")"

  case "$arch" in
    x86_64|amd64)
      if cpu_supports_x86_64_v3; then
        asset="$(printf '%s' "$api_json" | grep -oE 'browser_download_url": "[^"]*metatube-server-linux-amd64-v3[^"]*\.tar\.gz' | head -n1 | sed 's/^browser_download_url": "//')"
      fi
      if [[ -z "${asset:-}" ]]; then
        asset="$(printf '%s' "$api_json" | grep -oE 'browser_download_url": "[^"]*metatube-server-linux-amd64[^"]*\.tar\.gz' | grep -v 'amd64-v3' | head -n1 | sed 's/^browser_download_url": "//')"
      fi
      ;;
    aarch64|arm64)
      asset="$(printf '%s' "$api_json" | grep -oE 'browser_download_url": "[^"]*metatube-server-linux-arm64[^"]*\.tar\.gz' | head -n1 | sed 's/^browser_download_url": "//')"
      ;;
    armv7l|armv7)
      asset="$(printf '%s' "$api_json" | grep -oE 'browser_download_url": "[^"]*metatube-server-linux-armv7[^"]*\.tar\.gz' | head -n1 | sed 's/^browser_download_url": "//')"
      ;;
    *)
      red "Unsupported architecture: $arch"
      exit 1
      ;;
  esac

  if [[ -z "${asset:-}" ]]; then
    red "No matching release asset was found for this architecture."
    exit 1
  fi

  printf '%s\n' "$asset"
}

download_latest_binary() {
  local install_dir tmp_dir asset_url archive_path
  install_dir="$1"

  asset_url="$(detect_release_asset)"
  tmp_dir="$(mktemp -d)"
  archive_path="${tmp_dir}/metatube.tar.gz"

  blue "Downloading the latest MetaTube server release..."
  curl -fL "$asset_url" -o "$archive_path"
  tar -xzf "$archive_path" -C "$tmp_dir"

  if [[ ! -f "${tmp_dir}/metatube-server" ]]; then
    red "The downloaded archive does not contain metatube-server."
    exit 1
  fi

  install -m 0755 "${tmp_dir}/metatube-server" "${install_dir}/metatube-server"
  rm -rf "$tmp_dir"
}

write_direct_service() {
  local app_name install_dir port token service_file
  app_name="$1"
  install_dir="$2"
  port="$3"
  token="$4"
  service_file="/etc/systemd/system/${app_name}.service"

  install -d -m 0755 "${install_dir}/data"

  cat > "$service_file" <<EOF
[Unit]
Description=MetaTube Server (${app_name})
After=network.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${install_dir}
Environment=PORT=${port}
Environment=DSN=${install_dir}/data/metatube.db
Environment=DB_AUTO_MIGRATE=true
Environment=DB_PREPARED_STMT=true
Environment=REQUEST_TIMEOUT=5m
EOF

  if [[ -n "$token" ]]; then
    printf 'Environment=TOKEN=%s\n' "$token" >> "$service_file"
  fi

  cat >> "$service_file" <<EOF
ExecStart=${install_dir}/metatube-server
Restart=always
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now "${app_name}.service"
}

install_docker() {
  if command_exists docker; then
    green "Docker already exists, skipping installation."
  else
    blue "Installing Docker..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm -f /tmp/get-docker.sh
  fi

  systemctl enable docker
  systemctl restart docker

  if docker compose version >/dev/null 2>&1; then
    green "Docker Compose plugin is ready."
    return
  fi

  red "Docker is installed but the docker compose plugin is unavailable."
  exit 1
}

write_docker_compose() {
  local app_name install_dir port token
  app_name="$1"
  install_dir="$2"
  port="$3"
  token="$4"

  install -d -m 0755 "${install_dir}/postgres"

  cat > "${install_dir}/compose.yaml" <<EOF
services:
  postgres:
    image: postgres:17-alpine
    container_name: ${app_name}-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: metatube
      POSTGRES_USER: metatube
      POSTGRES_PASSWORD: metatube
      TZ: Asia/Shanghai
      PGTZ: Asia/Shanghai
    volumes:
      - ./postgres:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U metatube -d metatube"]
      interval: 10s
      timeout: 5s
      retries: 10

  metatube:
    image: ghcr.io/metatube-community/metatube-server:latest
    container_name: ${app_name}-server
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      PORT: ${port}
      DSN: postgres://metatube:metatube@postgres:5432/metatube?sslmode=disable
      DB_AUTO_MIGRATE: "true"
      DB_PREPARED_STMT: "true"
      REQUEST_TIMEOUT: 5m
EOF

  if [[ -n "$token" ]]; then
    printf '      TOKEN: "%s"\n' "$token" >> "${install_dir}/compose.yaml"
  fi

  cat >> "${install_dir}/compose.yaml" <<EOF
    ports:
      - "${port}:${port}"
EOF
}

start_docker_stack() {
  local install_dir
  install_dir="$1"
  (cd "$install_dir" && docker compose up -d)
}

choose_mode() {
  local mode
  while true; do
    echo "Choose deployment mode:" >&2
    echo "1. Direct deploy (systemd + SQLite, lighter setup)" >&2
    echo "2. Docker deploy (docker compose + PostgreSQL, closer to the high-performance official setup)" >&2
    read -r -p "Input option [1/2]: " mode
    case "$mode" in
      1) echo "direct"; return ;;
      2) echo "docker"; return ;;
      *) yellow "Please input 1 or 2." >&2 ;;
    esac
  done
}

summarize() {
  local mode app_name install_dir port token
  mode="$1"
  app_name="$2"
  install_dir="$3"
  port="$4"
  token="$5"

  echo
  green "Installation finished."
  echo "App name: ${app_name}"
  echo "Mode: ${mode}"
  echo "Install dir: ${install_dir}"
  echo "Port: ${port}"
  if [[ -n "$token" ]]; then
    echo "TOKEN: configured"
  else
    echo "TOKEN: empty"
  fi

  if [[ "$mode" == "direct" ]]; then
    echo "Status: systemctl status ${app_name}"
    echo "Logs: journalctl -u ${app_name} -f"
  else
    echo "Status: docker compose -f ${install_dir}/compose.yaml ps"
    echo "Logs: docker compose -f ${install_dir}/compose.yaml logs -f"
  fi
}

main() {
  local mode app_name port token install_dir default_dir

  ensure_basic_tools
  app_name="$(prompt_default "Input instance name" "${PROJECT_NAME}")"
  if ! validate_app_name "$app_name"; then
    red "Invalid instance name. Use only letters, numbers, dot, dash, or underscore."
    exit 1
  fi

  port="$(prompt_default "Input service port" "${DEFAULT_PORT}")"
  if ! validate_port "$port"; then
    red "Invalid port. Please use a number between 1 and 65535."
    exit 1
  fi

  token="$(prompt_secret_optional)"
  mode="$(choose_mode)"

  if [[ "$mode" == "direct" ]]; then
    default_dir="${DEFAULT_DIRECT_BASE}/${app_name}"
  else
    default_dir="${DEFAULT_DOCKER_BASE}/${app_name}"
  fi

  install_dir="$(prompt_default "Input install directory" "${default_dir}")"
  install -d -m 0755 "$install_dir"

  if [[ "$mode" == "direct" ]]; then
    download_latest_binary "$install_dir"
    write_direct_service "$app_name" "$install_dir" "$port" "$token"
    summarize "Direct" "$app_name" "$install_dir" "$port" "$token"
  else
    install_docker
    write_docker_compose "$app_name" "$install_dir" "$port" "$token"
    start_docker_stack "$install_dir"
    summarize "Docker Compose" "$app_name" "$install_dir" "$port" "$token"
  fi
}

main "$@"
