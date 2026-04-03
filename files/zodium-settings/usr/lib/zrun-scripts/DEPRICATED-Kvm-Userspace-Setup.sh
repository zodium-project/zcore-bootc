#!/usr/bin/env bash
# ================================================================
#  KVM Userspace Setup — kargs + flatpaks
#  on Fedora Silverblue/Kinoite/bootc (rpm-ostree only)
# ================================================================
set -Eeuo pipefail

command -v rpm-ostree &>/dev/null || { printf '%s\n' "⦻  rpm-ostree is required" >&2; exit 1; }
command -v flatpak    &>/dev/null || { printf '%s\n' "⦻  flatpak is required"    >&2; exit 1; }

# ── Styling ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'
DIM='\033[2m'; BLUE='\033[0;34m'

say()  { printf '%b\n' "$*"; }
ok()   { say "${GREEN}◆${NC}  $*"; }
warn() { say "${YELLOW}◇${NC}  $*"; }
fail() { say "${RED}⦻${NC}  $*" >&2; exit 1; }
step() { say "${BLUE}›${NC}  $*"; }
info() { say "${CYAN}◈${NC}  $*"; }

# ── Helpers ───────────────────────────────────────────────────
karg_exists() {
    grep -qw "$1" /proc/cmdline
}

has_flathub() {
    flatpak --user   remote-list --columns=name 2>/dev/null | grep -qx 'flathub' && return 0
    flatpak --system remote-list --columns=name 2>/dev/null | grep -qx 'flathub' && return 0
    return 1
}

ensure_flathub() {
    has_flathub && return
    step "Adding Flathub (--user)..."
    flatpak --user remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo \
        && ok "Flathub added" \
        || fail "Failed to add Flathub"
}

flatpak_installed() {
    flatpak --user   info "$1" &>/dev/null && return 0
    flatpak --system info "$1" &>/dev/null && return 0
    return 1
}

confirm() {
    printf '%b [y/N]: ' "$1"
    read -r _ans
    [[ "$_ans" =~ ^[Yy]([Ee][Ss])?$ ]]
}

menu() {
    local i=1 max=$#
    for opt in "$@"; do
        say "  ${DIM}$i)${NC}  ${CYAN}$opt${NC}"
        (( i++ )) || true
    done
    while :; do
        printf '\n  %b' "${DIM}choose:${NC} "
        read -r PICK
        say ""
        [[ "$PICK" =~ ^[1-9][0-9]*$ ]] && (( PICK >= 1 && PICK <= max )) && break || true
        warn "Invalid choice — enter a number between 1 and $max"
    done
}

# ── CPU + karg definitions ────────────────────────────────────
detect_cpu() {
    local vendor
    vendor="$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}')"
    case "$vendor" in
        GenuineIntel) echo "intel" ;;
        AuthenticAMD) echo "amd"   ;;
        *)            echo "unknown" ;;
    esac
}

CPU="$(detect_cpu)"
case "$CPU" in
    intel)   IOMMU_KARG="intel_iommu=on" ;;
    amd)     IOMMU_KARG="amd_iommu=on"   ;;
    unknown) fail "Could not detect CPU vendor — set kargs manually" ;;
esac

KARG_ORDER=("$IOMMU_KARG" "iommu=pt" "rd.driver.pre=vfio-pci")

declare -A KARG_DESC
KARG_DESC["$IOMMU_KARG"]="Enable IOMMU — required for PCIe/GPU passthrough"
KARG_DESC["iommu=pt"]="Passthrough mode — improves host performance"
KARG_DESC["rd.driver.pre=vfio-pci"]="Early vfio-pci load — required for GPU passthrough"

declare -A KARG_DETAIL
KARG_DETAIL["$IOMMU_KARG"]="Without this, VFIO cannot isolate devices from the host."
KARG_DETAIL["iommu=pt"]="Devices not being passed through bypass IOMMU translation."
KARG_DETAIL["rd.driver.pre=vfio-pci"]="Loads vfio-pci before nvidia/amdgpu/i915 can claim the device."

# ── Flatpak definitions ───────────────────────────────────────
FLATPAK_IDS=(
    "org.virt_manager.virt-manager"
    "org.gnome.Boxes"
)

declare -A FLATPAK_NAME
FLATPAK_NAME["org.virt_manager.virt-manager"]="Virt Manager"
FLATPAK_NAME["org.gnome.Boxes"]="GNOME Boxes"

declare -A FLATPAK_DESC
FLATPAK_DESC["org.virt_manager.virt-manager"]="Full-featured KVM/QEMU GUI — best for passthrough, networking, storage"
FLATPAK_DESC["org.gnome.Boxes"]="Simple GNOME VM manager — easier but less control"

# ── Detect state ──────────────────────────────────────────────
detect_state() {
    local kargs_set=0 kargs_total=${#KARG_ORDER[@]}
    local flatpaks_installed=0 flatpaks_total=${#FLATPAK_IDS[@]}

    for k in "${KARG_ORDER[@]}"; do
        karg_exists "$k" && kargs_set=$(( kargs_set + 1 )) || true
    done

    for id in "${FLATPAK_IDS[@]}"; do
        flatpak_installed "$id" && flatpaks_installed=$(( flatpaks_installed + 1 )) || true
    done

    if (( kargs_set == kargs_total && flatpaks_installed == flatpaks_total )); then
        SETUP_STATE="full"
    elif (( kargs_set > 0 || flatpaks_installed > 0 )); then
        SETUP_STATE="partial"
    else
        SETUP_STATE="none"
    fi
}

detect_state

# ── Header ────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◈  KVM Userspace Setup  ◈          ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════╝${NC}"
say ""

# ── Status display ────────────────────────────────────────────
case "$SETUP_STATE" in
    none)    warn "Nothing configured yet" ;;
    full)    ok   "Fully configured" ;;
    partial) warn "Partial setup detected" ;;
esac

say ""
info "CPU: ${BOLD}${CPU^^}${NC}  →  ${DIM}${IOMMU_KARG}${NC}"
say ""

say "  ${DIM}Kernel arguments:${NC}"
for k in "${KARG_ORDER[@]}"; do
    karg_exists "$k" \
        && say "  ${GREEN}◆${NC}  ${DIM}${k}${NC}" \
        || say "  ${RED}✗${NC}  ${DIM}${k}${NC}"
done

say ""
say "  ${DIM}Flatpaks:${NC}"
has_flathub \
    && say "  ${GREEN}◆${NC}  ${DIM}Flathub${NC}" \
    || say "  ${RED}✗${NC}  ${DIM}Flathub${NC}"
for id in "${FLATPAK_IDS[@]}"; do
    flatpak_installed "$id" \
        && say "  ${GREEN}◆${NC}  ${DIM}${FLATPAK_NAME[$id]}${NC}" \
        || say "  ${RED}✗${NC}  ${DIM}${FLATPAK_NAME[$id]}${NC}"
done
say ""

# ── Core ops ──────────────────────────────────────────────────
_apply_kargs() {
    say ""
    say "  ${DIM}Select kernel arguments to apply:${NC}"
    say ""
    local to_apply=()
    for k in "${KARG_ORDER[@]}"; do
        say "  ${BOLD}${CYAN}${k}${NC}  —  ${DIM}${KARG_DESC[$k]}${NC}"
        say "  ${DIM}${KARG_DETAIL[$k]}${NC}"
        say ""
        if karg_exists "$k"; then
            say "  ${GREEN}◆${NC}  ${DIM}already active — skipping${NC}"
            say ""
        else
            printf '%b [y/N]: ' "  ${YELLOW}?${NC}  Apply ${BOLD}${k}${NC}?"
            read -r _r
            say ""
            [[ "$_r" =~ ^[Yy]([Ee][Ss])?$ ]] && to_apply+=("$k") || true
        fi
    done

    if [[ ${#to_apply[@]} -eq 0 ]]; then
        warn "No kargs selected"
        return
    fi

    step "Applying kernel arguments via rpm-ostree..."
    local flags=()
    for k in "${to_apply[@]}"; do
        flags+=("--append-if-missing=${k}")
    done
    rpm-ostree kargs "${flags[@]}"
    ok "Kernel arguments applied"
    warn "A ${YELLOW}${BOLD}reboot${NC} is required for kargs to take effect"
}

_install_flatpaks() {
    ensure_flathub
    local scope="--user"
    flatpak --system remote-list --columns=name 2>/dev/null | grep -qx 'flathub' && scope="--system" || true

    say ""
    say "  ${DIM}Select Flatpaks to install:${NC}"
    say ""
    local to_install=()
    for id in "${FLATPAK_IDS[@]}"; do
        local name="${FLATPAK_NAME[$id]}"
        say "  ${BOLD}${CYAN}${name}${NC}  ${DIM}(${id})${NC}"
        say "  ${DIM}${FLATPAK_DESC[$id]}${NC}"
        say ""
        if flatpak_installed "$id"; then
            say "  ${GREEN}◆${NC}  ${DIM}already installed — skipping${NC}"
            say ""
        else
            printf '%b [y/N]: ' "  ${YELLOW}?${NC}  Install ${BOLD}${name}${NC}?"
            read -r _r
            say ""
            [[ "$_r" =~ ^[Yy]([Ee][Ss])?$ ]] && to_install+=("$id") || true
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        warn "No Flatpaks selected"
        return
    fi

    for id in "${to_install[@]}"; do
        local name="${FLATPAK_NAME[$id]}"
        step "Installing ${name} (${scope})..."
        flatpak install -y "$scope" flathub "$id" \
            && ok "${name} installed" \
            || warn "${name} install failed"
    done
}

_remove_flatpaks() {
    for id in "${FLATPAK_IDS[@]}"; do
        local name="${FLATPAK_NAME[$id]}"
        if flatpak_installed "$id"; then
            step "Removing ${name}..."
            flatpak --user   info "$id" &>/dev/null && flatpak uninstall -y --user   "$id" >/dev/null || true
            flatpak --system info "$id" &>/dev/null && flatpak uninstall -y --system "$id" >/dev/null || true
            ok "${name} removed"
        else
            say "  ${DIM}◌  ${name} not installed — skipping${NC}"
        fi
    done
}

# ── Actions ───────────────────────────────────────────────────
do_setup() {
    _apply_kargs
    _install_flatpaks
}

do_repair() {
    step "Repairing missing components..."
    _apply_kargs
    _install_flatpaks
}

do_reinstall() {
    confirm "${YELLOW}Remove all Flatpaks and reinstall?${NC}" \
        || { ok "Cancelled"; exit 0; }
    _remove_flatpaks
    detect_state
    _install_flatpaks
}

do_remove() {
    confirm "${YELLOW}Remove all KVM Flatpaks?${NC}" \
        || { ok "Cancelled"; exit 0; }
    _remove_flatpaks
}

# ── Menu (context-aware) ──────────────────────────────────────
PICK=""
case "$SETUP_STATE" in
    none)
        menu \
            "Setup kargs + Flatpaks" \
            "Exit"
        case "$PICK" in
            1) do_setup ;;
            *) ok "Bye!"; exit 0 ;;
        esac
        ;;
    partial)
        menu \
            "Repair missing components" \
            "Reinstall Flatpaks" \
            "Remove Flatpaks" \
            "Exit"
        case "$PICK" in
            1) do_repair ;;
            2) do_reinstall ;;
            3) do_remove ;;
            *) ok "Bye!"; exit 0 ;;
        esac
        ;;
    full)
        menu \
            "Reinstall Flatpaks" \
            "Remove Flatpaks" \
            "Exit"
        case "$PICK" in
            1) do_reinstall ;;
            2) do_remove ;;
            *) ok "Bye!"; exit 0 ;;
        esac
        ;;
esac

# ── Summary ───────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  KVM Userspace Setup — Done      ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════╝${NC}"
say ""
say "  ${YELLOW}◇${NC}  ${DIM}Reboot to apply kargs:   systemctl reboot${NC}"
say "  ${YELLOW}◇${NC}  ${DIM}Verify IOMMU after boot: find /sys/kernel/iommu_groups/ -type l | wc -l${NC}"
say "  ${YELLOW}◇${NC}  ${DIM}Start libvirt:           systemctl enable --now libvirtd${NC}"
say "  ${YELLOW}◇${NC}  ${DIM}Add your user:           usermod -aG libvirt,kvm \$(whoami)${NC}"
say ""