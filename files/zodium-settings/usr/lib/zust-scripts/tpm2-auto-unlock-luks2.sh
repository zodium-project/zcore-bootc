#!/usr/bin/env bash
# =============================================================================
# Interactive TPM2 Auto-Unlock Setup for LUKS2 (Root prompt included)
# =============================================================================

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────── #
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERR]${NC}   $*" >&2; exit 1; }

# ── Root check ───────────────────────────────────────────────────────────── #
if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}This script must be run as root.${NC}"
    read -rp "Do you want to re-run it with sudo? [Y/n]: " SUDO_ASK
    if [[ "${SUDO_ASK,,}" == "y" ]]; then
        exec sudo bash "$0" "$@"
    else
        error "Run the script as root to proceed."
    fi
fi

# ── Check commands ───────────────────────────────────────────────────────── #
for cmd in systemd-cryptenroll cryptsetup; do
    command -v "$cmd" &>/dev/null || error "Required command '$cmd' not found"
done

# ── Check TPM2 support ───────────────────────────────────────────────────── #
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

# ── Detect root LUKS device ──────────────────────────────────────────────── #
ROOT_DEV=$(findmnt -n -o SOURCE /)
info "Detected root device: $ROOT_DEV"

if [[ ! -b "$ROOT_DEV" ]]; then
    warn "Root device '$ROOT_DEV' is not a block device (not LUKS2)."
    error "Cannot enroll TPM2: only the currently booted root device can be enrolled."
fi

if ! cryptsetup luksDump "$ROOT_DEV" &>/dev/null; then
    error "Root device '$ROOT_DEV' is not a valid LUKS device."
fi

LUKS_VER=$(cryptsetup luksDump "$ROOT_DEV" | awk '/^Version:/{print $2}')
[[ "$LUKS_VER" == "2" ]] || error "Root device '$ROOT_DEV' is not LUKS2 (found version $LUKS_VER)."

success "Confirmed LUKS2 on root device: $ROOT_DEV"

# ── Ask for PCRs ─────────────────────────────────────────────────────────── #
echo ""
echo -e "${BOLD}Choose PCRs to bind TPM2 key to:${NC}"
echo "  PCR 7  → Secure Boot state (recommended)"
echo "  PCR 0  → Core firmware/UEFI code"
echo "  PCR 1  → Firmware config (BIOS settings)"
echo ""
read -rp "Enter PCRs (comma-separated) [default: 7]: " PCR_INPUT
PCRS="${PCR_INPUT:-7}"
info "Using PCRs: $PCRS"

# ── Confirm enrollment ───────────────────────────────────────────────────── #
echo ""
warn "This will enroll a TPM2 key on your root LUKS2 device."
warn "Your existing passphrase will still work as fallback."
read -rp "Proceed with TPM2 auto-unlock enrollment? [y/N]: " CONFIRM
[[ "${CONFIRM,,}" == "y" ]] || error "Enrollment cancelled by user"

# ── Enroll TPM2 key ──────────────────────────────────────────────────────── #
info "Enrolling TPM2 key..."
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs="$PCRS" "$ROOT_DEV"
success "TPM2 key enrolled successfully"

# ── Enable systemd unlock service ───────────────────────────────────────── #
info "Enabling systemd unlock socket..."
systemctl enable --now systemd-cryptsetup@$(basename "$ROOT_DEV").service 2>/dev/null || \
    warn "Unlock service may already be enabled or not required"
success "Systemd unlock service configured"

# ── Summary ─────────────────────────────────────────────────────────────── #
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  TPM2 Auto-Unlock Setup Complete!${NC}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Root device: ${BOLD}$ROOT_DEV${NC}"
echo -e "  PCRs used : ${BOLD}$PCRS${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Reboot the system"
echo "  2. The root disk should unlock automatically via TPM2"
echo "  3. Your original passphrase remains as fallback"
echo ""
echo -e "Verify binding anytime:  systemd-cryptenroll status $ROOT_DEV"
echo ""