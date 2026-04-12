#!/usr/bin/env bash
# ================================================================
#  Multimedia — negativo17 codec install
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
say "${MAGENTA}${BOLD}║   ◈  Multimedia Stack Installer  ◈     ║${NC}"
say "${MAGENTA}${BOLD}║   negativo17 · codecs · audio · gpu      ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Multimedia Codecs & Libraries ─────────────────────────────
MULTIMEDIA_PKGS=(
    ffmpeg
    ffmpeg-libs
    gstreamer1-plugin-libav
    gstreamer1-plugins-bad
    gstreamer1-plugins-ugly
    gstreamer1-plugins-good
    gstreamer1-plugins-good-extras
    libfreeaptx
    libfdk-aac
    libwebp
    libheif
    libjxl
    libldac
    exiv2
)

info "Installing multimedia codecs & libraries..."
for pkg in "${MULTIMEDIA_PKGS[@]}"; do
    say "  ${CYAN}◈${NC}  ${pkg}"
done

dnf install -y --setopt=install_weak_deps=False \
    --exclude='*.i686' \
    "${MULTIMEDIA_PKGS[@]}"

ok "Multimedia codecs & libraries installed"

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

# ── PipeWire Audio Stack ──────────────────────────────────────
PIPEWIRE_PKGS=(
    wireplumber
    pipewire
    pipewire-libs
    pipewire-libs-extra
    pipewire-jack-audio-connection-kit-libs
    pipewire-jack-audio-connection-kit
    pipewire-pulseaudio
    pipewire-alsa
    pipewire-gstreamer
    pipewire-config-raop
)

info "Installing PipeWire audio stack..."
for pkg in "${PIPEWIRE_PKGS[@]}"; do
    say "  ${CYAN}◈${NC}  ${pkg}"
done

dnf install -y --setopt=install_weak_deps=False \
    "${PIPEWIRE_PKGS[@]}"

ok "PipeWire audio stack installed"

# ── DNF Cleanup ───────────────────────────────────────────────
info "Running DNF cleanup..."
dnf clean all
dnf autoremove -y
dnf clean packages
ok "Cleanup complete"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  Multimedia Stack Install Complete  ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""