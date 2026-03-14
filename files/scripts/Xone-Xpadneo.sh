#!/usr/bin/env bash
# ================================================================
#  Xone-Xpadneo — akmod build & signing script for zcore
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
say "${MAGENTA}${BOLD}║   ◈  xpadneo & xone Installer  ◈         ║${NC}"
say "${MAGENTA}${BOLD}║   akmod build & signing for zcore        ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Make sure /var/tmp exists and is writable by all users ────
mkdir -p /var/tmp
chmod 1777 /var/tmp

# ── Variables & Paths ─────────────────────────────────────────
WORKDIR="/tmp/certs"
REPO_SNAPSHOT="/var/tmp/zodium-enabled-repos.txt"
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"

PUBLIC_KEY_DER="/etc/pki/akmods/certs/zodium-akmod.der"
PRIVATE_KEY_PEM="/tmp/certs/kernel_key.pem"

SIGNING_KEY="${WORKDIR}/signing_key.pem"
PUBLIC_KEY_CRT="${WORKDIR}/zodium-akmod.crt"
PRIVATE_KEY_PRIV="${WORKDIR}/private_key.priv"

SIGN_FILE="/usr/src/kernels/${KERNEL_VERSION}/scripts/sign-file"

XPAD_MODULE_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra/xpadneo"
XONE_MODULE_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra/xone"

# ── Disable External (Terra/RPMFusion) Repos ─────────────────
info "Snapshotting enabled repos..."
dnf repolist --enabled | awk 'NR>1 {print $1}' > "$REPO_SNAPSHOT"

mapfile -t SANDBOX_REPOS < <(
    dnf repolist --enabled | awk 'NR>1 {print $1}' | grep -Ei '^(terra|rpmfusion)'
)

if (( ${#SANDBOX_REPOS[@]} > 0 )); then
    info "Disabling external repos temporarily..."
    for repo in "${SANDBOX_REPOS[@]}"; do
        dnf config-manager setopt "${repo}.enabled=0"
    done
    ok "External repos disabled"
fi

# ── Add Negativo17 Fedora Multimedia Repo ─────────────────────
info "Adding Negativo17 Fedora Multimedia repo..."
curl -fLsS --retry 5 \
    -o /etc/yum.repos.d/negativo17-fedora-multimedia.repo \
    https://negativo17.org/repos/fedora-multimedia.repo
ok "Negativo17 repo added"

# ── Install Build Dependencies & akmods ───────────────────────
info "Installing build dependencies for kernel version: ${KERNEL_VERSION}..."
dnf install -y --setopt=install_weak_deps=False akmods gcc-c++

# ── Workaround Fix (monkey patch akmodsbuild) ─────────────────
warn "Applying akmodsbuild workaround..."
cp /usr/sbin/akmodsbuild /usr/sbin/akmodsbuild.backup
sed -i '/if \[\[ -w \/var \]\] ; then/,/fi/d' /usr/sbin/akmodsbuild

# ── Install akmod-xpadneo & akmod-xone ────────────────────────
dnf install -y --setopt=install_weak_deps=False \
    akmod-xpadneo akmod-xone

# ── Build Kernel Modules ──────────────────────────────────────
info "Building xpadneo kmod..."
akmods --force --kernels "${KERNEL_VERSION}" --kmod xpadneo

info "Building xone kmod..."
akmods --force --kernels "${KERNEL_VERSION}" --kmod xone

mv /usr/sbin/akmodsbuild.backup /usr/sbin/akmodsbuild
ok "akmodsbuild restored"

# ── Verify Modules ────────────────────────────────────────────
info "xpadneo & xone module detection..."

for DIR in "$XPAD_MODULE_DIR" "$XONE_MODULE_DIR"; do
    [[ -d "$DIR" ]] || fail "Module directory missing: $DIR"

    shopt -s nullglob
    MODULES=("$DIR"/*.ko*)
    shopt -u nullglob
    [[ ${#MODULES[@]} -gt 0 ]] || fail "No modules built in $DIR"

    ok "Modules found in $(basename "$DIR"): ${#MODULES[@]}"
    for m in "${MODULES[@]}"; do
        say "  ${CYAN}◈${NC}  $(basename "$m")"
    done

    modinfo "$DIR"/*.ko* > /dev/null || fail "modinfo check failed for $DIR"
done

ok "xpadneo & xone detection passed"

# ── Sign Modules ──────────────────────────────────────────────
info "Signing xpadneo & xone modules..."

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
done

ok "xpadneo & xone module signing complete"

# ── Remove Orphans/Useless Deps ───────────────────────────────
info "Removing build dependencies..."
dnf remove -y akmod-xpadneo akmod-xone akmods gcc-c++
ok "Build dependencies removed"

# ── Remove Added Repos ────────────────────────────────────────
info "Removing temporary repos..."
rm -f /etc/yum.repos.d/negativo17-fedora-multimedia.repo
ok "Temporary repos removed"

# ── Restore Repos (Terra/RPMFusion) ───────────────────────────
if [[ -f "$REPO_SNAPSHOT" ]]; then
    info "Restoring external repos..."
    while read -r repo; do
        dnf config-manager setopt "${repo}.enabled=1" || true
    done < "$REPO_SNAPSHOT"
    rm -f "$REPO_SNAPSHOT"
    ok "External repos restored"
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
say "${MAGENTA}${BOLD}║   ◆  xpadneo & xone Install Complete     ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""