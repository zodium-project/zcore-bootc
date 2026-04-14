#!/usr/bin/env bash
# ================================================================
#  Nvidia Open — NVIDIA OPEN drivers install script for zcore
#  Zodium Project : github.com/zodium-project
# ================================================================

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
say "${MAGENTA}${BOLD}║   ◈  NVIDIA Driver Installer  ◈        ║${NC}"
say "${MAGENTA}${BOLD}║   NVIDIA OPEN drivers for zcore          ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Detect running kernel ─────────────────────────────────────
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | tail -1)"
[[ -n "${KERNEL_VERSION}" ]] || fail "Could not detect kernel version"
info "Kernel: ${KERNEL_VERSION}"

# ── Add Negativo17 NVIDIA repo ────────────────────────────────
say ""
info "Adding Negativo17 NVIDIA repo..."
dnf config-manager addrepo \
    --from-repofile=https://negativo17.org/repos/fedora-nvidia.repo
dnf config-manager setopt fedora-nvidia.enabled=1
dnf config-manager setopt fedora-nvidia.priority=90
info "Disabling Negativo17 Multimedia repo..."
dnf config-manager setopt fedora-multimedia.enabled=0
dnf --refresh makecache
ok "Negativo17 repos added"

# ── Install kmod RPMs ─────────────────────────────────────────
info "Installing nvidia kmod RPMs via dnf..."
dnf install -y --setopt=install_weak_deps=False \
               nvidia-modprobe                  \
               nvidia-kmod-common               \
               nvidia-driver-selinux            \
               kmod-nvidia-"${KERNEL_VERSION}"
ok "nvidia kmod RPMs installed"

# ── Install NVIDIA userspace & container toolkit ──────────────
info "Installing NVIDIA userspace driver and container toolkit..."

curl -fLsS \
    -o /etc/yum.repos.d/nvidia-container-toolkit.repo \
    https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo

sed -i 's/^gpgcheck=0/gpgcheck=1/' /etc/yum.repos.d/nvidia-container-toolkit.repo
sed -i 's/^enabled=0.*/enabled=1/' /etc/yum.repos.d/nvidia-container-toolkit.repo

dnf install -y --setopt=install_weak_deps=False \
    nvidia-driver \
    nvidia-persistenced \
    nvidia-settings \
    nvidia-driver-cuda \
    nvidia-driver-NvFBCOpenGL \
    nvidia-container-toolkit \
    libnvidia-fbc \
    libva-nvidia-driver
ok "NVIDIA userspace installed"

info "Installing SELinux policy module..."
curl -fLsS \
    -o nvidia-container.pp \
    https://raw.githubusercontent.com/NVIDIA/dgx-selinux/master/bin/RHEL9/nvidia-container.pp
semodule -i nvidia-container.pp
ok "SELinux policy module installed"

# ── Remove repos ──────────────────────────────────────────────
info "Removing temporary repos..."
rm -f /etc/yum.repos.d/nvidia-container-toolkit.repo
dnf config-manager setopt fedora-nvidia.enabled=0
rm -f /etc/yum.repos.d/fedora-nvidia.repo
ok "Temporary repos removed"
info "Enabling Negativo17 Multimedia repo..."
dnf config-manager setopt fedora-multimedia.enabled=1

# ── DNF Cleanup ───────────────────────────────────────────────
info "Running DNF cleanup..."
dnf clean all
dnf autoremove -y
dnf clean packages
ok "Cleanup complete"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  NVIDIA Driver Install Complete     ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""