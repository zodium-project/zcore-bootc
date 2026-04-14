#!/usr/bin/env bash
# ================================================================
#  Udev — hardware & peripheral udev rules for zcore
#  Zodium Project : github.com/zodium-project
# ================================================================

# ── Exit immediately if a command exits with a non-zero status ── #
set -Eeuo pipefail

# ── Styling ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

say()  { printf "$@"; printf '\n'; }
info() { say "${CYAN}◈${NC}  $*"; }
ok()   { say "${GREEN}◆${NC}  $*"; }
warn() { say "${YELLOW}◇${NC}  $*"; }
fail() { say "${RED}⦻${NC}  $*" >&2; exit 1; }

# ── Header ────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◈  Udev Rules Installer  ◈           ║${NC}"
say "${MAGENTA}${BOLD}║   hardware & peripheral support          ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Install udev packages ─────────────────────────────────────
info "Installing udev packages..."
dnf -y install --setopt=install_weak_deps=False \
    ublue-os-udev-rules \
    3dprinter-udev-rules \
    openrgb-udev-rules \
    solaar-udev \
    unifying-receiver-udev \
    udev-hid-bpf \
    udev-hid-bpf-stable \
    mooltipass-udev \
    xr-hardware \
    trezor-common \
    liquidctl-udev \
    oversteer-udev
ok "udev packages installed"

info "Running DNF cleanup..."
dnf clean all
ok "Cleanup complete"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  Udev Rules Install Complete        ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""