#!/usr/bin/env bash
# ================================================================
#  Nvidia Open — NVIDIA OPEN drivers install script for zcore
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
say "${MAGENTA}${BOLD}║   ◈  NVIDIA Driver Installer  ◈          ║${NC}"
say "${MAGENTA}${BOLD}║   NVIDIA OPEN drivers for zcore          ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Make sure /var/tmp exists and is writable by all users ────
mkdir -p /var/tmp
chmod 1777 /var/tmp

# ── Variables & Paths ─────────────────────────────────────────
WORKDIR="/tmp/certs"
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | tail -1)"

PUBLIC_KEY_DER="/etc/pki/akmods/certs/zodium-mok.der"
PRIVATE_KEY_PEM="/tmp/certs/kernel_key.pem"

SIGNING_KEY="${WORKDIR}/signing_key.pem"
PUBLIC_KEY_CRT="${WORKDIR}/zodium-akmod.crt"
PRIVATE_KEY_PRIV="${WORKDIR}/private_key.priv"

SIGN_FILE="/usr/src/kernels/${KERNEL_VERSION}/scripts/sign-file"
NVIDIA_MODULE_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra/nvidia"

# ── Cleanup trap ──────────────────────────────────────────────
cleanup() {
    rm -f "${WORKDIR}/signing_key.pem" \
          "${WORKDIR}/zodium-akmod.crt" \
          "${WORKDIR}/private_key.priv"
    rm -f nvidia-container.pp
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

# ── Add Negativo17 NVIDIA repo ────────────────────────────────
info "Adding Negativo17 NVIDIA repo..."
dnf config-manager addrepo \
    --from-repofile=https://negativo17.org/repos/fedora-nvidia.repo
dnf config-manager setopt fedora-nvidia.enabled=1
dnf config-manager setopt fedora-nvidia.priority=90
info "Disabling Negativo17 Multimedia repo..."
dnf config-manager setopt fedora-multimedia.enabled=0
dnf --refresh makecache
ok "Negativo17 repos added"

# ── Install build deps ────────────────────────────────────────
info "Installing build dependencies for kernel: ${KERNEL_VERSION}..."
dnf install -y --setopt=install_weak_deps=False akmods
ok "Build dependencies installed"

# ── Workaround Fix (monkey patch akmodsbuild) ─────────────────
warn "Applying akmodsbuild workaround..."
cp /usr/sbin/akmodsbuild /usr/sbin/akmodsbuild.backup
sed -i '/if \[\[ -w \/var \]\] ; then/,/fi/d' /usr/sbin/akmodsbuild

dnf install -y --setopt=install_weak_deps=False \
    nvidia-kmod-common \
    nvidia-modprobe

info "Building NVIDIA kmod..."
akmods --force --kernels "${KERNEL_VERSION}" --kmod nvidia

mv /usr/sbin/akmodsbuild.backup /usr/sbin/akmodsbuild
ok "akmodsbuild restored"

# ── Verify modules ────────────────────────────────────────────
info "NVIDIA module detection..."
[[ -d "$NVIDIA_MODULE_DIR" ]] || \
    (cat /var/cache/akmods/nvidia/*.failed.log 2>/dev/null; fail "NVIDIA module directory missing")

shopt -s nullglob
MODULES=("$NVIDIA_MODULE_DIR"/*.ko*)
shopt -u nullglob
[[ ${#MODULES[@]} -gt 0 ]] || fail "No NVIDIA modules found"

ok "NVIDIA modules found: ${#MODULES[@]}"
for m in "${MODULES[@]}"; do
    say "  ${CYAN}◈${NC}  $(basename "$m")"
done

modinfo "${MODULES[@]}" > /dev/null || fail "modinfo check failed"
ok "NVIDIA detection passed"

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

ok "NVIDIA module signing complete"

# ── Refresh module dependencies ───────────────────────────────
info "Refreshing module dependencies..."
depmod -a "${KERNEL_VERSION}"
ok "depmod complete"

# ── Install NVIDIA userspace & container toolkit ──────────────
info "Installing NVIDIA userspace driver and container toolkit..."

curl -fLsS \
    -o /etc/yum.repos.d/nvidia-container-toolkit.repo \
    https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo

sed -i 's/^gpgcheck=0/gpgcheck=1/' /etc/yum.repos.d/nvidia-container-toolkit.repo
sed -i 's/^enabled=0.*/enabled=1/' /etc/yum.repos.d/nvidia-container-toolkit.repo

dnf install -y --setopt=install_weak_deps=False \
    nvidia-driver \
    nvidia-persistenced \
    nvidia-settings \
    nvidia-driver-cuda \
    nvidia-driver-NvFBCOpenGL \
    nvidia-container-toolkit \
    libnvidia-fbc \
    libva-nvidia-driver
ok "NVIDIA userspace installed"

info "Installing SELinux policy module..."
curl -fLsS \
    -o nvidia-container.pp \
    https://raw.githubusercontent.com/NVIDIA/dgx-selinux/master/bin/RHEL9/nvidia-container.pp
semodule -i nvidia-container.pp
ok "SELinux policy module installed"

# ── Remove build deps ─────────────────────────────────────────
info "Removing build dependencies..."
dnf remove -y akmod-nvidia akmods
ok "Build dependencies removed"

# ── Remove repos ──────────────────────────────────────────────
info "Removing temporary repos..."
rm -f /etc/yum.repos.d/nvidia-container-toolkit.repo
dnf config-manager setopt fedora-nvidia.enabled=0
rm -f /etc/yum.repos.d/fedora-nvidia.repo
ok "Temporary repos removed"
info "Enabling Negativo17 Multimedia repo..."
dnf config-manager setopt fedora-multimedia.enabled=1

# ── DNF Cleanup ───────────────────────────────────────────────
info "Running DNF cleanup..."
dnf clean all
dnf autoremove -y
dnf clean packages
ok "Cleanup complete"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  NVIDIA Driver Install Complete      ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""