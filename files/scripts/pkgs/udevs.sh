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

# ── Add COPR repo ─────────────────────────────────────────────
info "Enabling ublue-os/packages COPR..."
dnf -y copr enable ublue-os/packages
ok "COPR repo enabled"

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
    liquidctl-udev
ok "udev packages installed"

# ── Oversteer wheel rules ─────────────────────────────────────
info "Fetching Oversteer wheel rules..."
RULES_DIR="/usr/lib/udev/rules.d"
OVERSTEER_BASE="https://github.com/berarma/oversteer/raw/refs/heads/master/data/udev"

curl -fLsS -o "${RULES_DIR}/99-fanatec-wheel-perms.rules"      "${OVERSTEER_BASE}/99-fanatec-wheel-perms.rules"
curl -fLsS -o "${RULES_DIR}/99-logitech-wheel-perms.rules"     "${OVERSTEER_BASE}/99-logitech-wheel-perms.rules"
curl -fLsS -o "${RULES_DIR}/99-thrustmaster-wheel-perms.rules" "${OVERSTEER_BASE}/99-thrustmaster-wheel-perms.rules"
ok "Oversteer wheel rules installed"

# ── Cleanup ───────────────────────────────────────────────────
info "Disabling COPR repo..."
dnf -y copr disable ublue-os/packages
rm -rf /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:ublue-os:packages.repo
ok "COPR repo disabled"

info "Running DNF cleanup..."
dnf clean all
ok "Cleanup complete"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  Udev Rules Install Complete        ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""