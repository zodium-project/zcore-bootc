#!/usr/bin/env bash
set -euo pipefail

GROUP="gamemode"

# Exit quietly if group does not exist
if ! getent group "$GROUP" >/dev/null; then
    exit 0
fi

# Add all desktop users to the group
awk -F: '
  $3 >= 1000 &&
  $1 != "nobody" &&
  $7 !~ /(nologin|false)$/ {
    print $1
  }
' /etc/passwd | while read -r user; do
    /usr/sbin/usermod -aG "$GROUP" "$user"
done
