#!/usr/bin/env bash

# ---- Exit on errors or undefined variables ----
set -oue pipefail

# ---- Zodium Project : github.com/zodium-project ----
# ---- akmod-xpadneo & akmod-xone install, build & signing script ----

# ---- Ensure /var/tmp exists and is writable ----
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

# ---- Module directories ----
XPAD_MODULE_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra/xpadneo"
XONE_MODULE_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra/xone"

# ---- Disable Terra & RPMFusion repos temporarily ----
dnf repolist --enabled | awk 'NR>1 {print $1}' > "$REPO_SNAPSHOT"

mapfile -t SANDBOX_REPOS < <(
  dnf repolist --enabled | awk 'NR>1 {print $1}' | grep -Ei '^(terra|rpmfusion)'
)

if (( ${#SANDBOX_REPOS[@]} > 0 )); then
  for repo in "${SANDBOX_REPOS[@]}"; do
    dnf config-manager setopt "${repo}.enabled=0"
  done
fi

# ---- Add Negativo17 Fedora Multimedia repo ----
curl -fLsS --retry 5 \
    -o /etc/yum.repos.d/negativo17-fedora-multimedia.repo \
    https://negativo17.org/repos/fedora-multimedia.repo

# ---- Install build dependencies & akmods ----
echo "Installing build dependencies and akmods for kernel ${KERNEL_VERSION}"
dnf --refresh install -y --setopt=install_weak_deps=False \
    "kernel-devel-matched-$(rpm -q kernel --queryformat '%{VERSION}')"
dnf install -y --setopt=install_weak_deps=False akmods gcc-c++

# ---- Monkey-patch akmodsbuild (workaround) ----
cp /usr/sbin/akmodsbuild /usr/sbin/akmodsbuild.backup
sed -i '/if \[\[ -w \/var \]\] ; then/,/fi/d' /usr/sbin/akmodsbuild

# ---- Install akmod-xpadneo & akmod-xone ----
dnf install -y --setopt=install_weak_deps=False \
    akmod-xpadneo akmod-xone

# ---- Build kernel modules ----
echo "Building xpadneo & xone modules for kernel ${KERNEL_VERSION}"
akmods --force --kernels "${KERNEL_VERSION}" --kmod xpadneo
akmods --force --kernels "${KERNEL_VERSION}" --kmod xone

# ---- Restore akmodsbuild ----
mv /usr/sbin/akmodsbuild.backup /usr/sbin/akmodsbuild

# ---- Module verification function ----
fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for DIR in "$XPAD_MODULE_DIR" "$XONE_MODULE_DIR"; do
  [[ -d "$DIR" ]] || fail "Module directory missing: $DIR"

  shopt -s nullglob
  MODULES=("$DIR"/*.ko*)
  shopt -u nullglob
  [[ ${#MODULES[@]} -gt 0 ]] || fail "No modules built in $DIR"

  echo "Modules in $DIR: ${#MODULES[@]}"
  for m in "${MODULES[@]}"; do
    echo "  - $(basename "$m")"
  done

  modinfo "$DIR"/*.ko* > /dev/null || fail "modinfo check failed for $DIR"
done

# ---- Sign modules ----
mkdir -p "$WORKDIR"
chmod 700 "$WORKDIR"

openssl x509 -in "$PUBLIC_KEY_DER" -out "$PUBLIC_KEY_CRT"
openssl pkey -in "$PRIVATE_KEY_PEM" -out "$PRIVATE_KEY_PRIV"
chmod 600 "$PRIVATE_KEY_PRIV"

cat "$PRIVATE_KEY_PRIV" <(echo) "$PUBLIC_KEY_CRT" > "$SIGNING_KEY"
chmod 600 "$SIGNING_KEY"

for DIR in "$XPAD_MODULE_DIR" "$XONE_MODULE_DIR"; do
  shopt -s nullglob
  MODULES=("$DIR"/*.ko*)
  shopt -u nullglob
  [[ ${#MODULES[@]} -gt 0 ]] || continue

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
done

echo "== xpadneo & xone module signing COMPLETE =="

# ---- Cleanup: remove akmods & build deps ----
dnf remove -y akmod-xpadneo akmod-xone akmods kernel-devel kernel-headers gcc-c++

# ---- Remove added Negativo repo & restore original repos ----
rm -f /etc/yum.repos.d/negativo17-fedora-multimedia.repo

if [[ -f "$REPO_SNAPSHOT" ]]; then
  while read -r repo; do
    dnf config-manager setopt "${repo}.enabled=1" || true
  done < "$REPO_SNAPSHOT"
  rm -f "$REPO_SNAPSHOT"
fi

# ---- DNF Cleanup ----
dnf clean all
dnf autoremove -y
dnf clean packages

echo "== akmod-xpadneo & akmod-xone installation, signing, and verification COMPLETE =="