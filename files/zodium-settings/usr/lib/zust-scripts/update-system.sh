#!/usr/bin/env bash
# ================================================================
#  update-system — Updates system using zyncc (core updates only)
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

# ── Helpers ─────────────────────────────────────────────────── #
die()  { printf "%b[!] ERROR%b %s\n" "${RED}" "${RESET}" "$1" >&2; exit 1; }
info() { printf "%b[*]%b  %s\n" "${CYAN}" "${RESET}" "$1"; }
ok()   { printf "%b[+]%b  %s\n" "${GREEN}" "${RESET}" "$1"; }
warn() { printf "%b[!]%b  %s\n" "${YELLOW}" "${RESET}" "$1"; }

# ── Header ─────────────────────────────────────────────────── #
printf "%b%s System Update %s%b\n" "${CYAN}${BOLD}" "[*]" "[*]" "${RESET}"
echo

# ── Run zync update ─────────────────────────────────────────── #
info "Running system update using zync..."
if ! sudo /usr/bin/zync --system --flatpak --firmware; then
    die "zync update failed."
fi
ok "System update completed successfully."