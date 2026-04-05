#!/usr/bin/env bash
# ================================================================
#  CLI Tools — modern shell utilities for zcore
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
say "${MAGENTA}${BOLD}║   ◈  CLI Tools Installer  ◈              ║${NC}"
say "${MAGENTA}${BOLD}║   modern shell utilities                 ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Add COPR repo ─────────────────────────────────────────────
info "Enabling atim/starship COPR..."
dnf -y copr enable atim/starship
ok "COPR repo enabled"

# ── Install CLI packages ───────────────────────────────────────
info "Installing CLI tools..."
dnf -y install --setopt=install_weak_deps=False \
    fd-find \
    bat \
    ripgrep \
    trash-cli \
    starship \
    zoxide \
    btop \
    neovim
ok "CLI tools installed"

# ── Install eza from Terra (no repo registration) ─────────────
info "Resolving eza RPM from Terra..."
FEDORA_VER="$(rpm -E %fedora)"
TERRA_REPO="https://repos.fyralabs.com/terra${FEDORA_VER}"

EZA_URL="$(
    dnf -q repoquery eza \
        --repofrompath="terra,${TERRA_REPO}" \
        --repo=terra \
        --latest-limit=1 \
        --qf '%{location}\n' \
        2>/dev/null | grep "$(uname -m)"
)"
[[ -z "${EZA_URL}" ]] && fail "Could not resolve eza RPM from Terra (fc${FEDORA_VER}/$(uname -m))"
ok "Found: ${EZA_URL}"

info "Installing eza..."
dnf -y install --setopt=install_weak_deps=False \
    --repofrompath="terra,${TERRA_REPO}" \
    --repo=terra \
    "${EZA_URL}"
ok "eza installed → $(eza --version)"

# ── Install VS Code from Microsoft (no repo registration) ─────
info "Detecting system architecture..."
ARCH="$(uname -m)"
[[ "${ARCH}" != "x86_64" && "${ARCH}" != "aarch64" ]] && \
    fail "Unsupported architecture: ${ARCH} (expected x86_64 or aarch64)"
ok "Architecture: ${ARCH}"

info "Resolving VS Code RPM from Microsoft..."
VSCODE_REPO="https://packages.microsoft.com/yumrepos/vscode"

VSCODE_URL="$(
    dnf -q repoquery code \
        --repofrompath="vscode,${VSCODE_REPO}" \
        --repo=vscode \
        --latest-limit=1 \
        --qf '%{location}\n' \
        2>/dev/null | grep "${ARCH}"
)"
[[ -z "${VSCODE_URL}" ]] && fail "Could not resolve VS Code RPM for ${ARCH}"

VSCODE_VERSION="$(basename "${VSCODE_URL}" | grep -oP '(?<=code-)\S+(?=\.rpm)')"
ok "Found: ${VSCODE_VERSION} → ${ARCH}"

info "Installin VS code deps..."
dnf -y install --setopt=install_weak_deps=False \
    xdg-utils

info "Installing VS Code..."
dnf -y install --setopt=install_weak_deps=False \
    --repofrompath="vscode,${VSCODE_REPO}" \
    --repo=vscode \
    "${VSCODE_URL}"
ok "VS Code installed → ${VSCODE_VERSION}"

# ── Cleanup ───────────────────────────────────────────────────
info "Disabling COPR repo..."
dnf -y copr disable atim/starship
rm -rf /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:atim:starship.repo
ok "COPR repo disabled"
info "Removing extra desktop files..."
rm -rf /usr/share/applications/btop.desktop
rm -rf /usr/share/applications/nvim.desktop
ok "Extra desktop files have been removed"
info "Removing extra Btop themes..."
rm -rf /usr/share/btop/themes/HotPurpleTrafficLight.theme
rm -rf /usr/share/btop/themes/adapta.theme
rm -rf /usr/share/btop/themes/dusklight.theme
rm -rf /usr/share/btop/themes/elementarish.theme
rm -rf /usr/share/btop/themes/gotham.theme
rm -rf /usr/share/btop/themes/everforest-dark-medium.theme
rm -rf /usr/share/btop/themes/gruvbox_dark_v2.theme
rm -rf /usr/share/btop/themes/kanagawa-lotus.theme
rm -rf /usr/share/btop/themes/monokai.theme
rm -rf /usr/share/btop/themes/night-owl.theme
rm -rf /usr/share/btop/themes/paper.theme
rm -rf /usr/share/btop/themes/solarized_dark.theme
rm -rf /usr/share/btop/themes/solarized_light.theme
rm -rf /usr/share/btop/themes/phoenix-night.theme
rm -rf /usr/share/btop/themes/tokyo-storm.theme
rm -rf /usr/share/btop/themes/whiteout.theme
rm -rf /usr/share/btop/themes/flat-remix-light.theme
ok "Extra Btop themes have been removed"

info "Running DNF cleanup..."
dnf clean all
ok "Cleanup complete"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  CLI Tools Install Complete          ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""
