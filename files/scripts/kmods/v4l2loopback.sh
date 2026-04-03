#!/usr/bin/env bash
# ================================================================
#  v4l2loopback — git+make build & signing script for zcore
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
say "${MAGENTA}${BOLD}║   git+make build & signing for zcore     ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Make sure /var/tmp exists and is writable by all users ────
mkdir -p /var/tmp
chmod 1777 /var/tmp

# ── Variables & Paths ─────────────────────────────────────────
WORKDIR="/tmp/certs"
BUILD_DIR="/tmp/v4l2loopback"
REPO="v4l2loopback/v4l2loopback"

KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | tail -1)"

PUBLIC_KEY_DER="/etc/pki/akmods/certs/zodium-akmod.der"
PRIVATE_KEY_PEM="/tmp/certs/kernel_key.pem"

SIGNING_KEY="${WORKDIR}/signing_key.pem"
PUBLIC_KEY_CRT="${WORKDIR}/zodium-akmod.crt"
PRIVATE_KEY_PRIV="${WORKDIR}/private_key.priv"

SIGN_FILE="/usr/src/kernels/${KERNEL_VERSION}/scripts/sign-file"
MODULE_ROOT="/usr/lib/modules/${KERNEL_VERSION}"

# ── Cleanup trap ──────────────────────────────────────────────
cleanup() {
    rm -f "${WORKDIR}/signing_key.pem" \
          "${WORKDIR}/zodium-akmod.crt" \
          "${WORKDIR}/private_key.priv"
    rm -rf "${BUILD_DIR}"
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

# ── Install build deps ────────────────────────────────────────
info "Installing build dependencies"
dnf install -y --setopt=install_weak_deps=False help2man
ok "Build dependencies installed"

# ── Fetch latest release tag ──────────────────────────────────
info "Fetching latest v4l2loopback release tag..."
V4L2LB_VERSION="$(curl -fLsS \
    https://api.github.com/repos/${REPO}/tags \
    | grep '"name"' | head -1 | cut -d'"' -f4)"
[[ -n "$V4L2LB_VERSION" ]] || fail "Could not detect latest v4l2loopback tag"
info "v4l2loopback version: ${V4L2LB_VERSION}"

# ── Clone at tag ──────────────────────────────────────────────
info "Cloning v4l2loopback ${V4L2LB_VERSION}..."
rm -rf "${BUILD_DIR}"
git clone --depth=1 --branch "${V4L2LB_VERSION}" \
    "https://github.com/${REPO}.git" "${BUILD_DIR}"
ok "Source cloned"

# ── Build kernel module ───────────────────────────────────────
info "Building v4l2loopback kernel module for ${KERNEL_VERSION}..."
make -C "${BUILD_DIR}" KERNELRELEASE="${KERNEL_VERSION}" -j"$(nproc)"
ok "Kernel module built"

# ── Install module, utils & headers ──────────────────────────
info "Installing v4l2loopback..."
make -C "${BUILD_DIR}" KERNELRELEASE="${KERNEL_VERSION}" install
make -C "${BUILD_DIR}" KERNELRELEASE="${KERNEL_VERSION}" install-man
make -C "${BUILD_DIR}" KERNELRELEASE="${KERNEL_VERSION}" install-utils
make -C "${BUILD_DIR}" KERNELRELEASE="${KERNEL_VERSION}" install-headers
ok "v4l2loopback installed"

# ── Locate & verify installed modules ────────────────────────
info "Verifying installed modules..."
shopt -s nullglob globstar
MODULES=("${MODULE_ROOT}"/**/*v4l2loopback*.ko*)
shopt -u nullglob globstar

[[ ${#MODULES[@]} -gt 0 ]] || fail "No v4l2loopback modules found after install"

ok "v4l2loopback modules found: ${#MODULES[@]}"
for m in "${MODULES[@]}"; do
    say "  ${CYAN}◈${NC}  $(basename "$m")"
done

modinfo "${MODULES[@]}" > /dev/null || fail "modinfo check failed"
ok "v4l2loopback detection passed"

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
        cp --remove-destination "$module" "${module}.tmp"
        mv "${module}.tmp" "$module"
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

# ── Refresh module dependencies ───────────────────────────────
info "Refreshing module dependencies..."
depmod -a "${KERNEL_VERSION}"
ok "depmod complete"

# ── Remove build deps ─────────────────────────────────────────
info "Removing build dependencies..."
dnf remove -y help2man
ok "Build dependencies removed"

# ── DNF Cleanup ───────────────────────────────────────────────
info "Running DNF cleanup..."
dnf clean all
dnf autoremove -y
dnf clean packages
ok "Cleanup complete"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  v4l2loopback Install Complete               ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
say ""