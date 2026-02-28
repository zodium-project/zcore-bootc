#!/usr/bin/env bash
# ================================================================
#  gaming-meta — Flatpak Gaming Meta Installer
# ================================================================

set -Eeuo pipefail

# ── Colors ───────────────────────────────────────────────────── #

if [[ -t 1 ]] && tput colors &>/dev/null && [[ $(tput colors) -ge 8 ]]; then
    RED="\033[31m";    GREEN="\033[32m";  YELLOW="\033[33m"
    CYAN="\033[36m";   BOLD="\033[1m";   RESET="\033[0m"
else
    RED="" GREEN="" YELLOW="" CYAN="" BOLD="" RESET=""
fi

# ── Helpers ─────────────────────────────────────────────────── #

die()  { printf "%b[!] ERROR%b %s\n" "${RED}" "${RESET}" "$1" >&2; exit 1; }
info() { printf "%b[*]%b  %s\n" "${CYAN}" "${RESET}" "$1"; }
ok()   { printf "%b[+]%b  %s\n" "${GREEN}" "${RESET}" "$1"; }
warn() { printf "%b[!]%b  %s\n" "${YELLOW}" "${RESET}" "$1"; }

# ── Header ─────────────────────────────────────────────────── #

printf "%b%s Gaming Meta (Flatpak) %s%b\n" "${CYAN}${BOLD}" "[*]" "[*]" "${RESET}"
echo

# ── Flathub Setup ──────────────────────────────────────────── #

if ! flatpak remote-list | grep -q flathub; then
    info "Adding Flathub remote..."
    flatpak remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
    ok "Flathub added."
fi

# ── Install Gaming Applications ───────────────────────────── #

info "Installing gaming applications..."

flatpak install -y flathub \
    com.valvesoftware.Steam \
    com.heroicgameslauncher.hgl \
    net.lutris.Lutris \
    com.vysp3r.ProtonPlus \
    org.freedesktop.Platform.VulkanLayer.MangoHud \
    || warn "Some installs may have failed."

# ── Done ───────────────────────────────────────────────────── #

echo
ok "Gaming meta setup finished."