#!/usr/bin/env bash
# =============================================================================
# TPM2 Auto-Unlock Setup for LUKS2 Root (Interactive, no gum)
# Supports Silverblue, Fedora Atomic, Classic Fedora
# =============================================================================

set -euo pipefail

# ── Colors ─────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERR]${NC}   $*" >&2; exit 1; }

# ── Root check ─────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}This script must be run as root.${NC}"
    read -rp "Do you want to re-run it with sudo? [y/N]: " SUDO_ASK
    if [[ "${SUDO_ASK,,}" == "y" ]]; then
        exec sudo bash "$0" "$@"
    else
        error "Run the script as root to proceed."
    fi
fi

# ── Check required commands ────────────────────────────
for cmd in systemd-cryptenroll realpath xargs grep cut sed; do
    command -v "$cmd" &>/dev/null || error "Required command '$cmd' not found"
done

# ── Check TPM2 support ─────────────────────────────────
if [[ -f /sys/class/tpm/tpm0/device/description ]]; then
    DESC=$(< /sys/class/tpm/tpm0/device/description)
    info "TPM device detected: $DESC"
else
    error "No TPM device found at /sys/class/tpm/tpm0"
fi

if ! systemd-analyze has-tpm2 &>/dev/null; then
    error "Systemd does not detect TPM2 support"
fi
success "Systemd TPM2 support detected"

# ── Detect root LUKS device via kernel cmdline ────────
RD_LUKS_UUID="$(xargs -n1 -a /proc/cmdline | grep -F "rd.luks.uuid" | cut -d= -f2 | sed 's/^luks-//')"
[[ -n "$RD_LUKS_UUID" ]] || error "Could not find rd.luks.uuid kernel parameter (not LUKS2 root?)"

ROOT_DEV="$(realpath "/dev/disk/by-uuid/${RD_LUKS_UUID}")"
[[ -b "$ROOT_DEV" ]] || error "Cannot find LUKS2 root device at $ROOT_DEV"

success "Detected root LUKS2 device: $ROOT_DEV"

# ── Enable or disable TPM2 auto-unlock ───────────────
read -rp "Enable TPM2 auto-unlock on this root device? [y/N]: " ENABLE
if [[ "${ENABLE,,}" == "n" || -z "$ENABLE" ]]; then
    info "Disabling TPM2 auto-unlock (wiping TPM2 slot)..."
    systemd-cryptenroll --wipe-slot=tpm2 "$ROOT_DEV"
    success "TPM2 auto-unlock disabled"
    exit 0
fi

# ── Ask if user wants a PIN ───────────────────────────
read -rp "Would you like to set up a TPM2 PIN? [y/N]: " USE_PIN
SET_PIN_ARG=""
if [[ "${USE_PIN,,}" == "y" ]]; then
    SET_PIN_ARG="--tpm2-with-pin=yes"
fi

# ── Ask for PCRs ──────────────────────────────────────
read -rp "Enter PCRs to bind TPM2 key [default: 7]: " PCR_INPUT
PCRS="${PCR_INPUT:-7}"

# ── Enroll TPM2 key ───────────────────────────────────
info "Enrolling TPM2 key..."
systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs="$PCRS" $SET_PIN_ARG "$ROOT_DEV"
success "TPM2 auto-unlock configured for next reboot."

# ── Enable systemd unlock service ────────────────────
info "Enabling systemd unlock service..."
systemctl enable --now systemd-cryptsetup@$(basename "$ROOT_DEV").service 2>/dev/null || \
    warn "Unlock service may already be enabled or not required"
success "Systemd unlock service configured."

# ── Summary ─────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  TPM2 Auto-Unlock Setup Complete!${NC}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════════${NC}"
echo ""
echo -e "  Root device: ${BOLD}$ROOT_DEV${NC}"
echo -e "  PCRs used : ${BOLD}$PCRS${NC}"
echo -e "  PIN set   : ${BOLD}${SET_PIN_ARG:+Yes}${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Reboot the system"
echo "  2. The root disk should unlock automatically via TPM2"
echo "  3. Your original passphrase remains as fallback"
echo ""
echo -e "Verify binding anytime: systemd-cryptenroll status $ROOT_DEV"
echo ""