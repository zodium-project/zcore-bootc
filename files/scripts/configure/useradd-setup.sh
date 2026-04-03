#!/usr/bin/env bash
# ================================================================
#  Useradd-Defaults — Configure default shell and groups for new users
#  Zodium Project : github.com/zodium-project
# ================================================================

# ── Exit immediately if a command exits with a non-zero status ── #
set -Eeuo pipefail

# ── Styling ───────────────────────────────────────────────────
GREEN='\033[0;32m'; CYAN='\033[0;36m'
MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

say()  { printf "$@"; printf '\n'; }
info() { say "${CYAN}◈${NC}  $*"; }
ok()   { say "${GREEN}◆${NC}  $*"; }

# ── Header ────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◈  Useradd Defaults  ◈                 ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

cd /etc/default

# ── Force default shell ───────────────────────────────────────
info "Setting default shell to zsh..."
sed -i 's|^SHELL=.*|SHELL=/usr/bin/zsh|' useradd
ok "Default shell set to /usr/bin/zsh"

# ── Ensure all new users are in gamemode group ────────────────
info "Setting default group to gamemode..."
if grep -q '^GROUPS=' useradd; then
    sed -i 's|^GROUPS=.*|GROUPS=gamemode|' useradd
else
    printf 'GROUPS=gamemode\n' >> useradd
fi
ok "Default group set to gamemode"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  Useradd Defaults Set Complete       ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""