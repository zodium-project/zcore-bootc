#!/usr/bin/env bash
set -Eeuo pipefail

# ── Install Microsoft GPG key ───────────────────────────────── #

sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

# ── Add Visual Studio Code repository ───────────────────────── #

sudo tee /etc/yum.repos.d/vscode.repo > /dev/null << 'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF