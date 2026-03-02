#!/usr/bin/env bash
# ================================================================
#  Network Backend Toggle — Switch NM between iwd and wpa_supplicant
#  Only requires: bash, NetworkManager (nmcli), systemd
# ================================================================

set -Eeuo pipefail

command -v nmcli      &>/dev/null || { echo "⦻  nmcli is required" >&2; exit 1; }
command -v systemctl  &>/dev/null || { echo "⦻  systemd is required" >&2; exit 1; }

# ── Styling ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

say()  { printf "$@"; printf '\n'; }
info() { say "${CYAN}◈${NC}  $*"; }
ok()   { say "${GREEN}◆${NC}  $*"; }
warn() { say "${YELLOW}◇${NC}  $*"; }
fail() { say "${RED}⦻${NC}  $*" >&2; exit 1; }
skip() { say "  ${BOLD}↷${NC}  $* ${YELLOW}(skipped — not found)${NC}"; }

# ── Paths ─────────────────────────────────────────────────────
NM_CONF_DIR="/etc/NetworkManager/conf.d"
IWD_CONF="$NM_CONF_DIR/iwd.conf"

# ── Header ────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◈  Network Backend Toggle  ◈           ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── State detection ───────────────────────────────────────────
IWD_CONF_ACTIVE=false
IWD_PKG=false
WPA_SERVICE_ENABLED=false

[[ -f "$IWD_CONF" ]] && grep -q 'wifi.backend=iwd' "$IWD_CONF" 2>/dev/null && IWD_CONF_ACTIVE=true
command -v iwctl &>/dev/null && IWD_PKG=true
systemctl is-enabled --quiet wpa_supplicant.service 2>/dev/null && WPA_SERVICE_ENABLED=true || true

if $IWD_CONF_ACTIVE; then
    CURRENT="iwd"
else
    CURRENT="wpa_supplicant"
fi

say "  Current backend: ${BOLD}${MAGENTA}$CURRENT${NC}"
say ""
say "  ${YELLOW}◇${NC}  Switching will remove all saved Wi-Fi connections."
say ""

# ── Prompt ────────────────────────────────────────────────────
if [[ "$CURRENT" == "iwd" ]]; then
    say "  ${BOLD}1)${NC} Switch to wpa_supplicant"
    say "  ${BOLD}2)${NC} Cancel"
    say ""
    read -rp "  Enter choice [1/2]: " MODE
    [[ "$MODE" == "1" ]] && ACTION="use_wpa" || { info "Cancelled."; exit 0; }
else
    if ! $IWD_PKG; then
        warn "iwd is not installed — install it first before switching."
        say ""
        exit 1
    fi
    say "  ${BOLD}1)${NC} Switch to iwd"
    say "  ${BOLD}2)${NC} Cancel"
    say ""
    read -rp "  Enter choice [1/2]: " MODE
    [[ "$MODE" == "1" ]] && ACTION="use_iwd" || { info "Cancelled."; exit 0; }
fi
say ""

# ── Remove saved Wi-Fi connections ────────────────────────────
remove_wifi_connections() {
    info "Removing saved Wi-Fi connections..."
    local count=0
    while IFS= read -r conn; do
        [[ -z "$conn" ]] && continue
        sudo nmcli connection delete "$conn" &>/dev/null && (( count++ )) || true
    done < <(nmcli -t -f NAME,TYPE connection show | grep ':802-11-wireless' | cut -d: -f1)
    (( count > 0 )) && ok "Removed $count saved Wi-Fi connection(s)" \
                    || skip "No saved Wi-Fi connections found"
}

# ════════════════════════════════════════════════════════════════
#  SWITCH TO IWD
#  Per Arch wiki: NM manages iwd.service itself — do NOT enable it.
#  We only write the backend conf and disable wpa_supplicant.service.
# ════════════════════════════════════════════════════════════════
if [[ "$ACTION" == "use_iwd" ]]; then

    info "Writing NM iwd backend config..."
    sudo mkdir -p "$NM_CONF_DIR"
    printf '[device]\nwifi.backend=iwd\n' | sudo tee "$IWD_CONF" > /dev/null
    ok "Config written → $IWD_CONF"

    info "Disabling wpa_supplicant.service..."
    if $WPA_SERVICE_ENABLED; then
        sudo systemctl disable --now wpa_supplicant.service
        ok "wpa_supplicant.service disabled"
    else
        skip "wpa_supplicant.service was not enabled"
    fi

    remove_wifi_connections

    say ""
    say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
    say "${MAGENTA}${BOLD}║   ◆  Switched to iwd                     ║${NC}"
    say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
    say "  Config : ${BOLD}$IWD_CONF${NC}"
    say "  Note   : NM will manage iwd.service automatically"
    say ""
    say "  ${YELLOW}◇${NC}  ${BOLD}Reboot required${NC} to apply the backend change."
    say ""

# ════════════════════════════════════════════════════════════════
#  SWITCH TO WPA_SUPPLICANT
#  Remove iwd.conf so NM falls back to its default (wpa_supplicant).
#  Re-enable wpa_supplicant.service.
# ════════════════════════════════════════════════════════════════
elif [[ "$ACTION" == "use_wpa" ]]; then

    if $IWD_CONF_ACTIVE; then
        info "Removing iwd backend config..."
        sudo rm -f "$IWD_CONF"
        [[ -d "$NM_CONF_DIR" && -z "$(ls -A "$NM_CONF_DIR")" ]] && sudo rmdir "$NM_CONF_DIR"
        ok "iwd.conf removed"
    else
        skip "iwd.conf not present"
    fi

    info "Re-enabling wpa_supplicant.service..."
    if command -v wpa_supplicant &>/dev/null; then
        sudo systemctl enable --now wpa_supplicant.service
        ok "wpa_supplicant.service enabled"
    else
        skip "wpa_supplicant not installed"
    fi

    remove_wifi_connections

    say ""
    say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
    say "${MAGENTA}${BOLD}║   ◆  Switched to wpa_supplicant          ║${NC}"
    say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
    say "  iwd.conf removed — NM will use wpa_supplicant"
    say ""
    say "  ${YELLOW}◇${NC}  ${BOLD}Reboot required${NC} to apply the backend change."
    say ""

fi