#!/usr/bin/env bash
# ================================================================
#  enroll-secure-boot-key — MOK Enrollment Script
#  Automatically adds a MOK key to Secure Boot pending list
# ================================================================

set -Eeuo pipefail

# ── Colors ───────────────────────────────────────────────────── #

if [[ -t 1 ]] && tput colors &>/dev/null && [[ $(tput colors) -ge 8 ]]; then
    RED="\033[31m";    GREEN="\033[32m";  YELLOW="\033[33m"
    BLUE="\033[34m";   MAGENTA="\033[35m"; CYAN="\033[36m"
    BOLD="\033[1m";    DIM="\033[2m";    RESET="\033[0m"
else
    RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" BOLD="" DIM="" RESET=""
fi

# ── Config ─────────────────────────────────────────────────── #

ENROLLMENT_PASSWORD="zodium"
ENROLLMENT_MOK_DER="/etc/pki/akmods/certs/zodium-akmod.der"

# ── Helpers ─────────────────────────────────────────────────── #

die()  { printf "%b[!] ERROR%b %s\n" "${RED}" "${RESET}" "$1" >&2; exit 1; }
info() { printf "%b[*]%b  %s\n" "${CYAN}" "${RESET}" "$1"; }
ok()   { printf "%b[+]%b  %s\n" "${GREEN}" "${RESET}" "$1"; }
warn() { printf "%b[!]%b  %s\n" "${YELLOW}" "${RESET}" "$1"; }

# ── Header ─────────────────────────────────────────────────── #

printf "%b%s Secure Boot MOK Enrollment %s%b\n" "${CYAN}${BOLD}" "[*]" "[*]" "${RESET}"
echo

# ── Enrollment ───────────────────────────────────────────────── #

sudo bash <<EOF
# Check MOK file exists (root via sudo)
if [[ ! -f "$ENROLLMENT_MOK_DER" ]]; then
    echo -e "${YELLOW}[!] ERROR: MOK file not found at $ENROLLMENT_MOK_DER${RESET}"
    exit 1
fi

echo -e "${CYAN}[*] Starting MOK enrollment...${RESET}"

# Import MOK and capture output
OUTPUT=\$(echo -e "$ENROLLMENT_PASSWORD\n$ENROLLMENT_PASSWORD" | mokutil --import "$ENROLLMENT_MOK_DER" 2>&1)

# Handle SKIP / already pending
if [[ "\$OUTPUT" == *"SKIP:"* ]]; then
    echo -e "${YELLOW}[!] Key already pending enrollment.${RESET}"
else
    echo -e "${GREEN}[+] MOK enrollment request added.${RESET}"
fi
EOF

# ── Instructions ─────────────────────────────────────────────── #

echo
echo -e "${CYAN}[i] Next steps:${RESET}"
echo -e "  1. Reboot your system."
echo -e "  2. When the MOK menu appears, select '${BOLD}Enroll MOK${RESET}${CYAN}'."
echo -e "  3. Type the password: '${BOLD}$ENROLLMENT_PASSWORD${RESET}${CYAN}'."
echo -e "  4. Press '${BOLD}Enter${RESET}' to confirm, then reboot."