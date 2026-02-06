#!/usr/bin/env bash
set -euo pipefail
set -x

flatpak remotes
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak remote-modify --no-filter --enable flathub
flatpak remotes