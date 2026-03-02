#!/usr/bin/env bash
# ================================================================
#  OpenTabletDriver Installer — Install or remove OTD safely
#  Detects latest release, installs via Flatpak + udev rules
#  Only requires: curl, bash
#  For use on zcore derivatives / any systemd+flatpak distro
# ================================================================

set -Eeuo pipefail

# ── Dependency check ─────────────────────────────────────────
command -v curl     &>/dev/null || { echo "[✖]  curl is required but not installed" >&2; exit 1; }
command -v flatpak  &>/dev/null || { echo "[✖]  flatpak is required but not installed" >&2; exit 1; }
command -v systemctl &>/dev/null || { echo "[✖]  systemd is required" >&2; exit 1; }

# ── Styling ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${CYAN}[i]${NC}  $*"; }
ok()    { echo -e "${GREEN}[✔]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[⚠]${NC}  $*"; }
fail()  { echo -e "${RED}[✖]${NC}  $*" >&2; exit 1; }
ask()   { echo -e "${MAGENTA}[?]${NC}  $*"; }

FLATPAK_ID="net.opentabletdriver.OpenTabletDriver"
UDEV_RULES="/etc/udev/rules.d/71-opentabletdriver.rules"
MODPROBE_CONF="/etc/modprobe.d/blacklist-opentabletdriver.conf"
SERVICE_FILE="$HOME/.config/systemd/user/opentabletdriver.service"
SERVICE_URL="https://raw.githubusercontent.com/flathub/net.opentabletdriver.OpenTabletDriver/refs/heads/master/scripts/opentabletdriver.service"

# ── Header ────────────────────────────────────────────────────
echo ""
echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}${BOLD}║      OpenTabletDriver Installer          ║${NC}"
echo -e "${MAGENTA}${BOLD}║      Open-source user-mode tablet driver ║${NC}"
echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── Mode selection ────────────────────────────────────────────
ask "What would you like to do?"
echo -e "  ${BOLD}1)${NC} Install / Upgrade"
echo -e "  ${BOLD}2)${NC} Uninstall"
echo -e "  ${BOLD}3)${NC} Cancel"
echo ""
read -rp "  Enter choice [1/2/3]: " MODE
echo ""

case "$MODE" in
  1) ACTION="install" ;;
  2) ACTION="uninstall" ;;
  *) info "Cancelled."; exit 0 ;;
esac

# ════════════════════════════════════════════════════════════════
#  INSTALL
# ════════════════════════════════════════════════════════════════
if [[ "$ACTION" == "install" ]]; then

    # ── Fetch latest release info ─────────────────────────────
    info "Fetching latest OTD release info..."
    API_JSON=$(curl -fsSL "https://api.github.com/repos/OpenTabletDriver/OpenTabletDriver/releases/latest") \
        || fail "Failed to query GitHub API"

    # Parse without jq — extract tag_name
    LATEST_VERSION=$(echo "$API_JSON" | grep -Po '"tag_name":\s*"\K[^"]+') \
        || fail "Could not parse latest version"

    # ── udev rules ────────────────────────────────────────────
    info "Installing udev rules (requires sudo)..."
    OTD_TMPDIR="$(mktemp -d)"
    trap 'rm -rf "$OTD_TMPDIR"' EXIT

    TARBALL_URL=$(echo "$API_JSON" \
        | grep -Po '"browser_download_url":\s*"\K[^"]+opentabletdriver[^"]+\.tar\.gz') \
        || fail "Could not find tarball download URL"

    curl -fsSL "$TARBALL_URL" \
        | tar --strip-components=1 -xzf - -C "$OTD_TMPDIR"

    if [[ -f "$OTD_TMPDIR/etc/udev/rules.d/70-opentabletdriver.rules" ]]; then
        sudo cp "$OTD_TMPDIR/etc/udev/rules.d/70-opentabletdriver.rules" "$UDEV_RULES"
        sudo udevadm control --reload-rules && sudo udevadm trigger
        ok "udev rules installed"
    else
        warn "udev rules not found in tarball — skipping"
    fi

    # ── Kernel module blacklist ───────────────────────────────
    info "Blacklisting conflicting kernel modules..."
    printf 'blacklist hid_uclogic\nblacklist wacom\n' | sudo tee "$MODPROBE_CONF" > /dev/null
    ok "Module blacklist applied"

    # ── Flatpak install ───────────────────────────────────────
    info "Installing via Flatpak (system-wide)..."
    flatpak --system install -y flathub "$FLATPAK_ID" \
        || fail "Flatpak install failed — is Flathub added as a remote?"
    ok "Flatpak package installed"

    # ── Systemd user service ──────────────────────────────────
    info "Setting up systemd user service..."
    mkdir -p "$HOME/.config/systemd/user"
    curl -fsSL "$SERVICE_URL" -o "$SERVICE_FILE" \
        || fail "Failed to download service file"
    systemctl --user daemon-reload
    systemctl enable --user --now opentabletdriver.service
    ok "Service enabled and started"

    # ── Summary ───────────────────────────────────────────────
    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║        Installation Complete ✔           ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
    echo -e "  Version installed : ${BOLD}$LATEST_VERSION${NC}"
    echo -e "  Flatpak ID        : ${BOLD}$FLATPAK_ID${NC}"
    echo -e "  udev rules        : ${BOLD}$UDEV_RULES${NC}"
    echo -e "  Module blacklist  : ${BOLD}$MODPROBE_CONF${NC}"
    echo -e "  Service           : ${BOLD}opentabletdriver.service (user)${NC}"
    echo ""
    echo -e "${YELLOW}[⚠]${NC}  A ${BOLD}reboot${NC} is recommended to apply udev & module changes."
    echo ""

# ════════════════════════════════════════════════════════════════
#  UNINSTALL
# ════════════════════════════════════════════════════════════════
elif [[ "$ACTION" == "uninstall" ]]; then

    info "Stopping and disabling service..."
    systemctl --user disable --now opentabletdriver.service 2>/dev/null && ok "Service stopped" \
        || warn "Service was not running or not found"

    info "Removing service file..."
    rm -f "$SERVICE_FILE"
    systemctl --user daemon-reload
    ok "Service file removed"

    info "Removing Flatpak package..."
    flatpak --system remove -y "$FLATPAK_ID" 2>/dev/null && ok "Flatpak package removed" \
        || warn "Flatpak package was not installed"

    info "Removing udev rules and module blacklist (requires sudo)..."
    sudo rm -f "$UDEV_RULES" "$MODPROBE_CONF"
    sudo udevadm control --reload-rules 2>/dev/null || true
    ok "System rules removed"

    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║        Uninstall Complete ✔              ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}[⚠]${NC}  A ${BOLD}reboot${NC} is recommended to fully unload kernel changes."
    echo ""
fi