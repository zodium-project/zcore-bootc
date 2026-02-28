#!/usr/bin/env bash
# ================================================================
#  WinBoat Installer — Install or upgrade WinBoat safely
#  Detects latest release, removes old installation, sets symlinks
#  Should work on any distro , needs Curl installed
#  By Zodium Project for use on zcore derivatives
# ================================================================

set -Eeuo pipefail

# ── Paths & Styling ─────────────────────────────────────────
APP_DIR="$HOME/Applications/WinBoat"
APPIMAGE="$APP_DIR/WinBoat.AppImage"
ICON="$APP_DIR/winboat_logo.svg"
DESKTOP_FILE="$APP_DIR/winboat.desktop"
LOCAL_DESKTOP="$HOME/.local/share/applications/winboat.desktop"
CLI_LAUNCHER="$HOME/Applications/winboat-launcher"
VERSION_FILE="$APP_DIR/.version"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

ICON_INFO="[i]"; ICON_OK="[✔]"; ICON_WARN="[⚠]"; ICON_ERR="[✖]"

info()  { echo -e "${CYAN}${ICON_INFO}${NC}  $*"; }
ok()    { echo -e "${GREEN}${ICON_OK}${NC}  $*"; }
warn()  { echo -e "${YELLOW}${ICON_WARN}${NC}  $*"; }
fail()  { echo -e "${RED}${ICON_ERR}${NC}  $*" >&2; exit 1; }

# ── Header ───────────────────────────────────────────
echo -e "${MAGENTA}${BOLD}╔════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}${BOLD}║        WinBoat Installer Script    ║${NC}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════╝${NC}"
echo ""

# ── Get latest release info from GitHub API ─────────────
info "Checking latest WinBoat release..."
API_JSON=$(curl -fsSL https://api.github.com/repos/TibixDev/winboat/releases/latest) \
    || fail "Failed to query GitHub API"

LATEST_VERSION=$(echo "$API_JSON" | grep -Po '"tag_name":\s*"\K[^"]+')
[[ -z "$LATEST_VERSION" ]] && fail "Could not detect latest version"

LATEST_URL=$(echo "$API_JSON" | grep -Po '"browser_download_url":\s*"\K[^"]+\.AppImage')
[[ -z "$LATEST_URL" ]] && fail "Could not detect AppImage download URL"

# ── Version check ───────────────────────────────────────
INSTALLED_VERSION=""
if [[ -f "$VERSION_FILE" ]]; then
    INSTALLED_VERSION=$(< "$VERSION_FILE")
fi

if [[ "$INSTALLED_VERSION" == "$LATEST_VERSION" ]]; then
    ok "WinBoat is already up-to-date ($INSTALLED_VERSION)."
else
    [[ -n "$INSTALLED_VERSION" ]] && info "Upgrading: v$INSTALLED_VERSION → v$LATEST_VERSION"

    # ── Cleanup old installation ──────────────────────
    info "Removing old installation..."
    rm -rf "$APP_DIR" "$CLI_LAUNCHER" "$LOCAL_DESKTOP"
    mkdir -p "$APP_DIR"

    # ── Download AppImage ───────────────────────────
    info "Downloading AppImage..."
    curl -L --progress-bar -o "$APPIMAGE" "$LATEST_URL"
    chmod +x "$APPIMAGE"
    ok "AppImage installed"

    # ── Download Icon ───────────────────────────────
    info "Downloading icon..."
    curl -fsSL -o "$ICON" https://raw.githubusercontent.com/TibixDev/winboat/main/icons/winboat_logo.svg \
        || warn "Failed to fetch icon; using terminal fallback"
    ok "Icon ready"

    # ── Create .desktop shortcut ───────────────────
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

    # ── CLI symlink ───────────────────────────────
    ln -sf "$APPIMAGE" "$CLI_LAUNCHER"
    ok "CLI launcher ready"

    echo "$LATEST_VERSION" > "$VERSION_FILE"
fi

# ── Final Clean Output ───────────────────────────────
echo ""
echo -e "${MAGENTA}${BOLD}╔════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}${BOLD}║        WinBoat Setup Completed     ║${NC}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════╝${NC}"
echo -e "  Installed Version  : ${BOLD}$LATEST_VERSION${NC}"
echo -e "  AppImage Path      : ${BOLD}~/Applications/WinBoat/WinBoat.AppImage${NC}"
echo -e "  Desktop Shortcut   : ${BOLD}~/.local/share/applications/winboat.desktop${NC}"
echo -e "  CLI Launcher       : ${BOLD}~/Applications/winboat-launcher${NC}\n"

echo -e "${MAGENTA}╭──────────────────────────────────────────╮${NC}"
echo -e "${MAGENTA}│  Run 'WinBoat.AppImage' to launch WinBoat│${NC}"
echo -e "${MAGENTA}╰──────────────────────────────────────────╯${NC}"