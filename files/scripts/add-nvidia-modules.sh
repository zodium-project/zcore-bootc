#!/usr/bin/env bash

# Zodium Project
# Built with BlueBuild (Fedora ostree / bootc)

set -oue pipefail

mkdir -p /var/tmp
chmod 1777 /var/tmp

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

KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora.%_arch')"

#curl -fLsS --retry 5 \
#    -o /etc/yum.repos.d/negativo17-fedora-multimedia.repo \
#    https://negativo17.org/repos/fedora-multimedia.repo

curl -fLsS --retry 5 \
    -o /etc/yum.repos.d/negativo17-fedora-nvidia.repo \
    https://negativo17.org/repos/fedora-nvidia.repo

echo "Installing kernel modules for kernel version: ${KERNEL_VERSION}"

dnf install -y --setopt=install_weak_deps=False \
    "kernel-devel-matched-$(rpm -q kernel --queryformat '%{VERSION}')"

dnf install -y --setopt=install_weak_deps=False akmods gcc-c++

cp /usr/sbin/akmodsbuild /usr/sbin/akmodsbuild.backup
# Temporary upstream workaround
sed -i '/if \[\[ -w \/var \]\] ; then/,/fi/d' /usr/sbin/akmodsbuild

dnf install -y --setopt=install_weak_deps=False \
    nvidia-kmod-common \
    nvidia-modprobe

mv /usr/sbin/akmodsbuild.backup /usr/sbin/akmodsbuild

###################### Emergency workaround , no need to keep it for long #######
echo "Patching nvidia-kmod spec file..."
SPEC_FILE="/usr/src/akmods/nvidia-kmod.latest"

if [ -f "$SPEC_FILE" ]; then
    if grep -q "mkdir -p _kmod_build" "$SPEC_FILE"; then
        echo "Spec file already patched, skipping..."
    else
        sed -i '/for kernel_version in/a mkdir -p _kmod_build_${kernel_version%%%%___*}' "$SPEC_FILE"
        echo "Spec file patched successfully"
    fi
else
    echo "WARNING: Spec file not found at $SPEC_FILE"
fi
############# Remove it later when the issue is resolved upstream #############

echo "Installing kmod..."
akmods --force --kernels "${KERNEL_VERSION}" --kmod nvidia

modinfo /usr/lib/modules/${KERNEL_VERSION}/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz \
    > /dev/null || (cat /var/cache/akmods/nvidia/*.failed.log && exit 1)

modinfo -l /usr/lib/modules/${KERNEL_VERSION}/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz
