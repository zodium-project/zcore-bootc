#!/usr/bin/env bash
set -euo pipefail
set -x

chmod 0755 /usr/libexec/zodium-intel-hwp-dynamic-boost-start.sh
chmod 0755 /usr/libexec/zodium-intel-hwp-dynamic-boost-stop.sh
chmod 0755 /usr/libexec/zodium-set-gamemode.sh
chmod 0755 /usr/bin/zupdate
chmod 0755 /usr/bin/prime-run-experimental
chmod 0755 /usr/bin/dgpu-run-experimental
chmod 0755 /usr/libexec/zodium-tuned-sync.sh