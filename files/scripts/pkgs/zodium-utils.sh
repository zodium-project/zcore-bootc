#!/usr/bin/env bash
# ================================================================
#  Zodium Binaries — zrun · zync · zgpu
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
say "${MAGENTA}${BOLD}║   ◈  Zodium Installer  ◈                 ║${NC}"
say "${MAGENTA}${BOLD}║   zrun · zync · zgpu                     ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""
# ── Config ────────────────────────────────────────────────────
GITHUB_USER="zodium-project"
REPOS="zrun-rs zync-rs zgpu-rs"
BIN_DIR="/usr/bin"
WORK_DIR=$(mktemp -d /tmp/zodium-install.XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT
# ── Dependency check ──────────────────────────────────────────
for dep in curl jq; do
    command -v "$dep" >/dev/null 2>&1 || fail "'$dep' is required but not found"
done
# ── Arch detection ────────────────────────────────────────────
info "Detecting architecture..."
case "$(uname -m)" in
    x86_64)          ARCH="x86_64"  ;;
    aarch64|armv8*)  ARCH="aarch64" ;;
    *) fail "Unsupported architecture: $(uname -m)" ;;
esac
ok "Architecture: ${ARCH}"
# ── Install binaries ──────────────────────────────────────────
say ""
for repo in $REPOS; do
    bin="${repo%-rs}"

    info "Fetching latest stable release for ${BOLD}${bin}${NC}..."
    tag=$(curl -fsSL "https://api.github.com/repos/${GITHUB_USER}/${repo}/releases/latest" \
        | jq -r '.tag_name') \
        || fail "Could not fetch latest release for ${repo}"
    [[ -z "$tag" ]] && fail "Empty tag returned for ${repo}"

    version="${tag#v}"
    url="https://github.com/${GITHUB_USER}/${repo}/releases/download/${tag}/${bin}-${version}-musl-${ARCH}"
    tmp_file="${WORK_DIR}/${bin}"
    dest="${BIN_DIR}/${bin}"

    info "Downloading ${bin} ${tag}..."
    curl -fsSL "$url" -o "$tmp_file" || fail "Download failed for ${bin} — ${url}"
    chmod +x "$tmp_file"
    mv "$tmp_file" "$dest"

    ok "${bin} installed → ${dest}"
    say ""
done
# ── Done ──────────────────────────────────────────────────────
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  Zodium Install Complete             ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""