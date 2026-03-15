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
say "${MAGENTA}${BOLD}║   ◈  Multimedia Stack Installer  ◈       ║${NC}"
say "${MAGENTA}${BOLD}║   negativo17 · codecs · audio · gpu      ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Add negativo17 Fedora Multimedia Repo ─────────────────────
say "${CYAN}${BOLD}┌─ Repository Setup ──────────────────────┐${NC}"
say ""

info "Adding negativo17 fedora-multimedia repo..."

dnf config-manager addrepo \
    --from-repofile=https://negativo17.org/repos/fedora-multimedia.repo

info "Setting fedora-multimedia repo priority..."
dnf config-manager setopt fedora-multimedia.priority=90

ok "negativo17 fedora-multimedia repo added"
say ""
say "${CYAN}${BOLD}└─────────────────────────────────────────┘${NC}"
say ""

# ── Multimedia Codecs & Libraries ─────────────────────────────
say "${CYAN}${BOLD}┌─ Multimedia Codecs & Libraries ─────────┐${NC}"
say ""

MULTIMEDIA_PKGS=(
    ffmpeg
    ffmpeg-libs
    libfdk-aac
    gstreamer1-plugin-libav
    gstreamer1-plugins-good
    gstreamer1-plugins-good-extras
    gstreamer1-plugins-bad
    gstreamer1-plugins-ugly
    gstreamer1-vaapi
    libva
    libheif
    libjxl
    libwebp6
    libldac
    exiv2
)

info "Installing multimedia codecs & libraries..."
for pkg in "${MULTIMEDIA_PKGS[@]}"; do
    say "  ${CYAN}◈${NC}  ${pkg}"
done
say ""

dnf distro-sync --skip-unavailable -y \
    --setopt=install_weak_deps=False \
    --repo=fedora-multimedia "${MULTIMEDIA_PKGS[@]}"

ok "Multimedia codecs & libraries installed"
say ""
say "${CYAN}${BOLD}└─────────────────────────────────────────┘${NC}"
say ""

# ── GPU / Video Acceleration Drivers ─────────────────────────
say "${CYAN}${BOLD}┌─ GPU & Video Acceleration Drivers ──────┐${NC}"
say ""

GPU_PKGS=(
    intel-gmmlib
    intel-mediasdk
    intel-vpl-gpu-rt
    libva-intel-media-driver
    mesa-dri-drivers
    mesa-filesystem
    mesa-libEGL
    mesa-libGL
    mesa-libgbm
    mesa-va-drivers
    mesa-vulkan-drivers
)

info "Overriding GPU & video acceleration packages from fedora-multimedia..."
for pkg in "${GPU_PKGS[@]}"; do
    say "  ${CYAN}◈${NC}  ${pkg}"
done
say ""

dnf distro-sync --skip-unavailable -y \
    --setopt=install_weak_deps=False \
    --repo=fedora-multimedia "${GPU_PKGS[@]}"

ok "GPU & video acceleration drivers installed"
say ""
say "${CYAN}${BOLD}└─────────────────────────────────────────┘${NC}"
say ""

# ── PipeWire Audio Stack ──────────────────────────────────────
say "${CYAN}${BOLD}┌─ PipeWire Audio Stack ───────────────────┐${NC}"
say ""

PIPEWIRE_PKGS=(
    wireplumber
    pipewire
    pipewire-libs
    pipewire-jack-audio-connection-kit-libs
    pipewire-jack-audio-connection-kit
    pipewire-codec-aptx
    pipewire-pulseaudio
    pipewire-alsa
    pipewire-gstreamer
    pipewire-config-raop
)

info "Installing PipeWire audio stack..."
for pkg in "${PIPEWIRE_PKGS[@]}"; do
    say "  ${CYAN}◈${NC}  ${pkg}"
done
say ""

dnf distro-sync --skip-unavailable -y \
    --setopt=install_weak_deps=False \
    --repo=fedora-multimedia "${PIPEWIRE_PKGS[@]}"

ok "PipeWire audio stack installed"
say ""
say "${CYAN}${BOLD}└─────────────────────────────────────────┘${NC}"
say ""

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
say "${MAGENTA}${BOLD}║   ◆  Multimedia Stack Install Complete   ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""