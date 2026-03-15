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
say "${MAGENTA}${BOLD}║   ◈  Mesa & GPU Driver Installer  ◈      ║${NC}"
say "${MAGENTA}${BOLD}║   negativo17 · mesa · intel · vaapi      ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Add negativo17 Fedora Multimedia Repo ─────────────────────
info "Adding negativo17 fedora-multimedia repo..."

dnf config-manager addrepo \
    --from-repofile=https://negativo17.org/repos/fedora-multimedia.repo

info "Setting fedora-multimedia repo priority..."
dnf config-manager setopt fedora-multimedia.priority=90

ok "negativo17 fedora-multimedia repo added"

# ── Intel GPU & Video Acceleration Drivers ────────────────────
GPU_PKGS=(
    intel-vpl-gpu-rt
    intel-gmmlib
    intel-mediasdk
    libva-intel-media-driver
    gstreamer1-vaapi
)

info "Installing Intel GPU & video acceleration drivers..."
for pkg in "${GPU_PKGS[@]}"; do
    say "  ${CYAN}◈${NC}  ${pkg}"
done

dnf install -y --setopt=install_weak_deps=False \
    "${GPU_PKGS[@]}"

ok "Intel GPU packages installed"

# ── Sync pre-installed mesa packages to negativo17 versions ────
MESA_SYNC=(
    mesa-dri-drivers
    mesa-filesystem
    mesa-libEGL
    mesa-libGL
    mesa-libgbm
)

info "Syncing pre-installed mesa packages to negativo17 versions..."
for pkg in "${MESA_SYNC[@]}"; do
    say "  ${CYAN}◈${NC}  ${pkg}"
done

dnf distro-sync -y --setopt=install_weak_deps=False \
    --repo=fedora-multimedia "${MESA_SYNC[@]}"

ok "Pre-installed mesa packages synced"

# ── Install remaining mesa packages from negativo17 ───────────
MESA_INSTALL=(
    mesa-va-drivers
    mesa-vulkan-drivers
)

info "Installing remaining mesa packages from negativo17..."
for pkg in "${MESA_INSTALL[@]}"; do
    say "  ${CYAN}◈${NC}  ${pkg}"
done

dnf install -y \
    --setopt=install_weak_deps=False \
    --exclude='*.i686' \
    "${MESA_INSTALL[@]}"

ok "Remaining mesa packages installed"

# ── DNF Cleanup ───────────────────────────────────────────────
info "Running DNF cleanup..."
dnf clean all
dnf autoremove -y
dnf clean packages
ok "Cleanup complete"

# ── Remove negativo17 Repo ────────────────────────────────────
info "Removing negativo17 fedora-multimedia repo..."
dnf config-manager setopt fedora-multimedia.enabled=0
rm -f /etc/yum.repos.d/fedora-multimedia.repo
ok "negativo17 repo removed"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  Mesa & GPU Install Complete         ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""