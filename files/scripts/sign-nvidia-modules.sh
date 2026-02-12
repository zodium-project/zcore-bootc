#!/usr/bin/env bash
set -euo pipefail
set -x

echo "== NVIDIA module signing =="

KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
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
