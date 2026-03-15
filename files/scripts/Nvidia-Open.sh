#!/usr/bin/env bash
# ================================================================
#  Nvidia-Open — NVIDIA OPEN drivers install script for zcore
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

RELEASE="$(rpm -E '%fedora.%_arch')"
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"

PUBLIC_KEY_DER="/etc/pki/akmods/certs/zodium-akmod.der"
PRIVATE_KEY_PEM="/tmp/certs/kernel_key.pem"

SIGNING_KEY="${WORKDIR}/signing_key.pem"
PUBLIC_KEY_CRT="${WORKDIR}/zodium-akmod.crt"
PRIVATE_KEY_PRIV="${WORKDIR}/private_key.priv"

SIGN_FILE="/usr/src/kernels/${KERNEL_VERSION}/scripts/sign-file"
NVIDIA_MODULE_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra/nvidia"

# ── Add Negativo17 Nvidia-driver Repo ─────────────────────────
info "Adding Negativo17 NVIDIA repo..."
curl -fLsS --retry 5 \
    -o /etc/yum.repos.d/negativo17-fedora-nvidia.repo \
    https://negativo17.org/repos/fedora-nvidia.repo
ok "Negativo17 repo added"

# ── Build/Install Nvidia Driver Modules ───────────────────────
info "Installing kernel modules for kernel version: ${KERNEL_VERSION}..."
dnf install -y --setopt=install_weak_deps=False akmods gcc-c++

# ── Workaround Fix (monkey patch akmodsbuild) ─────────────────
warn "Applying akmodsbuild workaround..."
cp /usr/sbin/akmodsbuild /usr/sbin/akmodsbuild.backup
sed -i '/if \[\[ -w \/var \]\] ; then/,/fi/d' /usr/sbin/akmodsbuild

dnf install -y --setopt=install_weak_deps=False \
    nvidia-kmod-common \
    nvidia-modprobe

mv /usr/sbin/akmodsbuild.backup /usr/sbin/akmodsbuild
ok "akmodsbuild restored"

info "Building NVIDIA kmod..."
akmods --force --kernels "${KERNEL_VERSION}" --kmod nvidia

modinfo /usr/lib/modules/${KERNEL_VERSION}/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz \
    > /dev/null || (cat /var/cache/akmods/nvidia/*.failed.log && exit 1)

modinfo -l /usr/lib/modules/${KERNEL_VERSION}/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz

# ── Detect if Modules & Keys are available to be Signed ───────
info "NVIDIA module & signing key detection..."

info "Kernel version: $KERNEL_VERSION"

[[ -f "$PRIVATE_KEY_PEM" ]] || fail "Private key missing: $PRIVATE_KEY_PEM"
[[ -f "$PUBLIC_KEY_DER" ]]  || fail "Public key missing: $PUBLIC_KEY_DER"
[[ -x "$SIGN_FILE" ]]       || fail "sign-file not found or not executable: $SIGN_FILE"

grep -q "BEGIN PRIVATE KEY" "$PRIVATE_KEY_PEM" \
    || fail "Private key is not PKCS#8 PEM"

ok "Signing key: OK (PKCS#8 PEM)"
ok "Public cert: OK (DER)"

[[ -d "$NVIDIA_MODULE_DIR" ]] || fail "NVIDIA module directory missing"

shopt -s nullglob
modules=("$NVIDIA_MODULE_DIR"/*.ko*)
shopt -u nullglob

[[ ${#modules[@]} -gt 0 ]] || fail "No NVIDIA modules found"

ok "NVIDIA modules found: ${#modules[@]}"
for m in "${modules[@]}"; do
    say "  ${CYAN}◈${NC}  $(basename "$m")"
done

ok "NVIDIA detection passed"

# ── Sign NVIDIA Driver Modules ────────────────────────────────
info "Signing NVIDIA modules..."

[[ -f "$PRIVATE_KEY_PEM" ]] || fail "Missing kernel_key.pem"
[[ -f "$PUBLIC_KEY_DER" ]]  || fail "Missing zodium-akmod.der"
[[ -x "$SIGN_FILE" ]]       || fail "Missing sign-file"
[[ -d "$NVIDIA_MODULE_DIR" ]] || fail "Missing module dir"

mkdir -p "$WORKDIR"
chmod 700 "$WORKDIR"

openssl x509 -in "$PUBLIC_KEY_DER" -out "$PUBLIC_KEY_CRT"

openssl pkey -in "$PRIVATE_KEY_PEM" -out "$PRIVATE_KEY_PRIV"
chmod 600 "$PRIVATE_KEY_PRIV"

cat "$PRIVATE_KEY_PRIV" <(echo) "$PUBLIC_KEY_CRT" > "$SIGNING_KEY"
chmod 600 "$SIGNING_KEY"

shopt -s nullglob
MODULES=("$NVIDIA_MODULE_DIR"/*.ko*)
shopt -u nullglob
[[ ${#MODULES[@]} -gt 0 ]] || fail "No modules found"

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

# ── Install NVIDIA Driver (userspace) & container-toolkit ─────
info "Installing NVIDIA userspace driver and container toolkit..."
nvidia_packages_list=(
    nvidia-driver
    nvidia-persistenced
    nvidia-settings
    nvidia-driver-cuda
    nvidia-container-toolkit
    libnvidia-fbc
    libva-nvidia-driver
)

curl -fLsS \
    -o /etc/yum.repos.d/nvidia-container-toolkit.repo \
    https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo

sed -i 's/^gpgcheck=0/gpgcheck=1/' /etc/yum.repos.d/nvidia-container-toolkit.repo
sed -i 's/^enabled=0.*/enabled=1/' /etc/yum.repos.d/nvidia-container-toolkit.repo

dnf install -y --setopt=install_weak_deps=False \
    "${nvidia_packages_list[@]}"

info "Installing SELinux policy module..."
curl -fLsS \
    -o nvidia-container.pp \
    https://raw.githubusercontent.com/NVIDIA/dgx-selinux/master/bin/RHEL9/nvidia-container.pp

semodule -i nvidia-container.pp
ok "SELinux policy module installed"

# ── Remove Orphans/Useless Deps ───────────────────────────────
info "Removing build dependencies..."
dnf remove -y \
    akmod-nvidia \
    akmods \
    gcc-c++
ok "Build dependencies removed"

# ── Remove Added Repos ────────────────────────────────────────
info "Removing temporary repos..."
rm -f nvidia-container.pp
rm -f /etc/yum.repos.d/nvidia-container-toolkit.repo
rm -f /etc/yum.repos.d/negativo17-fedora-nvidia.repo
ok "Temporary repos removed"

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