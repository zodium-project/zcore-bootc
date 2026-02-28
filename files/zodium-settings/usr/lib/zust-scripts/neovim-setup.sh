#!/usr/bin/env bash
# ================================================================
#  neovim-setup — Installs Neovim and optional preconfigured setups
#  AstroNvim / LazyVim / Default
#  Made for Zodium Project
# ================================================================

set -Eeuo pipefail

# ── Styling ───────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

ICON_INFO="🔹"; ICON_OK="✔"; ICON_WARN="⚠"; ICON_ERR="✖"

info()  { echo -e "${CYAN}${ICON_INFO}${NC}  $*"; }
ok()    { echo -e "${GREEN}${ICON_OK}${NC}  $*"; }
warn()  { echo -e "${YELLOW}${ICON_WARN}${NC}  $*"; }
fail()  { echo -e "${RED}${ICON_ERR}${NC}  $*" >&2; exit 1; }

# ── Header ───────────────────────────────────────────
echo -e "${MAGENTA}${BOLD}╔════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}${BOLD}║        Zodium Neovim Setup Script          ║${NC}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════╝${NC}"
echo ""

# ── Check Homebrew ─────────────────────────────────
if ! command -v brew &>/dev/null; then
    fail "Homebrew is not installed. Please install it first."
fi
ok "Homebrew found"

# ── Install Neovim ───────────────────────────────
info "Installing Neovim..."
brew install neovim &>/dev/null || warn "Neovim already installed or failed to install"
ok "Neovim installed successfully"

# ── Choose Setup ──────────────────────────────────
echo ""
info "Select Neovim configuration:"
echo -e "  ${BOLD}1) AstroNvim${NC} (preconfigured)"
echo -e "  ${BOLD}2) LazyVim${NC} (preconfigured)"
echo -e "  ${BOLD}3) Default Neovim${NC} (no preconfig)"
echo -ne "${YELLOW}Enter choice [1-3]: ${NC}"
read choice
echo ""

SETUP_NAME="Default"

# ── Install Choice ───────────────────────────────
case "$choice" in
    1)
        SETUP_NAME="AstroNvim"
        info "Installing AstroNvim..."
        rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
        git clone --depth 1 https://github.com/AstroNvim/template ~/.config/nvim &>/dev/null
        rm -rf ~/.config/nvim/.git
        ok "AstroNvim installed"
        ;;
    2)
        SETUP_NAME="LazyVim"
        info "Installing LazyVim..."
        rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
        git clone https://github.com/LazyVim/starter ~/.config/nvim &>/dev/null
        rm -rf ~/.config/nvim/.git
        ok "LazyVim installed"
        ;;
    3)
        ok "Using default Neovim configuration. No preconfig installed."
        ;;
    *)
        fail "Invalid choice. Exiting."
        ;;
esac

# ── Summary ───────────────────────────────────────
echo ""
echo -e "${MAGENTA}${BOLD}╔════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}${BOLD}║          Neovim Setup Completed            ║${NC}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Installed Setup :${NC} ${BOLD}${SETUP_NAME}${NC}"
echo -e "${CYAN}Next Steps      :${NC} Run 'nvim' to complete setup and install plugins."
echo ""
echo -e "${MAGENTA}╭──────────────────────────────────────────╮${NC}"
echo -e "${MAGENTA}│        Happy Coding with Neovim!         │${NC}"
echo -e "${MAGENTA}╰──────────────────────────────────────────╯${NC}"

# to-do :
# 1. add nvchad etc.....
# 2. make default reset configs ?
# 3. change colors ?
# 4. use more unicode then ascii ?
# 5. add alternate ways to install neovim if brew is not shipped ?