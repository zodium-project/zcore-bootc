#!/usr/bin/env bash
set -euo pipefail

PLATFORM_PROFILE="/sys/firmware/acpi/platform_profile"
LOCKFILE="/run/tuned-sync.lock"

[ -f "$PLATFORM_PROFILE" ] || exit 0

# Prevent recursion / race
exec 9>"$LOCKFILE"
flock -n 9 || exit 0

CURRENT_PLATFORM=$(cat "$PLATFORM_PROFILE")
CURRENT_TUNED=$(tuned-adm active 2>/dev/null | awk '{print $NF}')

# Map firmware -> tuned
platform_to_tuned() {
    case "$1" in
        low-power) echo "zodium-powersave" ;;
        balanced) echo "zodium-balanced" ;;
        balanced-performance) echo "zodium-performance" ;;
        performance) echo "zodium-latency" ;;
        *) echo "" ;;
    esac
}

# Map tuned -> firmware
tuned_to_platform() {
    case "$1" in
        zodium-powersave) echo "low-power" ;;
        zodium-balanced) echo "balanced" ;;
        zodium-performance) echo "balanced-performance" ;;
        zodium-latency) echo "performance" ;;
        *) echo "" ;;
    esac
}

TARGET_TUNED=$(platform_to_tuned "$CURRENT_PLATFORM")
TARGET_PLATFORM=$(tuned_to_platform "$CURRENT_TUNED")

# If firmware changed and tuned is wrong → fix tuned
if [ -n "$TARGET_TUNED" ] && [ "$CURRENT_TUNED" != "$TARGET_TUNED" ]; then
    tuned-adm profile "$TARGET_TUNED"
    exit 0
fi

# If tuned changed and firmware is wrong → fix firmware
if [ -n "$TARGET_PLATFORM" ] && [ "$CURRENT_PLATFORM" != "$TARGET_PLATFORM" ]; then
    echo "$TARGET_PLATFORM" > "$PLATFORM_PROFILE"
    exit 0
fi

exit 0
