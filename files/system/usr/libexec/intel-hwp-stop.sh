#!/usr/bin/env bash
set -e

HWP="/sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost"

if [[ -w "$HWP" ]]; then
    echo 0 > "$HWP"
fi
