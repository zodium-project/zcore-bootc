#!/usr/bin/env bash
# ================================================================
#  Virt-Kvm — Install packages for a featureful KVM host
# ================================================================

set -Eeuo pipefail

# ── Styling ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'
DIM='\033[2m'; BLUE='\033[0;34m'

say()  { printf '%b\n' "$*"; }
ok()   { say "${GREEN}◆${NC}  $*"; }
warn() { say "${YELLOW}◇${NC}  $*"; }
fail() { say "${RED}⦻${NC}  $*" >&2; exit 1; }
step() { say "${BLUE}›${NC}  $*"; }

PACKAGES=(
    qemu-kvm
    qemu-img
    libvirt
    libvirt-daemon-kvm
    libvirt-daemon-driver-qemu
    libvirt-daemon-driver-nodedev
    libvirt-daemon-config-network
    edk2-ovmf
    swtpm
    swtpm-tools
    qemu-device-display-virtio-gpu
    qemu-device-display-virtio-gpu-gl
    qemu-device-display-virtio-vga-gl
    virtio-win
    virtiofsd
    virt-install
    virt-viewer
)

# ── Header ────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◈  KVM Setup  ◈                  ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════╝${NC}"
say ""

# ── Install packages ──────────────────────────────────────────
step "Installing KVM packages..."
dnf --setopt=install_weak_deps=false install -y "${PACKAGES[@]}"
ok "Packages installed"

# ── Ensure libvirt group exists ───────────────────────────────
step "Ensuring libvirt group exists..."
if ! getent group libvirt > /dev/null; then
    groupadd -r libvirt
    ok "libvirt group created"
else
    ok "libvirt group already exists"
fi

step "Ensuring kvm group exists..."
if ! getent group kvm > /dev/null; then
    groupadd -r kvm
    ok "kvm group created"
else
    ok "kvm group already exists"
fi

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  KVM Setup Complete  ◆         ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════╝${NC}"
say ""
say "  ${YELLOW}◇${NC}  ${DIM}To start libvirt:     systemctl enable --now libvirtd${NC}"
say "  ${YELLOW}◇${NC}  ${DIM}To add your user:     usermod -aG libvirt,kvm \$(whoami)${NC}"
say ""