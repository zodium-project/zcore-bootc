#!/usr/bin/env bash
# ================================================================
#  Zodium Packages — zodium-settings · fedora-logos
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
say "${MAGENTA}${BOLD}║   ◈  Zodium Packages                     ║${NC}"
say "${MAGENTA}${BOLD}║   zodium-settings · fedora-logos          ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Config ────────────────────────────────────────────────────
GITHUB_USER="zodium-project"
REPO="pkgs-zodium"
RELEASE_TAG="pkgs-rpm"
WORK_DIR=$(mktemp -d /tmp/zodium-pkgs.XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT

# ── Dependency check ──────────────────────────────────────────
for dep in curl jq dnf sudo; do
    command -v "$dep" >/dev/null 2>&1 || fail "'$dep' is required but not found"
done

# ── Root check ────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    info "Checking sudo access..."
    sudo -v || fail "sudo access required"
fi

# ── Fetch release asset URLs ──────────────────────────────────
say ""
info "Fetching release assets from ${BOLD}${GITHUB_USER}/${REPO}${NC}..."

ASSETS=$(curl -fsSL \
    "https://api.github.com/repos/${GITHUB_USER}/${REPO}/releases/tags/${RELEASE_TAG}" \
    | jq -r '.assets[] | .browser_download_url') \
    || fail "Could not fetch release assets"

[[ -z "$ASSETS" ]] && fail "No assets found in release ${RELEASE_TAG}"

ok "Release assets fetched"
say ""

# ── Helper: find asset URL by package name ────────────────────
get_url() {
    echo "$ASSETS" | grep "$1" | head -1
}

# ── Download ──────────────────────────────────────────────────
for pkg in zodium-settings fedora-logos; do
    info "Downloading ${BOLD}${pkg}${NC}..."
    url=$(get_url "${pkg}-")
    [[ -z "$url" ]] && fail "Could not find RPM for ${pkg} in release"
    curl -fsSL "$url" -o "${WORK_DIR}/${pkg}.rpm" \
        || fail "Download failed for ${pkg}"
    ok "${pkg} downloaded"
done
say ""

# ── Install zodium-settings ───────────────────────────────────
info "Installing ${BOLD}zodium-settings${NC}..."
sudo dnf install -y "${WORK_DIR}/zodium-settings.rpm" \
    || fail "Failed to install zodium-settings"
ok "zodium-settings installed"
say ""

# ── Swap fedora-logos ─────────────────────────────────────────
info "Swapping ${BOLD}fedora-logos${NC}..."
sudo dnf swap -y fedora-logos "${WORK_DIR}/fedora-logos.rpm" \
    || fail "Failed to swap fedora-logos"
ok "fedora-logos swapped"
say ""

# ── Done ──────────────────────────────────────────────────────
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  Zodium Packages Install Complete    ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""