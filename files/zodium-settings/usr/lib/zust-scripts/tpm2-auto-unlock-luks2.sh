#!/usr/bin/env bash
set -Eeuo pipefail

# ── Styling ───────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

ICON_INFO="[i]"
ICON_OK="[✔]"
ICON_WARN="[!]"
ICON_ERR="[X]"
ICON_LOCK="[L]"

info()  { echo -e "${CYAN}${ICON_INFO}${NC}  $*"; }
ok()    { echo -e "${GREEN}${ICON_OK}${NC}    $*"; }
warn()  { echo -e "${YELLOW}${ICON_WARN}${NC}  $*"; }
fail()  { echo -e "${RED}${ICON_ERR}${NC}   $*" >&2; exit 1; }

# ── Root Check ────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}This script must be run as root.${NC}"
    read -rp "Re-run with sudo? [y/N]: " yn
    if [[ "${yn,,}" == "y" ]]; then
        exec sudo bash "$0" "$@"
    else
        fail "Run the script as root to continue."
    fi
fi

# ── TPM Check ─────────────────────────────────────────
if [[ -f /sys/class/tpm/tpm0/device/description ]]; then
    info "TPM device detected: $(< /sys/class/tpm/tpm0/device/description)"
else
    fail "No TPM2 device detected."
fi

if ! systemd-analyze has-tpm2 &>/dev/null; then
    fail "Systemd TPM2 support not available."
fi
ok "Systemd TPM2 support detected"

# ── Detect Root Device (Aurora Logic) ────────────────
info "Detecting LUKS2 root device from kernel parameters..."

RD_LUKS_UUID="$(xargs -n1 -a /proc/cmdline \
    | grep -F 'rd.luks.uuid=' \
    | cut -d= -f2 \
    | sed 's/^luks-//' || true)"

if [[ -z "${RD_LUKS_UUID:-}" ]]; then
    warn "No LUKS root detected in kernel parameters."
    warn "Your root filesystem does not appear to be LUKS-encrypted."
    fail "Cannot enroll TPM2 auto-unlock without a LUKS2 root device."
fi

CRYPT_DISK="$(realpath "/dev/disk/by-uuid/${RD_LUKS_UUID}")"

if ! find /dev -iname "${RD_LUKS_UUID:-INVALID}" \
    | grep -F "${RD_LUKS_UUID}" &>/dev/null; then
    fail "Could not find LUKS device used to boot system."
fi

ok "Detected root device: ${BOLD}${CRYPT_DISK}${NC}"

# ── Enable / Disable ──────────────────────────────────
echo ""
read -rp "Enable TPM2 auto-unlock? [y/N]: " ENABLE

if [[ "${ENABLE,,}" == "n" || -z "$ENABLE" ]]; then
    info "Disabling TPM2 auto-unlock (wiping TPM2 slot)..."
    systemd-cryptenroll --wipe-slot=tpm2 "${CRYPT_DISK}"
    ok "TPM2 auto-unlock disabled"
    exit 0
fi

# ── Optional PIN ──────────────────────────────────────
echo ""
read -rp "Would you like to set up a TPM2 PIN? [y/N]: " USE_PIN
SET_PIN_ARG=""

if [[ "${USE_PIN,,}" == "y" ]]; then
    SET_PIN_ARG="--tpm2-with-pin=yes"
fi

# ── PCR Selection ─────────────────────────────────────
read -rp "Enter PCRs to bind TPM2 key [default: 7]: " PCR_INPUT
PCRS="${PCR_INPUT:-7}"

# ── Enroll ────────────────────────────────────────────
echo ""
info "Enrolling TPM2 key..."
systemd-cryptenroll \
    --wipe-slot=tpm2 \
    --tpm2-device=auto \
    --tpm2-pcrs="${PCRS}" \
    ${SET_PIN_ARG} \
    "${CRYPT_DISK}"

ok "TPM2 auto-unlock configured for next reboot."

# ── Summary ───────────────────────────────────────────
echo ""
echo -e "${MAGENTA}${BOLD}╔════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}${BOLD}║        TPM2 Auto-Unlock Successfully Set   ║${NC}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Root device : ${BOLD}${CRYPT_DISK}${NC}"
echo -e "  PCRs used   : ${BOLD}${PCRS}${NC}"
echo -e "  PIN enabled : ${BOLD}${SET_PIN_ARG:+Yes}${NC}"
echo ""
echo "Reboot to verify automatic unlock."
echo "Fallback passphrase remains available."