#!/usr/bin/env bash
# ================================================================
#  OpenRazer — Razer hardware support for zcore
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
say "${MAGENTA}${BOLD}║   ◈  OpenRazer Installer  ◈              ║${NC}"
say "${MAGENTA}${BOLD}║   Razer hardware support for zcore       ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Make sure /var/tmp exists and is writable ─────────────────
mkdir -p /var/tmp
chmod 1777 /var/tmp

# ── Variables & Paths ─────────────────────────────────────────
WORKDIR="/tmp/certs"
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | tail -1)"
BUILD_DIR="/tmp/openrazer"

PUBLIC_KEY_DER="/etc/pki/akmods/certs/zodium-akmod.der"
PRIVATE_KEY_PEM="/tmp/certs/kernel_key.pem"

SIGNING_KEY="${WORKDIR}/signing_key.pem"
PUBLIC_KEY_CRT="${WORKDIR}/zodium-akmod.crt"
PRIVATE_KEY_PRIV="${WORKDIR}/private_key.priv"

SIGN_FILE="/usr/src/kernels/${KERNEL_VERSION}/scripts/sign-file"
MODULE_ROOT="/usr/lib/modules/${KERNEL_VERSION}"
MODULE_INSTALL_DIR="/lib/modules/${KERNEL_VERSION}/kernel/drivers/hid"

# ── Cleanup trap ──────────────────────────────────────────────
cleanup() {
    rm -f "${WORKDIR}/signing_key.pem" \
          "${WORKDIR}/zodium-akmod.crt" \
          "${WORKDIR}/private_key.priv"
    rm -rf "${BUILD_DIR}" /tmp/openrazer.tar.gz
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

# ── Fetch latest release ──────────────────────────────────────
info "Fetching latest openrazer/openrazer release..."
OPENRAZER_VERSION="$(curl -fLsS https://api.github.com/repos/openrazer/openrazer/releases/latest \
    | grep '"tag_name"' | cut -d'"' -f4)"
[[ -n "$OPENRAZER_VERSION" ]] || fail "Could not detect latest openrazer release"
info "OpenRazer version: ${OPENRAZER_VERSION}"

curl -fLsS -Lo /tmp/openrazer.tar.gz \
    "https://github.com/openrazer/openrazer/archive/refs/tags/${OPENRAZER_VERSION}.tar.gz"
ok "Source downloaded"

# ── Extract source ────────────────────────────────────────────
info "Extracting source..."
mkdir -p "${BUILD_DIR}"
tar -xzf /tmp/openrazer.tar.gz -C "${BUILD_DIR}" --strip-components=1
ok "Source extracted"

# ── Build kernel modules ──────────────────────────────────────
info "Building OpenRazer kernel modules for ${KERNEL_VERSION}..."
KERNELDIR="/usr/src/kernels/${KERNEL_VERSION}" \
    make -C "${BUILD_DIR}" -j"$(nproc)" driver
ok "OpenRazer kernel modules built"

# ── Install kernel modules ────────────────────────────────────
info "Installing OpenRazer kernel modules..."
make -C "${BUILD_DIR}" driver_install_packaging \
    MODULEDIR="${MODULE_INSTALL_DIR}" \
    DESTDIR=/
ok "OpenRazer kernel modules installed"

# ── Install udev rules ────────────────────────────────────────
info "Installing OpenRazer udev rules..."
make -C "${BUILD_DIR}" udev_install DESTDIR=/
ok "OpenRazer udev rules installed"

# ── Locate & verify built modules ────────────────────────────
info "Locating OpenRazer modules..."
shopt -s nullglob globstar
MODULES=("${MODULE_ROOT}"/**/*razer*.ko*)
shopt -u nullglob globstar

[[ ${#MODULES[@]} -gt 0 ]] || fail "No razer modules found after install"

ok "OpenRazer modules found: ${#MODULES[@]}"
for m in "${MODULES[@]}"; do
    say "  ${CYAN}◈${NC}  $(basename "$m")"
done

modinfo "${MODULES[@]}" > /dev/null || fail "modinfo check failed for openrazer"
ok "OpenRazer detection passed"

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

ok "OpenRazer module signing complete"

# ── Refresh module dependencies ───────────────────────────────
info "Refreshing module dependencies..."
depmod -a "${KERNEL_VERSION}"
ok "depmod complete"

# ── Install userspace ─────────────────────────────────────────
info "Installing OpenRazer userspace..."
dnf install -y --setopt=install_weak_deps=False \
    python3 \
    python3-setuptools \
    python3-daemonize \
    python3-setproctitle \
    xautomation

make -C "${BUILD_DIR}" python_library_install DESTDIR=/
make -C "${BUILD_DIR}" daemon_install DESTDIR=/
ok "OpenRazer userspace installed"

# ── Ensure plugdev group exists ───────────────────────────────
info "Ensuring plugdev group exists..."
if ! getent group plugdev > /dev/null; then
    groupadd -r plugdev
    ok "plugdev group created"
else
    ok "plugdev group already exists"
fi

# ── DNF Cleanup ───────────────────────────────────────────────
info "Running DNF cleanup..."
dnf clean all
dnf autoremove -y
dnf clean packages
ok "Cleanup complete"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  OpenRazer Install Complete          ║${NC}"
say "${MAGENTA}${BOLD}║   GUI: install Polychromatic via Flatpak ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""