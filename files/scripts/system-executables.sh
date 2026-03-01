#!/usr/bin/env bash
set -Eeuo pipefail

# Make Tools Executable

chmod 0755 /usr/bin/gpu-run
chmod 0755 /usr/bin/zust
chmod 0755 /usr/bin/zync

# Make Scripts Executable

chmod 0755 /usr/libexec/zodium-tuned-sync.sh
chmod 0755 /usr/libexec/zodium-useradd-gamemode.sh
chmod 0755 /usr/lib/zust-scripts/*