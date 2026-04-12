#!/usr/bin/env bash
# ================================================================
#  Mesa — GPU & video acceleration drivers install script
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
say "${MAGENTA}${BOLD}║   ◈  Mesa & GPU Driver Installer  ◈    ║${NC}"
say "${MAGENTA}${BOLD}║   negativo17 · mesa · intel · vaapi      ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Intel GPU & Video Acceleration Drivers ────────────────────
GPU_PKGS=(
    intel-vpl-gpu-rt
    intel-gmmlib
    libva-intel-media-driver
)

info "Installing Intel GPU & video acceleration drivers..."
for pkg in "${GPU_PKGS[@]}"; do
    say "  ${CYAN}◈${NC}  ${pkg}"
done

dnf install -y --setopt=install_weak_deps=False \
    "${GPU_PKGS[@]}"

ok "Intel GPU packages installed"

# ── Install mesa packages from negativo17 ─────────────────────
MESA_PKGS=(
    mesa-va-drivers
    mesa-vulkan-drivers
)

info "Installing mesa packages from negativo17..."
for pkg in "${MESA_PKGS[@]}"; do
    say "  ${CYAN}◈${NC}  ${pkg}"
done

dnf install -y \
    --setopt=install_weak_deps=False \
    --exclude='*.i686' \
    "${MESA_PKGS[@]}"

ok "Mesa packages installed"

# ── DNF Cleanup ───────────────────────────────────────────────
info "Running DNF cleanup..."
dnf clean all
dnf autoremove -y
dnf clean packages
ok "Cleanup complete"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  Mesa & GPU Install Complete        ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""