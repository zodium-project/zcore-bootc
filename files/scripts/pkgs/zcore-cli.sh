#!/usr/bin/env bash
# ================================================================
#  CLI Tools — modern shell utilities for zcore
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
say "${MAGENTA}${BOLD}║   ◈  CLI Tools Installer  ◈            ║${NC}"
say "${MAGENTA}${BOLD}║   modern shell utilities                 ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Install CLI packages ───────────────────────────────────────
info "Installing CLI tools..."
dnf -y install --setopt=install_weak_deps=False \
    fd-find \
    bat \
    ripgrep \
    trash-cli \
    starship \
    zoxide \
    btop \
    neovim \
    code \
    eza \
    zync \
    zfetch \
    zrun \
    zgpu
ok "CLI tools installed"

# ── Cleanup ───────────────────────────────────────────────────
info "Removing extra desktop files..."
rm -rf /usr/share/applications/btop.desktop
rm -rf /usr/share/applications/nvim.desktop
ok "Extra desktop files have been removed"
info "Removing extra Btop themes..."
rm -rf /usr/share/btop/themes/HotPurpleTrafficLight.theme
rm -rf /usr/share/btop/themes/adapta.theme
rm -rf /usr/share/btop/themes/dusklight.theme
rm -rf /usr/share/btop/themes/elementarish.theme
rm -rf /usr/share/btop/themes/gotham.theme
rm -rf /usr/share/btop/themes/everforest-dark-medium.theme
rm -rf /usr/share/btop/themes/gruvbox_dark_v2.theme
rm -rf /usr/share/btop/themes/kanagawa-lotus.theme
rm -rf /usr/share/btop/themes/monokai.theme
rm -rf /usr/share/btop/themes/night-owl.theme
rm -rf /usr/share/btop/themes/paper.theme
rm -rf /usr/share/btop/themes/solarized_dark.theme
rm -rf /usr/share/btop/themes/solarized_light.theme
rm -rf /usr/share/btop/themes/phoenix-night.theme
rm -rf /usr/share/btop/themes/tokyo-storm.theme
rm -rf /usr/share/btop/themes/whiteout.theme
rm -rf /usr/share/btop/themes/flat-remix-light.theme
ok "Extra Btop themes have been removed"

info "Running DNF cleanup..."
dnf clean all
ok "Cleanup complete"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  CLI Tools Install Complete         ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""
