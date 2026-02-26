#!/usr/bin/env bash

# ---- Exit immediately if a command exits with a non-zero status ----
set -oue pipefail
set -x

# ---- Zodium Project : github.com/zodium-project ----
# ---- v4l2loopback akmod build & signing script ----

# ---- Make sure /var/tmp exists and is writable by all users ----
mkdir -p /var/tmp
chmod 1777 /var/tmp

# ---- Variables & Paths ----
WORKDIR="/tmp/certs"
REPO_SNAPSHOT="/var/tmp/zodium-enabled-repos.txt"
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"

PUBLIC_KEY_DER="/etc/pki/akmods/certs/zodium-akmod.der"
PRIVATE_KEY_PEM="/tmp/certs/kernel_key.pem"

SIGNING_KEY="${WORKDIR}/signing_key.pem"
PUBLIC_KEY_CRT="${WORKDIR}/zodium-akmod.crt"
PRIVATE_KEY_PRIV="${WORKDIR}/private_key.priv"

SIGN_FILE="/usr/src/kernels/${KERNEL_VERSION}/scripts/sign-file"
V4L2_MODULE_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra/v4l2loopback"

# ---- Disable only Terra repos temporarily ----
dnf repolist --enabled | awk 'NR>1 {print $1}' > "$REPO_SNAPSHOT"

mapfile -t TERRAREPOS < <(
  dnf repolist --enabled | awk 'NR>1 {print $1}' | grep -Ei '^terra'
)

if (( ${#TERRAREPOS[@]} > 0 )); then
  for repo in "${TERRAREPOS[@]}"; do
    dnf config-manager setopt "${repo}.enabled=0"
  done
fi

# ---- Install akmod-v4l2loopback & build deps ----
echo "Installing kernel modules for kernel version: ${KERNEL_VERSION}"
dnf install -y --setopt=install_weak_deps=False \
    "kernel-devel-matched-$(rpm -q kernel --queryformat '%{VERSION}')"
dnf install -y --setopt=install_weak_deps=False akmods gcc-c++

# ---- Monkey-patch akmodsbuild (workaround) ----
cp /usr/sbin/akmodsbuild /usr/sbin/akmodsbuild.backup
sed -i '/if \[\[ -w \/var \]\] ; then/,/fi/d' /usr/sbin/akmodsbuild

dnf install -y --setopt=install_weak_deps=False akmod-v4l2loopback

# ---- Build v4l2loopback modules ----
echo "Building v4l2loopback kernel modules for ${KERNEL_VERSION}"
akmods --force --kernels "${KERNEL_VERSION}" --kmod v4l2loopback

# ---- Restore akmodsbuild ----
mv /usr/sbin/akmodsbuild.backup /usr/sbin/akmodsbuild

# ---- Verify modules ----
fail() { echo "ERROR: $*" >&2; exit 1; }

[[ -d "$V4L2_MODULE_DIR" ]] || fail "v4l2loopback module directory missing"

shopt -s nullglob
MODULES=("$V4L2_MODULE_DIR"/*.ko*)
shopt -u nullglob
[[ ${#MODULES[@]} -gt 0 ]] || fail "No v4l2loopback modules built"

echo "v4l2loopback modules built: ${#MODULES[@]}"
for m in "${MODULES[@]}"; do
  echo "  - $(basename "$m")"
done

modinfo "$V4L2_MODULE_DIR"/*.ko* > /dev/null || fail "modinfo check failed"

# ---- Sign modules ----
mkdir -p "$WORKDIR"
chmod 700 "$WORKDIR"

openssl x509 -in "$PUBLIC_KEY_DER" -out "$PUBLIC_KEY_CRT"
openssl pkey -in "$PRIVATE_KEY_PEM" -out "$PRIVATE_KEY_PRIV"
chmod 600 "$PRIVATE_KEY_PRIV"

cat "$PRIVATE_KEY_PRIV" <(echo) "$PUBLIC_KEY_CRT" > "$SIGNING_KEY"
chmod 600 "$SIGNING_KEY"

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

echo "== Module signing COMPLETE =="

# ---- Remove akmod-v4l2loopback & cleanup build deps ----
dnf remove -y akmod-v4l2loopback akmods gcc-c++ kernel-devel kernel-headers

# ---- Install userspace/tools ----
dnf install -y --setopt=install_weak_deps=False v4l2loopback

# ---- Load module & verify ----
modprobe v4l2loopback
modinfo "$V4L2_MODULE_DIR"/*.ko*

# ---- Restore Terra repos ----
if [[ -f "$REPO_SNAPSHOT" ]]; then
  while read -r repo; do
    dnf config-manager setopt "${repo}.enabled=1" || true
  done < "$REPO_SNAPSHOT"
  rm -f "$REPO_SNAPSHOT"
fi

# ---- Cleanup ----
dnf clean all
dnf autoremove -y
dnf clean packages

echo "== v4l2loopback installation, signing, and verification COMPLETE =="