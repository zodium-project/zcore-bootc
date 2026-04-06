#!/usr/bin/env bash
# ================================================================
#  Intel-AMD — kernel module build & signing script for zcore
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
say "${MAGENTA}${BOLD}║   ◈  Intel & AMD Installer  ◈            ║${NC}"
say "${MAGENTA}${BOLD}║   git+make build & signing for zcore     ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Make sure /var/tmp exists and is writable ─────────────────
mkdir -p /var/tmp
chmod 1777 /var/tmp

# ── Variables & Paths ─────────────────────────────────────────
WORKDIR="/tmp/certs"
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | tail -1)"

USBIO_BUILD_DIR="/tmp/usbio-drivers"
ZENPOWER5_BUILD_DIR="/tmp/zenpower5"

PUBLIC_KEY_DER="/etc/pki/akmods/certs/zodium-mok.der"
PRIVATE_KEY_PEM="/tmp/certs/kernel_key.pem"

SIGNING_KEY="${WORKDIR}/signing_key.pem"
PUBLIC_KEY_CRT="${WORKDIR}/zodium-akmod.crt"
PRIVATE_KEY_PRIV="${WORKDIR}/private_key.priv"

SIGN_FILE="/usr/src/kernels/${KERNEL_VERSION}/scripts/sign-file"

# ── Cleanup trap ──────────────────────────────────────────────
cleanup() {
    rm -f "${WORKDIR}/signing_key.pem" \
          "${WORKDIR}/zodium-akmod.crt" \
          "${WORKDIR}/private_key.priv"
    rm -rf "${USBIO_BUILD_DIR}" "${ZENPOWER5_BUILD_DIR}" \
           /tmp/usbio-drivers.tar.gz
}
trap cleanup EXIT

# ── Shared: Signing prerequisite checks ───────────────────────
check_signing_prereqs() {
    [[ -f "$PRIVATE_KEY_PEM" ]] || fail "Private key missing: $PRIVATE_KEY_PEM"
    [[ -f "$PUBLIC_KEY_DER" ]]  || fail "Public key missing: $PUBLIC_KEY_DER"
    [[ -x "$SIGN_FILE" ]]       || fail "sign-file not found or not executable: $SIGN_FILE"
    grep -q "BEGIN PRIVATE KEY" "$PRIVATE_KEY_PEM" \
        || fail "Private key is not PKCS#8 PEM"
    ok "Signing key: OK (PKCS#8 PEM)"
    ok "Public cert: OK (DER)"
}

# ── Shared: Signing key setup ─────────────────────────────────
setup_signing_keys() {
    mkdir -p "$WORKDIR"
    chmod 700 "$WORKDIR"
    openssl x509 -in "$PUBLIC_KEY_DER" -out "$PUBLIC_KEY_CRT"
    openssl pkey -in "$PRIVATE_KEY_PEM" -out "$PRIVATE_KEY_PRIV"
    chmod 600 "$PRIVATE_KEY_PRIV"
    cat "$PRIVATE_KEY_PRIV" <(echo) "$PUBLIC_KEY_CRT" > "$SIGNING_KEY"
    chmod 600 "$SIGNING_KEY"
}

# ── Shared: Sign modules by glob pattern ──────────────────────
sign_modules() {
    local GLOB_PATTERN="$1"
    local MODULE_ROOT="/usr/lib/modules/${KERNEL_VERSION}"

    shopt -s nullglob globstar
    local MODULES=("${MODULE_ROOT}"/**/${GLOB_PATTERN})
    shopt -u nullglob globstar

    [[ ${#MODULES[@]} -gt 0 ]] || fail "No modules found matching ${GLOB_PATTERN}"

    ok "Modules found: ${#MODULES[@]}"
    for m in "${MODULES[@]}"; do
        say "  ${CYAN}◈${NC}  $(basename "$m")"
    done

    modinfo "${MODULES[@]}" > /dev/null || fail "modinfo check failed for ${GLOB_PATTERN}"

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
}

# ── Check signing prereqs once before all phases ──────────────
check_signing_prereqs
setup_signing_keys

# ════════════════════════════════════════════════════════════════
#  PHASE 1 — intel/usbio-drivers (git+make)
# ════════════════════════════════════════════════════════════════
say ""
say "${CYAN}${BOLD}── Phase 1: intel-usbio (git+make) ─────────────────────${NC}"
say ""

info "Fetching latest intel/usbio-drivers release..."
USBIO_VERSION="$(curl -fLsS \
    https://api.github.com/repos/intel/usbio-drivers/releases/latest \
    | grep '"tag_name"' | cut -d'"' -f4)"
[[ -n "$USBIO_VERSION" ]] || fail "Could not detect latest usbio-drivers release"
info "usbio-drivers version: ${USBIO_VERSION}"

curl -fLsS -Lo /tmp/usbio-drivers.tar.gz \
    "https://github.com/intel/usbio-drivers/archive/refs/tags/${USBIO_VERSION}.tar.gz"
ok "Source downloaded"

info "Extracting source..."
mkdir -p "${USBIO_BUILD_DIR}"
tar -xzf /tmp/usbio-drivers.tar.gz -C "${USBIO_BUILD_DIR}" --strip-components=1
ok "Source extracted"

info "Building usbio modules for ${KERNEL_VERSION}..."
make -C "${USBIO_BUILD_DIR}" -j"$(nproc)" \
    KERNELRELEASE="${KERNEL_VERSION}" \
    KDIR="/usr/src/kernels/${KERNEL_VERSION}"
ok "usbio modules built"

info "Installing usbio modules..."
make -C "${USBIO_BUILD_DIR}" modules_install \
    KERNELRELEASE="${KERNEL_VERSION}" \
    KDIR="/usr/src/kernels/${KERNEL_VERSION}"
ok "usbio modules installed"

info "Signing usbio modules..."
sign_modules "*usbio*.ko*"

info "Refreshing module dependencies..."
depmod -a "${KERNEL_VERSION}"
ok "depmod complete"

info "Running DNF cleanup..."
dnf clean all
dnf autoremove -y
dnf clean packages
ok "Phase 1 cleanup complete"

# ════════════════════════════════════════════════════════════════
#  PHASE 2 — mattkeenan/zenpower5 (git+make)
# ════════════════════════════════════════════════════════════════
say ""
say "${CYAN}${BOLD}── Phase 2: zenpower5 (git+make) ────────────────────────${NC}"
say ""

info "Fetching latest zenpower5 tag..."
ZENPOWER5_VERSION="$(curl -fLsS \
    https://api.github.com/repos/mattkeenan/zenpower5/tags \
    | grep '"name"' | head -1 | cut -d'"' -f4)"
[[ -n "$ZENPOWER5_VERSION" ]] || fail "Could not detect latest zenpower5 tag"
info "zenpower5 version: ${ZENPOWER5_VERSION}"

info "Cloning zenpower5 ${ZENPOWER5_VERSION}..."
rm -rf "${ZENPOWER5_BUILD_DIR}"
git clone --depth=1 --branch "${ZENPOWER5_VERSION}" \
    "https://github.com/mattkeenan/zenpower5.git" "${ZENPOWER5_BUILD_DIR}"
ok "Source cloned"

info "Building zenpower5 kernel module for ${KERNEL_VERSION}..."
make -C "${ZENPOWER5_BUILD_DIR}" TARGET="${KERNEL_VERSION}" modules -j"$(nproc)"
ok "Kernel module built"

info "Installing zenpower5 kernel module..."
install -D -p -m 644 \
    "${ZENPOWER5_BUILD_DIR}/zenpower.ko" \
    "/usr/lib/modules/${KERNEL_VERSION}/extra/zenpower5/zenpower.ko"
ok "Kernel module installed"

info "Blacklisting k10temp..."
cat > /etc/modprobe.d/zenpower5.conf << 'EOF'
# zenpower5 uses the same PCI device as k10temp
# k10temp must be disabled for zenpower5 to work
blacklist k10temp
EOF
ok "k10temp blacklisted"

info "Signing zenpower5 modules..."
sign_modules "*zenpower*.ko*"

info "Refreshing module dependencies..."
depmod -a "${KERNEL_VERSION}"
ok "depmod complete"

info "Running DNF cleanup..."
dnf clean all
dnf autoremove -y
dnf clean packages
ok "Phase 2 cleanup complete"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  Intel & AMD Install Complete        ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""