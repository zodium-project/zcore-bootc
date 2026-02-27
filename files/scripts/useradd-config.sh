#!/usr/bin/env bash
set -Eeuo pipefail

cd /etc/default

# ──── Force default shell ──── #
sed -i 's|^SHELL=.*|SHELL=/usr/bin/zsh|' useradd

# ──── Ensure all new users are in gamemode group ──── #
if grep -q '^GROUPS=' useradd; then
    sed -i 's|^GROUPS=.*|GROUPS=gamemode|' useradd
else
    echo 'GROUPS=gamemode' >> useradd
fi