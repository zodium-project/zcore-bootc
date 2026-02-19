#!/usr/bin/env bash
set -euo pipefail

echo "== NVIDIA module & signing key detection =="

KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
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
