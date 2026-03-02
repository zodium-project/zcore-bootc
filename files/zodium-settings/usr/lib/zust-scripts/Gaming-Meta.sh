#!/usr/bin/env bash
# ================================================================
#  Gaming-Meta — Flatpak Gaming Meta Installer
# ================================================================
set -Eeuo pipefail

command -v flatpak &>/dev/null || { echo "⦻  flatpak is required" >&2; exit 1; }

# ── Styling ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

say()  { printf "$@"; printf '\n'; }
info() { say "${CYAN}◈${NC}  $*"; }
ok()   { say "${GREEN}◆${NC}  $*"; }
warn() { say "${YELLOW}◇${NC}  $*"; }
fail() { say "${RED}⦻${NC}  $*" >&2; exit 1; }
skip() { say "  ${BOLD}↷${NC}  $* ${YELLOW}(already installed)${NC}"; }

# ── Header ────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◈  Gaming Meta Installer  ◈            ║${NC}"
say "${MAGENTA}${BOLD}║      Flatpak gaming apps setup           ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Flathub remote ────────────────────────────────────────────
if ! flatpak remote-list | grep -q flathub; then
    info "Adding Flathub remote..."
    flatpak remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo \
        && ok "Flathub remote added" \
        || fail "Failed to add Flathub remote"
else
    skip "Flathub remote"
fi
say ""

# ── Apps ──────────────────────────────────────────────────────
declare -A APPS=(
    ["Steam"]="com.valvesoftware.Steam"
    ["Heroic Games Launcher"]="com.heroicgameslauncher.hgl"
    ["Lutris"]="net.lutris.Lutris"
    ["ProtonPlus"]="com.vysp3r.ProtonPlus"
    ["MangoJuice"]="io.github.radiolamp.mangojuice"
)

FAILED=()

info "Installing gaming applications..."
say ""

for NAME in "${!APPS[@]}"; do
    ID="${APPS[$NAME]}"
    if flatpak info "$ID" &>/dev/null; then
        skip "$NAME ($ID)"
    else
        info "Installing $NAME..."
        if flatpak install -y flathub "$ID" &>/dev/null; then
            ok "$NAME installed"
        else
            warn "$NAME failed — $ID"
            FAILED+=("$NAME")
        fi
    fi
done

# ── Summary ───────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  Gaming Meta Setup Complete          ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"

if (( ${#FAILED[@]} > 0 )); then
    say ""
    warn "The following apps failed to install:"
    for f in "${FAILED[@]}"; do
        say "  ${RED}◇${NC}  $f"
    done
fi
say ""