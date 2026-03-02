#!/usr/bin/env bash
# ================================================================
#  Broadcom-Wl — Broadcom Wi-Fi kernel module build & signing
#  Zodium Project : github.com/zodium-project
# ================================================================

# ── Exit immediately if a command exits with a non-zero status ── #
set -Eeuo pipefail

# ── Styling ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

say()  { printf "$@"; printf '\n'; }
info() { say "${CYAN}◈${NC}  $*"; }
ok()   { say "${GREEN}◆${NC}  $*"; }
warn() { say "${YELLOW}◇${NC}  $*"; }
fail() { say "${RED}⦻${NC}  $*" >&2; exit 1; }

# ── Header ────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◈  akmod-wl Build & Signing  ◈         ║${NC}"
say "${MAGENTA}${BOLD}║   Broadcom Wi-Fi kernel module           ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Make sure /var/tmp exists and is writable by all users ────
mkdir -p /var/tmp
chmod 1777 /var/tmp

# ── Variables & Paths ─────────────────────────────────────────
WORKDIR="/tmp/certs"

REPO_SNAPSHOT="/var/tmp/zodium-enabled-repos.txt"
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"

PUBLIC_KEY_DER="/etc/pki/akmods/certs/zodium-akmod.der"
PRIVATE_KEY_PEM="/tmp/certs/kernel_key.pem"
SIGNING_KEY="${WORKDIR}/signing_key.pem"

PUBLIC_KEY_CRT="${WORKDIR}/zodium-akmod.crt"
PRIVATE_KEY_PRIV="${WORKDIR}/private_key.priv"
SIGN_FILE="/usr/src/kernels/${KERNEL_VERSION}/scripts/sign-file"

WL_MODULE_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra/wl"

# ── Disable only Terra repos temporarily ──────────────────────
info "Snapshotting enabled repos..."
dnf repolist --enabled | awk 'NR>1 {print $1}' > "$REPO_SNAPSHOT"
mapfile -t TERRAREPOS < <(
    dnf repolist --enabled | awk 'NR>1 {print $1}' | grep -Ei '^terra'
)
if (( ${#TERRAREPOS[@]} > 0 )); then
    info "Disabling Terra repos temporarily..."
    for repo in "${TERRAREPOS[@]}"; do
        dnf config-manager setopt "${repo}.enabled=0"
    done
    ok "Terra repos disabled"
fi

# ── Install akmod-wl & build deps ─────────────────────────────
info "Installing akmod-wl and dependencies for kernel ${KERNEL_VERSION}..."
dnf --refresh install -y --setopt=install_weak_deps=False \
    "kernel-devel-matched-$(rpm -q kernel --queryformat '%{VERSION}')"
dnf install -y --setopt=install_weak_deps=False akmods gcc-c++

# ── Monkey-patch akmodsbuild (workaround) ─────────────────────
warn "Applying akmodsbuild workaround..."
cp /usr/sbin/akmodsbuild /usr/sbin/akmodsbuild.backup
sed -i '/if \[\[ -w \/var \]\] ; then/,/fi/d' /usr/sbin/akmodsbuild

dnf install -y --setopt=install_weak_deps=False akmod-wl

info "Building wl kernel modules for ${KERNEL_VERSION}..."
akmods --force --kernels "${KERNEL_VERSION}" --kmod wl

# ── Restore akmodsbuild ───────────────────────────────────────
mv /usr/sbin/akmodsbuild.backup /usr/sbin/akmodsbuild
ok "akmodsbuild restored"

# ── Verify modules ────────────────────────────────────────────
info "Verifying built modules..."
[[ -d "$WL_MODULE_DIR" ]] || fail "wl module directory missing"

shopt -s nullglob
MODULES=("$WL_MODULE_DIR"/*.ko*)
shopt -u nullglob

[[ ${#MODULES[@]} -gt 0 ]] || fail "No wl modules built"
ok "wl modules built: ${#MODULES[@]}"
for m in "${MODULES[@]}"; do
    say "  ${CYAN}◈${NC}  $(basename "$m")"
done

modinfo "$WL_MODULE_DIR"/*.ko* > /dev/null || fail "modinfo check failed"

# ── Sign modules ──────────────────────────────────────────────
info "Preparing signing keys..."
mkdir -p "$WORKDIR"
chmod 700 "$WORKDIR"
openssl x509 -in "$PUBLIC_KEY_DER" -out "$PUBLIC_KEY_CRT"
openssl pkey -in "$PRIVATE_KEY_PEM" -out "$PRIVATE_KEY_PRIV"
chmod 600 "$PRIVATE_KEY_PRIV"
cat "$PRIVATE_KEY_PRIV" <(echo) "$PUBLIC_KEY_CRT" > "$SIGNING_KEY"
chmod 600 "$SIGNING_KEY"
ok "Signing keys ready"

info "Signing modules..."
for module in "${MODULES[@]}"; do
    info "Signing $(basename "$module")..."
    compressed=false
    if [[ "$module" == *.xz ]]; then
        xz -d "$module"
        module="${module%.xz}"
        compressed=true
    fi

    openssl cms -sign \
        -signer "$SIGNING_KEY" \
        -binary \
        -in "$module" \
        -outform DER \
        -out "${module}.cms" \
        -nocerts -noattr -nosmimecap

    "$SIGN_FILE" -s "${module}.cms" sha256 "$PUBLIC_KEY_CRT" "$module"
    rm -f "${module}.cms"
    $compressed && xz -C crc32 -f "$module"
    ok "Signed $(basename "$module")"
done

ok "Module signing complete"

# ── Remove akmod-wl & cleanup build deps ──────────────────────
info "Removing build dependencies..."
dnf remove -y akmod-wl akmods gcc-c++ kernel-devel kernel-headers
ok "Build dependencies removed"

# ── Restore Terra repos ───────────────────────────────────────
if [[ -f "$REPO_SNAPSHOT" ]]; then
    info "Restoring Terra repos..."
    while read -r repo; do
        dnf config-manager setopt "${repo}.enabled=1" || true
    done < "$REPO_SNAPSHOT"
    rm -f "$REPO_SNAPSHOT"
    ok "Terra repos restored"
fi

# ── Cleanup ───────────────────────────────────────────────────
info "Running DNF cleanup..."
dnf clean all
dnf autoremove -y
dnf clean packages
ok "Cleanup complete"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  akmod-wl Build & Signing Complete   ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""