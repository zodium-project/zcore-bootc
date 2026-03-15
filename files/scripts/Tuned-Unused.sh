#!/usr/bin/env bash
# ================================================================
#  Remove unused TuneD profiles
#  Zodium Project : github.com/zodium-project
# ================================================================

set -Eeuo pipefail

# ── Styling ───────────────────────────────────────────────────
GREEN='\033[0;32m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

say() { printf "$@"; printf '\n'; }
ok()  { say "${GREEN}◆${NC}  $*"; }

# ── Header ────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◈  Remove Unused TuneD Profiles        ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Remove profiles ───────────────────────────────────────────
rm -rf /usr/lib/tuned/profiles/accelerator-performance/
rm -rf /usr/lib/tuned/profiles/hpc-compute/
rm -rf /usr/lib/tuned/profiles/latency-performance/
rm -rf /usr/lib/tuned/profiles/powersave/
rm -rf /usr/lib/tuned/profiles/throughput-performance/
rm -rf /usr/lib/tuned/profiles/virtual-guest/
rm -rf /usr/lib/tuned/profiles/virtual-host/
rm -rf /usr/lib/tuned/profiles/desktop/
rm -rf /usr/lib/tuned/profiles/optimize-serial-console/
rm -rf /usr/lib/tuned/profiles/network-latency/
rm -rf /usr/lib/tuned/profiles/network-throughput/
rm -rf /usr/lib/tuned/profiles/intel-sst/
rm -rf /usr/lib/tuned/profiles/aws/
rm -rf /usr/lib/tuned/profiles/balanced/
rm -rf /usr/lib/tuned/profiles/balanced-battery/

ok "Unused TuneD profiles removed"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  TuneD Cleanup Complete              ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""