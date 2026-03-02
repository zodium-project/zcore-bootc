#!/usr/bin/env bash
# ================================================================
#  WinBoat Installer — Install or upgrade WinBoat safely
#  Detects latest release, removes old installation, sets symlinks
#  Should work on any distro, needs curl installed
#  By Zodium Project for use on zcore derivatives
# ================================================================

set -Eeuo pipefail

# ── Dependency check ──────────────────────────────────────────
command -v curl &>/dev/null || { echo "⦻  curl is required but not installed" >&2; exit 1; }

# ── Paths ─────────────────────────────────────────────────────
APP_DIR="$HOME/Applications/WinBoat"
APPIMAGE="$APP_DIR/WinBoat.AppImage"
ICON="$APP_DIR/winboat_logo.svg"
DESKTOP_FILE="$APP_DIR/winboat.desktop"
LOCAL_DESKTOP="$HOME/.local/share/applications/winboat.desktop"
CLI_LAUNCHER="$HOME/.local/bin/winboat"
VERSION_FILE="$APP_DIR/.version"

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
say "${MAGENTA}${BOLD}╔════════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◈  WinBoat Installer  ◈                  ║${NC}"
say "${MAGENTA}${BOLD}╚════════════════════════════════════════════╝${NC}"
say ""

# ── Get latest release info from GitHub API ───────────────────
info "Checking latest WinBoat release..."
API_JSON=$(curl -fsSL https://api.github.com/repos/TibixDev/winboat/releases/latest) \
    || fail "Failed to query GitHub API"

if command -v jq &>/dev/null; then
    LATEST_VERSION=$(echo "$API_JSON" | jq -r '.tag_name')
    LATEST_URL=$(echo "$API_JSON" | jq -r '.assets[] | select(.name | endswith(".AppImage")) | .browser_download_url')
else
    LATEST_VERSION=$(echo "$API_JSON" | grep -Po '"tag_name":\s*"\K[^"]+')
    LATEST_URL=$(echo "$API_JSON" | grep -Po '"browser_download_url":\s*"\K[^"]+\.AppImage')
fi

[[ -z "$LATEST_VERSION" ]] && fail "Could not detect latest version"
[[ -z "$LATEST_URL" ]]     && fail "Could not detect AppImage download URL"

# ── Version check ─────────────────────────────────────────────
INSTALLED_VERSION=""
[[ -f "$VERSION_FILE" ]] && INSTALLED_VERSION=$(< "$VERSION_FILE")

if [[ "$INSTALLED_VERSION" == "$LATEST_VERSION" ]]; then
    ok "WinBoat is already up-to-date ($INSTALLED_VERSION)."
else
    [[ -n "$INSTALLED_VERSION" ]] && info "Upgrading: $INSTALLED_VERSION → $LATEST_VERSION"

    # ── Cleanup old installation ──────────────────────────────
    info "Removing old installation..."
    [[ -n "$APP_DIR" && "$APP_DIR" == "$HOME/Applications/WinBoat" ]] \
        || fail "Unexpected APP_DIR value, aborting cleanup"
    rm -rf "$APP_DIR" "$CLI_LAUNCHER" "$LOCAL_DESKTOP"
    mkdir -p "$APP_DIR"

    # ── Download AppImage ─────────────────────────────────────
    info "Downloading AppImage..."
    curl -L --progress-bar -o "$APPIMAGE" "$LATEST_URL" \
        || fail "Failed to download AppImage"
    chmod +x "$APPIMAGE"
    ok "AppImage installed"

    # ── Download Icon ─────────────────────────────────────────
    info "Downloading icon..."
    curl -fsSL -o "$ICON" https://raw.githubusercontent.com/TibixDev/winboat/main/icons/winboat_logo.svg \
        || warn "Failed to fetch icon — desktop entry will have no icon"
    ok "Icon ready"

    # ── Create .desktop shortcut ──────────────────────────────
    mkdir -p "$(dirname "$LOCAL_DESKTOP")"
    cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=WinBoat
Comment=WinBoat Windows container
Exec=$APPIMAGE
Icon=$ICON
Terminal=false
Type=Application
Categories=Utility;
EOF
    chmod +x "$DESKTOP_FILE"
    ln -sf "$DESKTOP_FILE" "$LOCAL_DESKTOP"
    ok ".desktop shortcut ready"

    # ── CLI symlink ───────────────────────────────────────────
    mkdir -p "$HOME/.local/bin"
    ln -sf "$APPIMAGE" "$CLI_LAUNCHER"
    [[ ":$PATH:" != *":$HOME/.local/bin:"* ]] \
        && warn "~/.local/bin is not in your PATH — add it to use 'winboat' from terminal"
    ok "CLI launcher ready"

    echo "$LATEST_VERSION" > "$VERSION_FILE"
fi

# ── Summary ───────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔════════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  WinBoat Setup Completed               ║${NC}"
say "${MAGENTA}${BOLD}╚════════════════════════════════════════════╝${NC}"
say "  Version  : ${BOLD}$LATEST_VERSION${NC}"
say "  AppImage : ${BOLD}~/Applications/WinBoat/WinBoat.AppImage${NC}"
say "  Desktop  : ${BOLD}~/.local/share/applications/winboat.desktop${NC}"
say "  CLI      : ${BOLD}~/.local/bin/winboat${NC}"
say ""
say "  ${CYAN}◈${NC}  Run ${BOLD}WinBoat.AppImage${NC} to launch WinBoat"
say "  ${CYAN}◈${NC}  Only Podman mode is supported"
say ""