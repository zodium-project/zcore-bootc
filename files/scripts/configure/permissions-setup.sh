#!/usr/bin/env bash
# ================================================================
#  Set-Permissions — Make Zodium tools and scripts executable
#  Zodium Project : github.com/zodium-project
# ================================================================

# ── Exit immediately if a command exits with a non-zero status ── #
set -Eeuo pipefail

# ── Styling ───────────────────────────────────────────────────
GREEN='\033[0;32m'; CYAN='\033[0;36m'
MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

say()  { printf "%b\n" "$*"; }
info() { say "${CYAN}◈${NC}  $*"; }
ok()   { say "${GREEN}◆${NC}  $*"; }

# ── Header ────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◈  Set Permissions  ◈                  ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Make Tools Executable ─────────────────────────────────────
info "Setting tool permissions..."
chmod 0755 /usr/bin/zgpu
chmod 0755 /usr/bin/zrun
chmod 0755 /usr/bin/zync
ok "Tools set executable"

# ── Make Scripts Executable ───────────────────────────────────
info "Setting script permissions..."
chmod 0755 /usr/lib/zrun-scripts
ok "Scripts permissions processed"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  Permissions Set Complete            ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""