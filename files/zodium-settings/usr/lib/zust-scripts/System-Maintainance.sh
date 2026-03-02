#!/usr/bin/env bash
# ================================================================
#  System-Maintainance — Update & Clear Oprhans using zync
# ================================================================
set -Eeuo pipefail

/usr/bin/zync --brew --rpm-ostree --flatpak --no-reboot --maintain