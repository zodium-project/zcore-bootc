#!/usr/bin/env bash
# ================================================================
#  Neovim-Setup — Installs Neovim and optional preconfigured setups
#  AstroNvim / LazyVim / Default
#  Made for Zodium Project
# ================================================================

set -Eeuo pipefail

# ── Dependency check ──────────────────────────────────────────
command -v brew &>/dev/null || { echo "⦻  Homebrew is required but not installed" >&2; exit 1; }
command -v git  &>/dev/null || { echo "⦻  git is required but not installed" >&2; exit 1; }

# ── Styling ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

say()  { printf "$@"; printf '\n'; }
info() { say "${CYAN}◈${NC}  $*"; }
ok()   { say "${GREEN}◆${NC}  $*"; }
warn() { say "${YELLOW}◇${NC}  $*"; }
fail() { say "${RED}⦻${NC}  $*" >&2; exit 1; }
skip() { say "  ${BOLD}↷${NC}  $* ${YELLOW}(skipped)${NC}"; }

# ── Header ────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔════════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◈  Zodium Neovim Setup  ◈                ║${NC}"
say "${MAGENTA}${BOLD}╚════════════════════════════════════════════╝${NC}"
say ""

# ── Install Neovim ────────────────────────────────────────────
if command -v nvim &>/dev/null; then
    skip "Neovim already installed ($(nvim --version | head -1))"
else
    info "Installing Neovim via Homebrew..."
    brew install neovim || fail "Neovim installation failed"
    ok "Neovim installed ($(nvim --version | head -1))"
fi
say ""

# ── Existing config warning ───────────────────────────────────
NVIM_DIRS=(~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim)
HAS_EXISTING=false
for d in "${NVIM_DIRS[@]}"; do
    [[ -d "$d" ]] && HAS_EXISTING=true && break
done

if $HAS_EXISTING; then
    warn "Existing Neovim config detected — selecting a setup will ${BOLD}remove it.${NC}"
    say ""
fi

# ── Choose setup ──────────────────────────────────────────────
say "  Select Neovim configuration:"
say ""
say "  ${BOLD}1)${NC} AstroNvim  — fully featured, batteries-included"
say "  ${BOLD}2)${NC} LazyVim    — modern, plugin-lazy-loaded"
say "  ${BOLD}3)${NC} Default    — clean slate, no preconfig"
say "  ${BOLD}4)${NC} Cancel     — quit installer"
say ""
read -rp "  Enter choice [1-4]: " CHOICE
say ""

# ── Wipe existing config ──────────────────────────────────────
wipe_config() {
    info "Removing existing Neovim config..."
    for d in "${NVIM_DIRS[@]}"; do
        [[ -d "$d" ]] && rm -rf "$d" && ok "Removed $d" || true
    done
}

# ── Install ───────────────────────────────────────────────────
case "$CHOICE" in
    1)
        SETUP="AstroNvim"
        wipe_config
        info "Cloning AstroNvim template..."
        git clone --depth 1 https://github.com/AstroNvim/template ~/.config/nvim \
            || fail "Failed to clone AstroNvim"
        rm -rf ~/.config/nvim/.git
        ok "AstroNvim installed"
        ;;
    2)
        SETUP="LazyVim"
        wipe_config
        info "Cloning LazyVim starter..."
        git clone https://github.com/LazyVim/starter ~/.config/nvim \
            || fail "Failed to clone LazyVim"
        rm -rf ~/.config/nvim/.git
        ok "LazyVim installed"
        ;;
    3)
        SETUP="Default"
        wipe_config
        ok "Using default Neovim configuration"
        ;;
    4)
        info "Cancelled. No changes made."
        exit 0
        ;;
    *)
        fail "Invalid choice."
        ;;
esac

# ── Summary ───────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔════════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  Neovim Setup Complete                 ║${NC}"
say "${MAGENTA}${BOLD}╚════════════════════════════════════════════╝${NC}"
say "  Setup : ${BOLD}$SETUP${NC}"
if [[ "$SETUP" == "Default" ]]; then
    say "  Run   : ${BOLD}nvim${NC} to get started"
else
    say "  Run   : ${BOLD}nvim${NC} to finish plugin installation"
fi
say ""