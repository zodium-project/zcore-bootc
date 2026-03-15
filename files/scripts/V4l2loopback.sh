#!/usr/bin/env bash
# ================================================================
#  V4l2loopback — akmod build & signing script for zcore
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
say "${MAGENTA}${BOLD}║   ◈  v4l2loopback Installer  ◈           ║${NC}"
say "${MAGENTA}${BOLD}║   akmod build & signing for zcore        ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Make sure /var/tmp exists and is writable by all users ────
mkdir -p /var/tmp
chmod 1777 /var/tmp

# ── Variables & Paths ─────────────────────────────────────────
WORKDIR="/tmp/certs"
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"

PUBLIC_KEY_DER="/etc/pki/akmods/certs/zodium-akmod.der"
PRIVATE_KEY_PEM="/tmp/certs/kernel_key.pem"

SIGNING_KEY="${WORKDIR}/signing_key.pem"
PUBLIC_KEY_CRT="${WORKDIR}/zodium-akmod.crt"
PRIVATE_KEY_PRIV="${WORKDIR}/private_key.priv"

SIGN_FILE="/usr/src/kernels/${KERNEL_VERSION}/scripts/sign-file"
V4L2_MODULE_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra/v4l2loopback"

# ── Add RPM Fusion Repos ──────────────────────────────────────
say "${CYAN}${BOLD}┌─ Repository Setup ──────────────────────┐${NC}"
say ""

info "Adding RPM Fusion free repo..."
dnf install -y --setopt=install_weak_deps=False \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"

info "Adding RPM Fusion nonfree repo..."
dnf install -y --setopt=install_weak_deps=False \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

dnf --refresh reinstall -y rpmfusion-free-release rpmfusion-nonfree-release

ok "RPM Fusion repos added"
say ""
say "${CYAN}${BOLD}└─────────────────────────────────────────┘${NC}"
say ""

# ── Install akmod-v4l2loopback & Build Deps ───────────────────
info "Installing kernel modules for kernel version: ${KERNEL_VERSION}..."
dnf install -y --setopt=install_weak_deps=False akmods gcc-c++

# ── Workaround Fix (monkey patch akmodsbuild) ─────────────────
warn "Applying akmodsbuild workaround..."
cp /usr/sbin/akmodsbuild /usr/sbin/akmodsbuild.backup
sed -i '/if \[\[ -w \/var \]\] ; then/,/fi/d' /usr/sbin/akmodsbuild

dnf install -y --setopt=install_weak_deps=False akmod-v4l2loopback

info "Building v4l2loopback kmod..."
akmods --force --kernels "${KERNEL_VERSION}" --kmod v4l2loopback

mv /usr/sbin/akmodsbuild.backup /usr/sbin/akmodsbuild
ok "akmodsbuild restored"

# ── Verify Modules ────────────────────────────────────────────
info "v4l2loopback module detection..."

[[ -d "$V4L2_MODULE_DIR" ]] || fail "v4l2loopback module directory missing"

shopt -s nullglob
MODULES=("$V4L2_MODULE_DIR"/*.ko*)
shopt -u nullglob
[[ ${#MODULES[@]} -gt 0 ]] || fail "No v4l2loopback modules built"

ok "v4l2loopback modules found: ${#MODULES[@]}"
for m in "${MODULES[@]}"; do
    say "  ${CYAN}◈${NC}  $(basename "$m")"
done

modinfo "$V4L2_MODULE_DIR"/*.ko* > /dev/null || fail "modinfo check failed"
ok "v4l2loopback detection passed"

# ── Sign v4l2loopback Modules ─────────────────────────────────
info "Signing v4l2loopback modules..."

mkdir -p "$WORKDIR"
chmod 700 "$WORKDIR"

openssl x509 -in "$PUBLIC_KEY_DER" -out "$PUBLIC_KEY_CRT"
openssl pkey -in "$PRIVATE_KEY_PEM" -out "$PRIVATE_KEY_PRIV"
chmod 600 "$PRIVATE_KEY_PRIV"

cat "$PRIVATE_KEY_PRIV" <(echo) "$PUBLIC_KEY_CRT" > "$SIGNING_KEY"
chmod 600 "$SIGNING_KEY"

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

ok "v4l2loopback module signing complete"

# ── Remove Orphans/Useless Deps ───────────────────────────────
info "Removing build dependencies..."
dnf remove -y akmod-v4l2loopback akmods gcc-c++
ok "Build dependencies removed"

# ── Install Userspace Tools ───────────────────────────────────
info "Installing v4l2loopback userspace tools..."
dnf install -y --setopt=install_weak_deps=False v4l2loopback
ok "Userspace tools installed"

# ── Remove RPM Fusion Repos ───────────────────────────────────
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
say "${MAGENTA}${BOLD}║   ◆  v4l2loopback Install Complete       ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""