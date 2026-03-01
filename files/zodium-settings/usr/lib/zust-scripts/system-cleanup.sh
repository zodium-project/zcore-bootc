#!/usr/bin/env bash
# ================================================================
#  zync-auto-updates — Manage automatic updates for zync
# ================================================================
set -euo pipefail

/usr/bin/zync --brew --rpm-ostree --flatpak --maintain