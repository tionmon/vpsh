#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  cfddns — Uninstaller
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -euo pipefail

INSTALL_DIR="/opt/cfddns"
SERVICE_NAME="cfddns"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}[ERROR]${NC} Please run as root"; exit 1; }

echo -e "${YELLOW}This will completely remove cfddns from this system.${NC}"
read -rp "Continue? [y/N] " confirm
[[ "${confirm,,}" != "y" ]] && { echo "Aborted."; exit 0; }

echo -e "${GREEN}[1/3]${NC} Stopping service…"
systemctl stop "${SERVICE_NAME}" 2>/dev/null || true
systemctl disable "${SERVICE_NAME}" 2>/dev/null || true
rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
systemctl daemon-reload

echo -e "${GREEN}[2/3]${NC} Removing files…"
rm -rf "${INSTALL_DIR}"

echo -e "${GREEN}[3/3]${NC} Done!"
echo -e "${GREEN}cfddns has been completely removed.${NC}"
