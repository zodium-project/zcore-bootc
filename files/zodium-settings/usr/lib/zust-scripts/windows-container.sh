#!/usr/bin/env bash
# ================================================================
#  winboat-setup — Installs the latest WinBoat AppImage for the user
#  Repo: https://github.com/TibixDev/winboat
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

# ── Variables ──────────────────────────────────────────
REPO="TibixDev/winboat"
API="https://api.github.com/repos/${REPO}/releases/latest"
APP_DIR="${HOME}/Applications"
DESKTOP_DIR="${HOME}/.local/share/applications"
BIN_NAME="winboat"

mkdir -p "${APP_DIR}"
mkdir -p "${DESKTOP_DIR}"

# ── Fetch latest release info ─────────────────────────
info "Fetching latest WinBoat release info..."
json=$(curl -sL "${API}") || fail "Failed to fetch release info."

# ── Parse asset download URL for AppImage ─────────────
DOWNLOAD_URL=$(echo "$json" \
    | grep '"browser_download_url":' \
    | grep -i "\.AppImage\"" \
    | head -n 1 \
    | sed -E 's/.*"([^"]+)".*/\1/') || true

if [[ -z "$DOWNLOAD_URL" ]]; then
    fail "Could not find AppImage download URL in release assets."
fi
ok "Found AppImage: ${DOWNLOAD_URL##*/}"

# ── Download AppImage ─────────────────────────────────
TARGET="${APP_DIR}/${BIN_NAME}.AppImage"
info "Downloading AppImage..."
curl -L -o "$TARGET" "$DOWNLOAD_URL" || fail "Download failed."
chmod +x "$TARGET"
ok "Downloaded and made executable: $TARGET"

# ── Create symlink in ~/Applications for easy access ──
ln -fs "$TARGET" "${APP_DIR}/${BIN_NAME}"
ok "Created launcher symlink: ${APP_DIR}/${BIN_NAME}"

# ── Add to PATH if missing ───────────────────────────
if ! grep -q "${APP_DIR}" <<< "$PATH"; then
    info "Adding ${APP_DIR} to PATH in ~/.bashrc"
    echo -e "\n# WinBoat installer\nexport PATH=\"\$PATH:${APP_DIR}\"" >> "${HOME}/.bashrc"
    ok "PATH updated (reload shell or run 'source ~/.bashrc')"
fi

# ── Create Desktop Shortcut ───────────────────────────
DESKTOP_FILE="${DESKTOP_DIR}/winboat.desktop"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=WinBoat
Comment=WinBoat AppImage Launcher
Exec=${APP_DIR}/${BIN_NAME}
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=Utility;
EOF

ok "Created desktop shortcut: ${DESKTOP_FILE}"

# ── Summary ─────────────────────────────────────────
echo ""
echo -e "${MAGENTA}${BOLD}╔════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}${BOLD}║            WinBoat Setup Completed         ║${NC}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Run '${BOLD}${BIN_NAME}${NC}' to launch WinBoat.${NC}"
echo ""