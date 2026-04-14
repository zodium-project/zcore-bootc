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
say "${MAGENTA}${BOLD}╔═════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║ ◈  akmod-wl Install (kmods-zodium)  ◈ ║${NC}"
say "${MAGENTA}${BOLD}║   Broadcom Wi-Fi kernel module          ║${NC}"
say "${MAGENTA}${BOLD}╚═════════════════════════════════════════╝${NC}"
say ""

# ── Detect running kernel ─────────────────────────────────────
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | tail -1)"
[[ -n "${KERNEL_VERSION}" ]] || fail "Could not detect kernel version"
info "Kernel: ${KERNEL_VERSION}"

# ── Install RPMs ──────────────────────────────────────────────
info "Installing RPMs via dnf..."
dnf install -y --setopt=install_weak_deps=False \
               broadcom-wl                      \
               kmod-wl-"${KERNEL_VERSION}"
ok "RPMs installed"

# ── DNF Cleanup ───────────────────────────────────────────────
info "Running DNF cleanup..."
dnf clean all
ok "Cleanup complete"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔═════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  akmod-wl Install Complete         ║${NC}"
say "${MAGENTA}${BOLD}╚═════════════════════════════════════════╝${NC}"
say ""