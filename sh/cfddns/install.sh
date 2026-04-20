#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  cfddns — One-click installer for Debian 12
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -euo pipefail

INSTALL_DIR="/opt/cfddns"
SERVICE_NAME="cfddns"
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Pre-checks ────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Please run as root: sudo bash install.sh"

info "Installing system dependencies…"
apt-get update -qq
apt-get install -y -qq python3 python3-venv python3-pip > /dev/null 2>&1
ok "System dependencies installed"

# ── Deploy files ──────────────────────────────────────
info "Setting up ${INSTALL_DIR}…"
mkdir -p "${INSTALL_DIR}/logs"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cp "${SCRIPT_DIR}/cfddns.py"       "${INSTALL_DIR}/"
cp "${SCRIPT_DIR}/requirements.txt" "${INSTALL_DIR}/"

# Only copy config if it doesn't exist (preserve user config on re-install)
if [[ ! -f "${INSTALL_DIR}/config.yaml" ]]; then
    cp "${SCRIPT_DIR}/config.yaml" "${INSTALL_DIR}/"
    warn "config.yaml copied — you MUST edit it before starting!"
else
    ok "Existing config.yaml preserved"
fi

ok "Files deployed to ${INSTALL_DIR}"

# ── Python venv ───────────────────────────────────────
info "Creating Python virtual environment…"
python3 -m venv "${INSTALL_DIR}/venv"
"${INSTALL_DIR}/venv/bin/pip" install --quiet --upgrade pip
"${INSTALL_DIR}/venv/bin/pip" install --quiet -r "${INSTALL_DIR}/requirements.txt"
ok "Python environment ready"

# ── Systemd service ──────────────────────────────────
info "Installing systemd service…"
cp "${SCRIPT_DIR}/cfddns.service" "/etc/systemd/system/${SERVICE_NAME}.service"
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"
ok "Service installed and enabled"

# ── Done ─────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Installation complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  1. Edit config:     nano ${INSTALL_DIR}/config.yaml"
echo "  2. Test connection:  cd ${INSTALL_DIR} && venv/bin/python3 cfddns.py test"
echo "  3. Start service:    systemctl start ${SERVICE_NAME}"
echo "  4. View logs:        journalctl -u ${SERVICE_NAME} -f"
echo "                       or: tail -f ${INSTALL_DIR}/logs/cfddns.log"
echo ""
echo "  Other commands:"
echo "    cfddns status   → Show configured schedules"
echo "    cfddns now      → Apply current time-appropriate record immediately"
echo "    cfddns set <domain> <ip> → Manual override"
echo ""
