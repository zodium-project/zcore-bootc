#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status, if an undefined variable is used, or if any command in a pipeline fails.
# Enable debug mode to print each command before executing it.
set -oue pipefail
set -x

## Work in Progress: NVIDIA Driver Installation Script for Fedora ##
# Zodium Project : github.com/zodium-project
# This script is intended to be run on a clean Fedora installation to install the NVIDIA driver and related components. It performs the following steps:
# 1. Disables any potentially conflicting repositories (e.g., RPM Fusion, Terra).
# 2. Installs the necessary kernel development packages and akmods for building the NVIDIA kernel modules.
# 3. Installs the NVIDIA driver packages from the Negativo17 repository.
# 4. Builds the NVIDIA kernel modules using akmods.
# 5. Verifies that the NVIDIA kernel modules were built successfully.
# 6. Signs the NVIDIA kernel modules using a custom signing key.
# 7. Cleans up temporary files and restores any modified repository configurations.
# 8. Installs the NVIDIA Container Toolkit and related packages for GPU support in containers.
# 9. Cleans up any remaining installation artifacts and restores the system to a clean state.

# Make sure /var/tmp exists and is writable by all users (with the sticky bit set to prevent deletion by other users).
mkdir -p /var/tmp
chmod 1777 /var/tmp

# Save the list of currently enabled repositories to a temporary file so we can restore them later.
REPO_SNAPSHOT="/var/tmp/zodium-enabled-repos.txt"

dnf repolist --enabled \
  | awk 'NR>1 {print $1}' \
  > "$REPO_SNAPSHOT"

mapfile -t SANDBOX_REPOS < <(
  dnf repolist --enabled \
    | awk 'NR>1 {print $1}' \
    | grep -Ei '^(terra|rpmfusion)'
)

if (( ${#SANDBOX_REPOS[@]} > 0 )); then
  for repo in "${SANDBOX_REPOS[@]}"; do
    dnf config-manager setopt "${repo}.enabled=0"
  done
fi

# Determine the current kernel version and architecture to ensure we install the correct kernel modules and drivers.
# Add the Negativo17 repository for NVIDIA drivers, which provides pre-built kernel modules compatible with the current kernel.
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora.%_arch')"

curl -fLsS --retry 5 \
    -o /etc/yum.repos.d/negativo17-fedora-nvidia.repo \
    https://negativo17.org/repos/fedora-nvidia.repo

echo "Installing kernel modules for kernel version: ${KERNEL_VERSION}"

dnf install -y --setopt=install_weak_deps=False \
    "kernel-devel-matched-$(rpm -q kernel --queryformat '%{VERSION}')"

dnf install -y --setopt=install_weak_deps=False akmods gcc-c++

## Workaround fix , remove when no longer needed ##
cp /usr/sbin/akmodsbuild /usr/sbin/akmodsbuild.backup
# Temporary upstream workaround
sed -i '/if \[\[ -w \/var \]\] ; then/,/fi/d' /usr/sbin/akmodsbuild
###################################################
dnf install -y --setopt=install_weak_deps=False \
    nvidia-kmod-common \
    nvidia-modprobe

## remove when no longer needed ##
mv /usr/sbin/akmodsbuild.backup /usr/sbin/akmodsbuild
##################################

echo "Installing kmod..."
akmods --force --kernels "${KERNEL_VERSION}" --kmod nvidia

modinfo /usr/lib/modules/${KERNEL_VERSION}/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz \
    > /dev/null || (cat /var/cache/akmods/nvidia/*.failed.log && exit 1)

modinfo -l /usr/lib/modules/${KERNEL_VERSION}/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz

# Detect NVIDIA modules & signing key before signing to ensure everything is in place and avoid partial signing if something is missing.
echo "== NVIDIA module & signing key detection =="
NVIDIA_MODULE_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra/nvidia"
PRIVATE_KEY="/tmp/certs/kernel_key.pem"
PUBLIC_KEY="/etc/pki/akmods/certs/zodium-nvidia.der"
SIGN_FILE="/usr/src/kernels/${KERNEL_VERSION}/scripts/sign-file"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

echo "Kernel version: $KERNEL_VERSION"

[[ -f "$PRIVATE_KEY" ]] || fail "Private key missing: $PRIVATE_KEY"
[[ -f "$PUBLIC_KEY" ]]  || fail "Public key missing: $PUBLIC_KEY"
[[ -x "$SIGN_FILE" ]]   || fail "sign-file not found or not executable: $SIGN_FILE"

grep -q "BEGIN PRIVATE KEY" "$PRIVATE_KEY" \
  || fail "Private key is not PKCS#8 PEM"

echo "Signing key: OK (PKCS#8 PEM)"
echo "Public cert: OK (DER)"

[[ -d "$NVIDIA_MODULE_DIR" ]] || fail "NVIDIA module directory missing"

shopt -s nullglob
modules=("$NVIDIA_MODULE_DIR"/*.ko*)
shopt -u nullglob

[[ ${#modules[@]} -gt 0 ]] || fail "No NVIDIA modules found"

echo "NVIDIA modules: FOUND (${#modules[@]})"
for m in "${modules[@]}"; do
  echo "  - $(basename "$m")"
done

echo "== NVIDIA detection PASSED =="

# Sign the NVIDIA kernel modules using the provided signing key. This is necessary for environments where unsigned modules cannot be loaded.
# This ensures that NVIDIA modules are loaded on system as fedora kernel is configured to only load signed modules.
echo "== NVIDIA module signing =="

MODULE_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra/nvidia"
PRIVATE_KEY_PEM="/tmp/certs/kernel_key.pem"
PUBLIC_KEY_DER="/etc/pki/akmods/certs/zodium-nvidia.der"
WORKDIR="/tmp/certs"
PUBLIC_KEY_CRT="${WORKDIR}/zodium-nvidia.crt"
PRIVATE_KEY_PRIV="${WORKDIR}/private_key.priv"
SIGNING_KEY="${WORKDIR}/signing_key.pem"

SIGN_FILE="/usr/src/kernels/${KERNEL_VERSION}/scripts/sign-file"

fail() { echo "ERROR: $*" >&2; exit 1; }

[[ -f "$PRIVATE_KEY_PEM" ]] || fail "Missing kernel_key.pem"
[[ -f "$PUBLIC_KEY_DER" ]] || fail "Missing zodium-nvidia.der"
[[ -x "$SIGN_FILE" ]] || fail "Missing sign-file"
[[ -d "$MODULE_DIR" ]] || fail "Missing module dir"

mkdir -p "$WORKDIR"
chmod 700 "$WORKDIR"

openssl x509 -in "$PUBLIC_KEY_DER" -out "$PUBLIC_KEY_CRT"

openssl pkey -in "$PRIVATE_KEY_PEM" -out "$PRIVATE_KEY_PRIV"
chmod 600 "$PRIVATE_KEY_PRIV"

cat "$PRIVATE_KEY_PRIV" <(echo) "$PUBLIC_KEY_CRT" > "$SIGNING_KEY"
chmod 600 "$SIGNING_KEY"

shopt -s nullglob
MODULES=("$MODULE_DIR"/*.ko*)
shopt -u nullglob
[[ ${#MODULES[@]} -gt 0 ]] || fail "No modules found"

for module in "${MODULES[@]}"; do
  echo "Signing $(basename "$module")"

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
done

echo "== NVIDIA module signing COMPLETE =="

# Clean up temporary files and restore any modified repository configurations to ensure the system is left in a clean state after installation.
# Install the NVIDIA Container Toolkit and related packages to enable GPU support in containerized environments (e.g., Docker, Podman).
# Install NVIDIA user-space libraries and tools for CUDA support and GPU management in containers.
# Clean up any remaining installation artifacts and restore the system to a clean state by removing temporary files and re-enabling any previously disabled repositories.
REPO_SNAPSHOT="/var/tmp/zodium-enabled-repos.txt"

nvidia_packages_list=( \
    nvidia-driver \
    nvidia-persistenced \
    nvidia-settings \
    nvidia-driver-cuda \
    nvidia-container-toolkit \
    libnvidia-fbc \
    libva-nvidia-driver \
)

curl -fLsS \
    -o /etc/yum.repos.d/nvidia-container-toolkit.repo \
    https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo

sed -i 's/^gpgcheck=0/gpgcheck=1/' /etc/yum.repos.d/nvidia-container-toolkit.repo
sed -i 's/^enabled=0.*/enabled=1/' /etc/yum.repos.d/nvidia-container-toolkit.repo

dnf install -y --setopt=install_weak_deps=False \
    "${nvidia_packages_list[@]}"

curl -fLsS \
    -o nvidia-container.pp \
    https://raw.githubusercontent.com/NVIDIA/dgx-selinux/master/bin/RHEL9/nvidia-container.pp

semodule -i nvidia-container.pp

dnf remove -y \
    akmod-nvidia \
    akmods \
    kernel-devel \
    kernel-headers

rm -f nvidia-container.pp
rm -f /etc/yum.repos.d/nvidia-container-toolkit.repo
rm -f /etc/yum.repos.d/negativo17-fedora-nvidia.repo
rm -f /etc/yum.repos.d/negativo17-fedora-multimedia.repo

if [[ -f "$REPO_SNAPSHOT" ]]; then
  while read -r repo; do
    dnf config-manager setopt "${repo}.enabled=1" || true
  done < "$REPO_SNAPSHOT"

  rm -f "$REPO_SNAPSHOT"
fi
# NVIDIA driver installation complete.
# Work in progress: Further testing and validation needed to ensure all components are installed correctly and the system is stable with the new NVIDIA drivers.