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
say "${MAGENTA}${BOLD}║   ◈  NVIDIA Driver Installer  ◈          ║${NC}"
say "${MAGENTA}${BOLD}║   NVIDIA OPEN drivers for zcore          ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Config ────────────────────────────────────────────────────
KMODS_ZODIUM_REPO="zodium-project/kmods-zodium"
KMOD="nvidia"

# ── Temp dir with auto-cleanup ────────────────────────────────
WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}" nvidia-container.pp' EXIT

# ── Detect running kernel ─────────────────────────────────────
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | tail -1)"
[[ -n "${KERNEL_VERSION}" ]] || fail "Could not detect kernel version"
info "Kernel: ${KERNEL_VERSION}"

# ── Resolve release on kmods-zodium ──────────────────────────
RELEASE_TAG="kernel-${KERNEL_VERSION}"
RELEASE_API="https://api.github.com/repos/${KMODS_ZODIUM_REPO}/releases/tags/${RELEASE_TAG}"

info "Looking up kmods-zodium release: ${RELEASE_TAG}"
RELEASE_JSON="$(curl -fLsS "${RELEASE_API}")" \
  || fail "Release not found on kmods-zodium for kernel ${KERNEL_VERSION} — has kmods-zodium built this kernel yet?"

ok "Release found: ${RELEASE_TAG}"

# ── Find the nvidia.zip asset URL ────────────────────────────
ASSET_URL="$(
  printf '%s' "${RELEASE_JSON}" \
  | python3 -c "
import json, sys
assets = json.load(sys.stdin).get('assets', [])
match = next((a['browser_download_url'] for a in assets if a['name'] == 'nvidia.zip'), None)
if not match:
    raise SystemExit('nvidia.zip not found in release assets')
print(match)
")" || fail "nvidia.zip not found in release ${RELEASE_TAG} — kmods-zodium may still be building"

ok "Found asset: ${ASSET_URL}"

# ── Download & extract ────────────────────────────────────────
ZIP_PATH="${WORKDIR}/nvidia.zip"
RPM_DIR="${WORKDIR}/rpms"
mkdir -p "${RPM_DIR}"

info "Downloading nvidia.zip..."
curl -fL --progress-bar "${ASSET_URL}" -o "${ZIP_PATH}"
ok "Download complete"

info "Extracting RPMs..."
unzip -q "${ZIP_PATH}" -d "${RPM_DIR}"

RPM_COUNT="$(find "${RPM_DIR}" -name '*.rpm' | wc -l)"
[[ "${RPM_COUNT}" -gt 0 ]] || fail "No RPMs found inside nvidia.zip"
ok "Extracted ${RPM_COUNT} RPM(s):"
find "${RPM_DIR}" -name '*.rpm' | while read -r rpm; do
  say "  ${CYAN}◈${NC}  $(basename "${rpm}")"
done

# ── Install kmod RPMs ─────────────────────────────────────────
info "Installing nvidia kmod RPMs via dnf..."
dnf install -y --setopt=install_weak_deps=False "${RPM_DIR}"/*.rpm
ok "nvidia kmod RPMs installed"

# ── Refresh module dependencies ───────────────────────────────
info "Refreshing module dependencies..."
depmod -a "${KERNEL_VERSION}"
ok "depmod complete"

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
say "${MAGENTA}${BOLD}║   ◆  NVIDIA Driver Install Complete      ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""