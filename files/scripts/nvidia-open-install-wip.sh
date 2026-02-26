#!/usr/bin/env bash

# ---- Exit immediately if a command exits with a non-zero status ----
set -oue pipefail
# ---- Enable debug mode ----
set -x

# ---- Zodium Project : github.com/zodium-project ----
# ---- NVIDIA OPEN drivers install script for zcore ----

# ---- Make sure /var/tmp exists and is writable by all users ----
mkdir -p /var/tmp
chmod 1777 /var/tmp

# ---- Set Variables/Paths for Keys & Packages ----
REPO_SNAPSHOT="/var/tmp/zodium-enabled-repos.txt"
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora.%_arch')"

NVIDIA_MODULE_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra/nvidia"

PRIVATE_KEY_PEM="/tmp/certs/kernel_key.pem"
PRIVATE_KEY_PRIV="${WORKDIR}/private_key.priv"
PUBLIC_KEY_DER="/etc/pki/akmods/certs/zodium-akmod.der"
PUBLIC_KEY_CRT="${WORKDIR}/zodium-akmod.crt"
SIGNING_KEY="${WORKDIR}/signing_key.pem"

SIGN_FILE="/usr/src/kernels/${KERNEL_VERSION}/scripts/sign-file"
WORKDIR="/tmp/certs"

# ---- Disable External (Nonfree/Extra) Repos ----
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

# ---- Add Negativo17 Nvidia-driver Repo ---
curl -fLsS --retry 5 \
    -o /etc/yum.repos.d/negativo17-fedora-nvidia.repo \
    https://negativo17.org/repos/fedora-nvidia.repo

# ---- Build/Install Nvidia Driver Modules ----
echo "Installing kernel modules for kernel version: ${KERNEL_VERSION}"
dnf install -y --setopt=install_weak_deps=False \
    "kernel-devel-matched-$(rpm -q kernel --queryformat '%{VERSION}')"
dnf install -y --setopt=install_weak_deps=False akmods gcc-c++

# ---- Workaround Fix (monkey patch 'akmodsbuild') ----
cp /usr/sbin/akmodsbuild /usr/sbin/akmodsbuild.backup
sed -i '/if \[\[ -w \/var \]\] ; then/,/fi/d' /usr/sbin/akmodsbuild
# ---- ---- ---- ---- ---- ---- ---- ---- ---- ----  
dnf install -y --setopt=install_weak_deps=False \
    nvidia-kmod-common \
    nvidia-modprobe

# ---- Depricate when upstream fixes it (akmod) ----
mv /usr/sbin/akmodsbuild.backup /usr/sbin/akmodsbuild
# ---- ---- ---- ---- ---- ---- ---- ---- ---- ----

echo "Installing kmod..."
akmods --force --kernels "${KERNEL_VERSION}" --kmod nvidia

modinfo /usr/lib/modules/${KERNEL_VERSION}/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz \
    > /dev/null || (cat /var/cache/akmods/nvidia/*.failed.log && exit 1)

modinfo -l /usr/lib/modules/${KERNEL_VERSION}/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz

# ---- Detect if Modules & Keys are avaliable to be Singned ----
echo "== NVIDIA module & signing key detection =="

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

echo "Kernel version: $KERNEL_VERSION"

[[ -f "$PRIVATE_KEY_PEM" ]] || fail "Private key missing: $PRIVATE_KEY_PEM"
[[ -f "$PUBLIC_KEY_DER" ]]  || fail "Public key missing: $PUBLIC_KEY_DER"
[[ -x "$SIGN_FILE" ]]   || fail "sign-file not found or not executable: $SIGN_FILE"

grep -q "BEGIN PRIVATE KEY" "$PRIVATE_KEY_PEM" \
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

# ---- Sing Nvidia Driver Modules ----
echo "== NVIDIA module signing =="

fail() { echo "ERROR: $*" >&2; exit 1; }

[[ -f "$PRIVATE_KEY_PEM" ]] || fail "Missing kernel_key.pem"
[[ -f "$PUBLIC_KEY_DER" ]] || fail "Missing zodium-akmod.der"
[[ -x "$SIGN_FILE" ]] || fail "Missing sign-file"
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

# ---- Install Nvidia Driver (userspace) & container-toolkit ----
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

# ---- Remove Orphans/Useless Deps ----
dnf remove -y \
    akmod-nvidia \
    akmods \
    kernel-devel \
    kernel-headers

# ---- Remove Added Negativo & container-toolkit repo ----
rm -f nvidia-container.pp
rm -f /etc/yum.repos.d/nvidia-container-toolkit.repo
rm -f /etc/yum.repos.d/negativo17-fedora-nvidia.repo

# ---- Restore Repos (Nonfree/Extra) ----
if [[ -f "$REPO_SNAPSHOT" ]]; then
  while read -r repo; do
    dnf config-manager setopt "${repo}.enabled=1" || true
  done < "$REPO_SNAPSHOT"

  rm -f "$REPO_SNAPSHOT"
fi

# ---- Dnf Cleanup ---
dnf5 clean all
dnf5 autoremove -y
dnf5 clean packages