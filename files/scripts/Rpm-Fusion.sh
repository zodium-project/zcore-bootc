#!/usr/bin/env bash
# ================================================================
#  Rpm-Fusion — Enable RPM Fusion repos
#  Zodium Project
# ================================================================

set -Eeuo pipefail

# ── Styling ───────────────────────────────────────────────────
GREEN='\033[0;32m'; CYAN='\033[0;36m'
MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

say()  { printf "$@"; printf '\n'; }
info() { say "${CYAN}◈${NC}  $*"; }
ok()   { say "${GREEN}◆${NC}  $*"; }

# ── Header ────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◈  RPM Fusion Setup  ◈                 ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Enable RPM Fusion ─────────────────────────────────────────
info "Installing RPM Fusion free and nonfree repos..."
dnf install \
    https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
ok "RPM Fusion repos installed"

info "Installing tainted repos..."
dnf install \
    rpmfusion-free-release-tainted \
    rpmfusion-nonfree-release-tainted
ok "Tainted repos installed"

info "Checking for upgrades..."
dnf --refresh check-upgrade

# ── a backup for bling module ─────────────────────────────────

ok "RPM Fusion setup complete"
say ""