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
info "Adding negativo17 fedora-multimedia repo..."

dnf config-manager addrepo \
    --from-repofile=https://negativo17.org/repos/fedora-multimedia.repo

info "Setting fedora-multimedia repo priority..."
dnf config-manager setopt fedora-multimedia.priority=90

ok "negativo17 fedora-multimedia repo added"

# ── Install intel-vpl-gpu-rt first (provides libvpl.so.2) ─────
info "Installing intel-vpl-gpu-rt..."
dnf install -y --setopt=install_weak_deps=False intel-vpl-gpu-rt
ok "intel-vpl-gpu-rt installed"

# ── Swap fdk-aac-free for libfdk-aac from negativo17 ──────────
info "Swapping fdk-aac-free for libfdk-aac..."
dnf swap -y --repo=fedora-multimedia fdk-aac-free libfdk-aac
ok "libfdk-aac swapped"

# ── Install negativo17 Multimedia Codecs ──────────────────────
NEGATIVO_PKGS=(
    ffmpeg
    ffmpeg-libs
    gstreamer1-plugin-libav
    gstreamer1-plugins-bad
    gstreamer1-plugins-ugly
    libva
    libwebp6
    libheif
)

info "Installing negativo17 multimedia codecs..."
for pkg in "${NEGATIVO_PKGS[@]}"; do
    say "  ${CYAN}◈${NC}  ${pkg}"
done

dnf install -y --setopt=install_weak_deps=False \
    --repo=fedora-multimedia "${NEGATIVO_PKGS[@]}"

ok "negativo17 multimedia codecs installed"

# ── Install Fedora Base Multimedia Packages ───────────────────
FEDORA_PKGS=(
    gstreamer1-plugins-good
    gstreamer1-plugins-good-extras
    gstreamer1-vaapi
    libjxl
    libldac
    exiv2
)

info "Installing Fedora base multimedia packages..."
for pkg in "${FEDORA_PKGS[@]}"; do
    say "  ${CYAN}◈${NC}  ${pkg}"
done

dnf install -y --setopt=install_weak_deps=False \
    "${FEDORA_PKGS[@]}"

ok "Fedora multimedia packages installed"

# ── Swap mesa packages with negativo17 versions ───────────────
MESA_SWAPS=(
    mesa-dri-drivers
    mesa-filesystem
    mesa-libEGL
    mesa-libGL
    mesa-libgbm
    mesa-va-drivers
    mesa-vulkan-drivers
)

info "Swapping mesa packages from fedora-multimedia..."
for pkg in "${MESA_SWAPS[@]}"; do
    say "  ${CYAN}◈${NC}  ${pkg}"
done

dnf install -y --setopt=install_weak_deps=False \
    --repo=fedora-multimedia "${MESA_SWAPS[@]}"

ok "mesa packages swapped"

# ── Install remaining GPU packages ────────────────────────────
GPU_PKGS=(
    intel-gmmlib
    intel-mediasdk
    libva-intel-media-driver
)

info "Installing GPU packages from fedora-multimedia..."
for pkg in "${GPU_PKGS[@]}"; do
    say "  ${CYAN}◈${NC}  ${pkg}"
done

dnf install -y --setopt=install_weak_deps=False \
    --repo=fedora-multimedia "${GPU_PKGS[@]}"

ok "GPU packages installed"

# ── Install PipeWire Audio Stack ──────────────────────────────
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

dnf install -y --setopt=install_weak_deps=False \
    "${PIPEWIRE_PKGS[@]}"

ok "PipeWire audio stack installed"

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
say ""#!/usr/bin/env bash
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
info "Adding negativo17 fedora-multimedia repo..."

dnf config-manager addrepo \
    --from-repofile=https://negativo17.org/repos/fedora-multimedia.repo

info "Setting fedora-multimedia repo priority..."
dnf config-manager setopt fedora-multimedia.priority=90

ok "negativo17 fedora-multimedia repo added"

# ── Install intel-vpl-gpu-rt first (provides libvpl.so.2) ─────
info "Installing intel-vpl-gpu-rt..."
dnf install -y --setopt=install_weak_deps=False intel-vpl-gpu-rt
ok "intel-vpl-gpu-rt installed"

# ── Swap fdk-aac-free for libfdk-aac from negativo17 ──────────
info "Swapping fdk-aac-free for libfdk-aac..."
dnf swap -y --repo=fedora-multimedia fdk-aac-free libfdk-aac
ok "libfdk-aac swapped"

# ── Install negativo17 Multimedia Codecs ──────────────────────
NEGATIVO_PKGS=(
    ffmpeg
    ffmpeg-libs
    gstreamer1-plugin-libav
    gstreamer1-plugins-bad
    gstreamer1-plugins-ugly
    libva
    libwebp6
    libheif
)

info "Installing negativo17 multimedia codecs..."
for pkg in "${NEGATIVO_PKGS[@]}"; do
    say "  ${CYAN}◈${NC}  ${pkg}"
done

dnf install -y --setopt=install_weak_deps=False \
    --repo=fedora-multimedia "${NEGATIVO_PKGS[@]}"

ok "negativo17 multimedia codecs installed"

# ── Install Fedora Base Multimedia Packages ───────────────────
FEDORA_PKGS=(
    gstreamer1-plugins-good
    gstreamer1-plugins-good-extras
    gstreamer1-vaapi
    libjxl
    libldac
    exiv2
)

info "Installing Fedora base multimedia packages..."
for pkg in "${FEDORA_PKGS[@]}"; do
    say "  ${CYAN}◈${NC}  ${pkg}"
done

dnf install -y --setopt=install_weak_deps=False \
    "${FEDORA_PKGS[@]}"

ok "Fedora multimedia packages installed"

# ── Swap mesa packages with negativo17 versions ───────────────
MESA_SWAPS=(
    mesa-dri-drivers
    mesa-filesystem
    mesa-libEGL
    mesa-libGL
    mesa-libgbm
    mesa-va-drivers
    mesa-vulkan-drivers
)

info "Swapping mesa packages from fedora-multimedia..."
for pkg in "${MESA_SWAPS[@]}"; do
    say "  ${CYAN}◈${NC}  ${pkg}"
done

dnf install -y --setopt=install_weak_deps=False \
    --repo=fedora-multimedia "${MESA_SWAPS[@]}"

ok "mesa packages swapped"

# ── Install remaining GPU packages ────────────────────────────
GPU_PKGS=(
    intel-gmmlib
    intel-mediasdk
    libva-intel-media-driver
)

info "Installing GPU packages from fedora-multimedia..."
for pkg in "${GPU_PKGS[@]}"; do
    say "  ${CYAN}◈${NC}  ${pkg}"
done

dnf install -y --setopt=install_weak_deps=False \
    --repo=fedora-multimedia "${GPU_PKGS[@]}"

ok "GPU packages installed"

# ── Install PipeWire Audio Stack ──────────────────────────────
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

dnf install -y --setopt=install_weak_deps=False \
    "${PIPEWIRE_PKGS[@]}"

ok "PipeWire audio stack installed"

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