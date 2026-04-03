#!/usr/bin/env bash
# ================================================================
#  Broadcom Wl — Broadcom Wi-Fi kernel module build & signing
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
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | tail -1)"

PUBLIC_KEY_DER="/etc/pki/akmods/certs/zodium-akmod.der"
PRIVATE_KEY_PEM="/tmp/certs/kernel_key.pem"

SIGNING_KEY="${WORKDIR}/signing_key.pem"
PUBLIC_KEY_CRT="${WORKDIR}/zodium-akmod.crt"
PRIVATE_KEY_PRIV="${WORKDIR}/private_key.priv"

SIGN_FILE="/usr/src/kernels/${KERNEL_VERSION}/scripts/sign-file"
WL_MODULE_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra/wl"

# ── Cleanup trap ──────────────────────────────────────────────
cleanup() {
    rm -f "${WORKDIR}/signing_key.pem" \
          "${WORKDIR}/zodium-akmod.crt" \
          "${WORKDIR}/private_key.priv"
}
trap cleanup EXIT

# ── Signing prerequisite checks ───────────────────────────────
info "Checking signing prerequisites..."
[[ -f "$PRIVATE_KEY_PEM" ]] || fail "Private key missing: $PRIVATE_KEY_PEM"
[[ -f "$PUBLIC_KEY_DER" ]]  || fail "Public key missing: $PUBLIC_KEY_DER"
[[ -x "$SIGN_FILE" ]]       || fail "sign-file not found or not executable: $SIGN_FILE"
grep -q "BEGIN PRIVATE KEY" "$PRIVATE_KEY_PEM" \
    || fail "Private key is not PKCS#8 PEM"
ok "Signing key: OK (PKCS#8 PEM)"
ok "Public cert: OK (DER)"

# ── Add RPM Fusion repos ──────────────────────────────────────
info "Adding RPM Fusion free repo..."
dnf install -y --setopt=install_weak_deps=False \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"

info "Adding RPM Fusion nonfree repo..."
dnf install -y --setopt=install_weak_deps=False \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

info "Reinstalling RPM Fusion repos..."
dnf --refresh reinstall -y rpmfusion-free-release rpmfusion-nonfree-release
ok "RPM Fusion repos ready"

# ── Install build deps ────────────────────────────────────────
info "Installing build dependencies for kernel: ${KERNEL_VERSION}..."
dnf install -y --setopt=install_weak_deps=False akmods
ok "Build dependencies installed"

# ── Workaround Fix (monkey patch akmodsbuild) ─────────────────
warn "Applying akmodsbuild workaround..."
cp /usr/sbin/akmodsbuild /usr/sbin/akmodsbuild.backup
sed -i '/if \[\[ -w \/var \]\] ; then/,/fi/d' /usr/sbin/akmodsbuild

dnf install -y --setopt=install_weak_deps=False akmod-wl

info "Building wl kernel modules for ${KERNEL_VERSION}..."
akmods --force --kernels "${KERNEL_VERSION}" --kmod wl

mv /usr/sbin/akmodsbuild.backup /usr/sbin/akmodsbuild
ok "akmodsbuild restored"

# ── Verify modules ────────────────────────────────────────────
info "Verifying built modules..."
[[ -d "$WL_MODULE_DIR" ]] || fail "wl module directory missing"

shopt -s nullglob
MODULES=("$WL_MODULE_DIR"/*.ko*)
shopt -u nullglob
[[ ${#MODULES[@]} -gt 0 ]] || fail "No wl modules found"

ok "wl modules found: ${#MODULES[@]}"
for m in "${MODULES[@]}"; do
    say "  ${CYAN}◈${NC}  $(basename "$m")"
done

modinfo "${MODULES[@]}" > /dev/null || fail "modinfo check failed"
ok "wl detection passed"

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

ok "wl module signing complete"

# ── Refresh module dependencies ───────────────────────────────
info "Refreshing module dependencies..."
depmod -a "${KERNEL_VERSION}"
ok "depmod complete"

# ── Remove build deps ─────────────────────────────────────────
info "Removing build dependencies..."
dnf remove -y akmod-wl akmods
ok "Build dependencies removed"

# ── Remove RPM Fusion repos ───────────────────────────────────
info "Removing RPM Fusion repos..."
dnf remove -y rpmfusion-free-release rpmfusion-nonfree-release
ok "RPM Fusion repos removed"

# ── DNF Cleanup ───────────────────────────────────────────────
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