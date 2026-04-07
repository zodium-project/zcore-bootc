#!/usr/bin/env bash
# ================================================================
#  Broadcom Wl — install pre-built kmod RPMs from kmods-zodium
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
say "${MAGENTA}${BOLD}║   ◈  akmod-wl Install (kmods-zodium)  ◈  ║${NC}"
say "${MAGENTA}${BOLD}║   Broadcom Wi-Fi kernel module           ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Config ────────────────────────────────────────────────────
KMODS_ZODIUM_REPO="zodium-project/kmods-zodium"
KMOD="wl"

# ── Temp dir with auto-cleanup ────────────────────────────────
WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

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

# ── Find the wl.zip asset URL ─────────────────────────────────
ASSET_URL="$(
  printf '%s' "${RELEASE_JSON}" \
  | python3 -c "
import json, sys
assets = json.load(sys.stdin).get('assets', [])
match = next((a['browser_download_url'] for a in assets if a['name'] == 'wl.zip'), None)
if not match:
    raise SystemExit('wl.zip not found in release assets')
print(match)
")" || fail "wl.zip not found in release ${RELEASE_TAG} — kmods-zodium may still be building"

ok "Found asset: ${ASSET_URL}"

# ── Download & extract ────────────────────────────────────────
ZIP_PATH="${WORKDIR}/wl.zip"
RPM_DIR="${WORKDIR}/rpms"
mkdir -p "${RPM_DIR}"

info "Downloading wl.zip..."
curl -fL --progress-bar "${ASSET_URL}" -o "${ZIP_PATH}"
ok "Download complete"

info "Extracting RPMs..."
unzip -q "${ZIP_PATH}" -d "${RPM_DIR}"

RPM_COUNT="$(find "${RPM_DIR}" -name '*.rpm' | wc -l)"
[[ "${RPM_COUNT}" -gt 0 ]] || fail "No RPMs found inside wl.zip"
ok "Extracted ${RPM_COUNT} RPM(s):"
find "${RPM_DIR}" -name '*.rpm' | while read -r rpm; do
  say "  ${CYAN}◈${NC}  $(basename "${rpm}")"
done

# ── Install RPMs ──────────────────────────────────────────────
info "Installing RPMs via dnf..."
dnf install -y --setopt=install_weak_deps=False "${RPM_DIR}"/*.rpm
ok "RPMs installed"

# ── Refresh module dependencies ───────────────────────────────
info "Refreshing module dependencies..."
depmod -a "${KERNEL_VERSION}"
ok "depmod complete"

# ── DNF Cleanup ───────────────────────────────────────────────
info "Running DNF cleanup..."
dnf clean all
ok "Cleanup complete"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  akmod-wl Install Complete           ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""