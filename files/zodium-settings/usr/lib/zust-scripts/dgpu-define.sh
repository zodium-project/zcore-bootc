#!/usr/bin/env bash
# ================================================================
#  dgpu-define — Create ~/.config/dgpu-run/defined
# ================================================================

set -euo pipefail
shopt -s nullglob

CONFIG_DIR="$HOME/.config/dgpu-run"
CONFIG_FILE="$CONFIG_DIR/defined"

mkdir -p "$CONFIG_DIR"

# ---------------------------
# Human-friendly GPU name (borrowed from dgpu-run)
# ---------------------------
pci_friendly_name() {
    local dev="$1" vid did dd label
    label=$(cat "$dev/label" 2>/dev/null)
    [[ -n "$label" ]] && { printf '%s' "$label"; return; }

    vid=$(cat "$dev/vendor" 2>/dev/null || echo "0x0000"); vid=${vid#0x}; vid=${vid^^}
    did=$(cat "$dev/device" 2>/dev/null || echo "0x0000"); did=${did#0x}; did=${did^^}
    dd=$((16#$did))

    case "$vid" in
    10DE) printf 'NVIDIA GPU';;
    1002) printf 'AMD GPU';;
    8086) printf 'Intel GPU';;
    *)    printf 'GPU [%s:%s]' "$vid" "$did";;
    esac
}

# ---------------------------
# Discover cards
# ---------------------------
declare -a cards=()
declare -A card_model card_drv

for card_path in /sys/class/drm/card*; do
    cname=$(basename "$card_path")
    [[ -e "$card_path/device" ]] || continue
    # skip connectors like card0-eDP-2
    [[ "$cname" =~ ^card[0-9]+$ ]] || continue

    cards+=("$cname")

    devpath=$(readlink -f "$card_path/device")
    card_model["$cname"]="$(pci_friendly_name "$devpath")"
    card_drv["$cname"]="$(basename "$(readlink -f "$devpath/driver" 2>/dev/null)" 2>/dev/null || echo "none")"
done

[[ ${#cards[@]} -gt 0 ]] || { echo "No DRM GPUs found"; exit 1; }

echo "Detected GPUs:"
for idx in "${!cards[@]}"; do
    c="${cards[$idx]}"
    echo "  [$((idx+1))] $c — ${card_model[$c]} (driver: ${card_drv[$c]})"
done

# ---------------------------
# Helper to select GPU
# ---------------------------
select_gpu() {
    local prompt="$1" choice idx
    while true; do
        read -rp "$prompt [1-${#cards[@]}]: " choice
        [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#cards[@]} )) && break
        echo "Invalid choice, try again."
    done
    idx=$((choice-1))
    echo "${cards[$idx]}"
}

echo ""
igpu=$(select_gpu "Select iGPU (weak GPU)")
dgpu=$(select_gpu "Select dGPU (powerful GPU)")

if [[ "$igpu" == "$dgpu" ]]; then
    echo "iGPU and dGPU cannot be the same. Exiting."
    exit 1
fi

# ---------------------------
# Write to file
# ---------------------------
cat > "$CONFIG_FILE" <<EOF
weak_gpu_igpu=$igpu
powerful_gpu_dgpu=$dgpu
EOF

echo ""
echo "Saved GPU mapping to $CONFIG_FILE"
echo "  iGPU: $igpu — ${card_model[$igpu]} (driver: ${card_drv[$igpu]})"
echo "  dGPU: $dgpu — ${card_model[$dgpu]} (driver: ${card_drv[$dgpu]})"