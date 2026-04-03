#!/usr/bin/env bash
# ================================================================
#  Remove unused TuneD profiles
#  Zodium Project : github.com/zodium-project
# ================================================================

# ── Exit immediately if a command exits with a non-zero status ── #
set -Eeuo pipefail

# ── Styling ───────────────────────────────────────────────────
GREEN='\033[0;32m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

say() { printf "$@"; printf '\n'; }
ok()  { say "${GREEN}◆${NC}  $*"; }

# ── Header ────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◈  Remove Unused Plymouth Themes       ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Remove Themes ─────────────────────────────────────────────
rm -rf /usr/share/plymouth/themes/charge
rm -rf /usr/share/plymouth/themes/details
rm -rf /usr/share/plymouth/themes/spinner
rm -rf /usr/share/plymouth/themes/text
rm -rf /usr/share/plymouth/themes/tribar


ok "Unused Plymouth Themes removed"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  Plymouth Cleanup Complete           ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""