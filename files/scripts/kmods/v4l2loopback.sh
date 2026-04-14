#!/usr/bin/env bash
# ================================================================
#  v4l2loopback — Virtual camera support for zcore
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
say "${MAGENTA}${BOLD}║   ◈  v4l2loopback Installer  ◈         ║${NC}"
say "${MAGENTA}${BOLD}║   virtual camera support for zcore       ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Detect running kernel ─────────────────────────────────────
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | tail -1)"
[[ -n "${KERNEL_VERSION}" ]] || fail "Could not detect kernel version"
info "Kernel: ${KERNEL_VERSION}"

# ── Install RPMs ──────────────────────────────────────────────
info "Installing RPMs via dnf..."
dnf install -y --setopt=install_weak_deps=False \
               v4l2loopback                     \
               v4l2loopback-akmod-modules       \
               kmod-v4l2loopback-"${KERNEL_VERSION}"
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
say "${MAGENTA}${BOLD}║   ◆  v4l2loopback Install Complete      ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""