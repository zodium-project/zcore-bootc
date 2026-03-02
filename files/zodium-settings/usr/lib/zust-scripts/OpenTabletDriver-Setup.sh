#!/usr/bin/env bash
# ================================================================
#  OpenTabletDriver Installer — Install, Upgrade, or Remove OTD
#  Detects current state before acting — never blindly executes
#  Only requires: curl, flatpak, systemd
#  For use on zcore derivatives / any systemd+flatpak distro
# ================================================================

set -Eeuo pipefail

# ── Dependency check ──────────────────────────────────────────
command -v curl      &>/dev/null || { echo "⦻  curl is required but not installed" >&2; exit 1; }
command -v flatpak   &>/dev/null || { echo "⦻  flatpak is required but not installed" >&2; exit 1; }
command -v systemctl &>/dev/null || { echo "⦻  systemd is required" >&2; exit 1; }

# ── Styling ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

say()   { printf "$@"; printf '\n'; }
info()  { say "${CYAN}◈${NC}  $*"; }
ok()    { say "${GREEN}◆${NC}  $*"; }
warn()  { say "${YELLOW}◇${NC}  $*"; }
fail()  { say "${RED}⦻${NC}  $*" >&2; exit 1; }
ask()   { say "${MAGENTA}◉${NC}  $*"; }
skip()  { say "  ${BOLD}↷${NC}  $* ${YELLOW}(skipped — not found)${NC}"; }

# ── Paths ─────────────────────────────────────────────────────
FLATPAK_ID="net.opentabletdriver.OpenTabletDriver"
UDEV_RULES="/etc/udev/rules.d/71-opentabletdriver.rules"
MODPROBE_CONF="/etc/modprobe.d/blacklist-opentabletdriver.conf"
SERVICE_FILE="$HOME/.config/systemd/user/opentabletdriver.service"
SERVICE_URL="https://raw.githubusercontent.com/flathub/net.opentabletdriver.OpenTabletDriver/refs/heads/master/scripts/opentabletdriver.service"

# ── Header ────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║    ◈  OpenTabletDriver Installer  ◈      ║${NC}"
say "${MAGENTA}${BOLD}║    Open-source user-mode tablet driver   ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── State detection ───────────────────────────────────────────
info "Scanning system for existing installation..."

HAS_FLATPAK=false
HAS_UDEV=false
HAS_MODPROBE=false
HAS_SERVICE=false
HAS_SERVICE_ENABLED=false

flatpak info "$FLATPAK_ID" &>/dev/null                           && HAS_FLATPAK=true
[[ -f "$UDEV_RULES" ]]                                           && HAS_UDEV=true
[[ -f "$MODPROBE_CONF" ]]                                        && HAS_MODPROBE=true
[[ -f "$SERVICE_FILE" ]]                                         && HAS_SERVICE=true
systemctl --user is-enabled opentabletdriver.service &>/dev/null && HAS_SERVICE_ENABLED=true

INSTALLED_COUNT=0
$HAS_FLATPAK  && (( INSTALLED_COUNT++ )) || true
$HAS_UDEV     && (( INSTALLED_COUNT++ )) || true
$HAS_MODPROBE && (( INSTALLED_COUNT++ )) || true
$HAS_SERVICE  && (( INSTALLED_COUNT++ )) || true

# ── Report detected state ─────────────────────────────────────
say "  ${BOLD}Detection results:${NC}"
$HAS_FLATPAK  && say "  ${GREEN}◆${NC} Flatpak package    — installed" \
              || say "  ${RED}◇${NC} Flatpak package    — not found"
$HAS_UDEV     && say "  ${GREEN}◆${NC} udev rules         — present" \
              || say "  ${RED}◇${NC} udev rules         — not found"
$HAS_MODPROBE && say "  ${GREEN}◆${NC} Module blacklist   — present" \
              || say "  ${RED}◇${NC} Module blacklist   — not found"
$HAS_SERVICE  && say "  ${GREEN}◆${NC} Systemd service    — present" \
              || say "  ${RED}◇${NC} Systemd service    — not found"
say ""

# ── Determine install state ───────────────────────────────────
if   [[ $INSTALLED_COUNT -eq 0 ]]; then
    STATE="none"
elif [[ $INSTALLED_COUNT -eq 4 ]]; then
    STATE="full"
else
    STATE="partial"
fi

# ── Mode prompt based on state ────────────────────────────────
case "$STATE" in

  none)
    say "  ${CYAN}◈${NC} No existing installation detected."
    say ""
    ask "What would you like to do?"
    say "  ${BOLD}1)${NC} Install"
    say "  ${BOLD}2)${NC} Cancel"
    say ""
    read -rp "  Enter choice [1/2]: " MODE
    case "$MODE" in
      1) ACTION="install" ;;
      *) info "Cancelled."; exit 0 ;;
    esac
    ;;

  full)
    INSTALLED_VER=$(flatpak info "$FLATPAK_ID" 2>/dev/null \
        | grep -i 'version' | awk '{print $NF}' || echo "unknown")
    say "  ${GREEN}◆${NC} Full installation detected — version ${BOLD}${INSTALLED_VER}${NC}"
    say ""
    ask "What would you like to do?"
    say "  ${BOLD}1)${NC} Upgrade to latest"
    say "  ${BOLD}2)${NC} Uninstall"
    say "  ${BOLD}3)${NC} Cancel"
    say ""
    read -rp "  Enter choice [1/2/3]: " MODE
    case "$MODE" in
      1) ACTION="install" ;;
      2) ACTION="uninstall" ;;
      *) info "Cancelled."; exit 0 ;;
    esac
    ;;

  partial)
    say "  ${YELLOW}◇${NC} Partial installation detected (${INSTALLED_COUNT}/4 components found)."
    say "    This may be a broken or incomplete install."
    say ""
    ask "What would you like to do?"
    say "  ${BOLD}1)${NC} Repair / Complete installation"
    say "  ${BOLD}2)${NC} Remove all detected components"
    say "  ${BOLD}3)${NC} Cancel"
    say ""
    read -rp "  Enter choice [1/2/3]: " MODE
    case "$MODE" in
      1) ACTION="install" ;;
      2) ACTION="uninstall" ;;
      *) info "Cancelled."; exit 0 ;;
    esac
    ;;

esac
say ""

# ════════════════════════════════════════════════════════════════
#  INSTALL / UPGRADE
# ════════════════════════════════════════════════════════════════
if [[ "$ACTION" == "install" ]]; then

    # ── Fetch latest release info ─────────────────────────────
    info "Fetching latest OTD release info..."
    API_JSON=$(curl -fsSL "https://api.github.com/repos/OpenTabletDriver/OpenTabletDriver/releases/latest") \
        || fail "Failed to query GitHub API"

    LATEST_VERSION=$(echo "$API_JSON" | grep -Po '"tag_name":\s*"\K[^"]+') \
        || fail "Could not parse latest version"
    info "Latest version: ${BOLD}$LATEST_VERSION${NC}"

    TARBALL_URL=$(echo "$API_JSON" \
        | grep -Po '"browser_download_url":\s*"\K[^"]+opentabletdriver[^"]+\.tar\.gz') \
        || fail "Could not find tarball download URL"

    # ── Fetch tarball for udev rules ──────────────────────────
    info "Downloading release tarball for udev rules..."
    OTD_TMPDIR="$(mktemp -d)"
    trap 'rm -rf "$OTD_TMPDIR"' EXIT

    curl -fsSL "$TARBALL_URL" \
        | tar --strip-components=1 -xzf - -C "$OTD_TMPDIR"

    # ── udev rules ────────────────────────────────────────────
    if [[ -f "$OTD_TMPDIR/etc/udev/rules.d/70-opentabletdriver.rules" ]]; then
        info "Installing udev rules (requires sudo)..."
        sudo cp "$OTD_TMPDIR/etc/udev/rules.d/70-opentabletdriver.rules" "$UDEV_RULES"
        sudo udevadm control --reload-rules && sudo udevadm trigger
        ok "udev rules installed → $UDEV_RULES"
    else
        warn "udev rules not found in tarball — skipping"
    fi

    # ── Kernel module blacklist ───────────────────────────────
    info "Writing kernel module blacklist..."
    printf 'blacklist hid_uclogic\nblacklist wacom\n' | sudo tee "$MODPROBE_CONF" > /dev/null
    ok "Module blacklist written → $MODPROBE_CONF"

    # ── Flatpak install / upgrade ─────────────────────────────
    if $HAS_FLATPAK; then
        info "Upgrading Flatpak package..."
        flatpak --system update -y "$FLATPAK_ID" \
            || fail "Flatpak upgrade failed"
        ok "Flatpak package upgraded"
    else
        info "Installing Flatpak package..."
        flatpak --system install -y flathub "$FLATPAK_ID" \
            || fail "Flatpak install failed — is Flathub added as a remote?"
        ok "Flatpak package installed"
    fi

    # ── Systemd user service ──────────────────────────────────
    info "Installing systemd user service..."
    mkdir -p "$HOME/.config/systemd/user"
    curl -fsSL "$SERVICE_URL" -o "$SERVICE_FILE" \
        || fail "Failed to download service file"
    systemctl --user daemon-reload

    if $HAS_SERVICE_ENABLED; then
        info "Restarting service..."
        systemctl --user restart opentabletdriver.service
        ok "Service restarted"
    else
        systemctl enable --user --now opentabletdriver.service
        ok "Service enabled and started"
    fi

    # ── Summary ───────────────────────────────────────────────
    say ""
    say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
    say "${MAGENTA}${BOLD}║   ◆  Installation Complete               ║${NC}"
    say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
    say "  Version   : ${BOLD}$LATEST_VERSION${NC}"
    say "  Flatpak   : ${BOLD}$FLATPAK_ID${NC}"
    say "  udev      : ${BOLD}$UDEV_RULES${NC}"
    say "  Blacklist : ${BOLD}$MODPROBE_CONF${NC}"
    say "  Service   : ${BOLD}opentabletdriver.service (user)${NC}"
    say ""
    say "  ${YELLOW}◇${NC}  A ${BOLD}reboot${NC} is recommended to apply kernel module changes."
    say ""

# ════════════════════════════════════════════════════════════════
#  UNINSTALL
# ════════════════════════════════════════════════════════════════
elif [[ "$ACTION" == "uninstall" ]]; then

    # ── Service ───────────────────────────────────────────────
    if $HAS_SERVICE_ENABLED; then
        info "Stopping and disabling service..."
        systemctl --user disable --now opentabletdriver.service
        ok "Service stopped and disabled"
    else
        skip "Service was not enabled"
    fi

    if $HAS_SERVICE; then
        info "Removing service file..."
        rm -f "$SERVICE_FILE"
        systemctl --user daemon-reload
        ok "Service file removed"
    else
        skip "Service file — $SERVICE_FILE"
    fi

    # ── Flatpak ───────────────────────────────────────────────
    if $HAS_FLATPAK; then
        info "Removing Flatpak package..."
        flatpak --system remove -y "$FLATPAK_ID"
        ok "Flatpak package removed"
    else
        skip "Flatpak package — $FLATPAK_ID"
    fi

    # ── udev rules ────────────────────────────────────────────
    if $HAS_UDEV; then
        info "Removing udev rules (requires sudo)..."
        sudo rm -f "$UDEV_RULES"
        sudo udevadm control --reload-rules
        ok "udev rules removed"
    else
        skip "udev rules — $UDEV_RULES"
    fi

    # ── Module blacklist ──────────────────────────────────────
    if $HAS_MODPROBE; then
        info "Removing module blacklist (requires sudo)..."
        sudo rm -f "$MODPROBE_CONF"
        ok "Module blacklist removed"
    else
        skip "Module blacklist — $MODPROBE_CONF"
    fi

    # ── Summary ───────────────────────────────────────────────
    say ""
    say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
    say "${MAGENTA}${BOLD}║   ◆  Uninstall Complete                  ║${NC}"
    say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
    say ""
    say "  ${YELLOW}◇${NC}  A ${BOLD}reboot${NC} is recommended to fully unload kernel changes."
    say ""

fi