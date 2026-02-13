#!/usr/bin/env bash

# Zodium Project
# Built with BlueBuild (Fedora ostree / bootc)

set -oue pipefail
## temporary remove -x after debugging ##
set -x

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
dnf install -y --allowerasing \
  https://negativo17.org/repos/nvidia/fedora-43/x86_64/akmod-nvidia-590.48.01-1.fc43.x86_64.rpm
############# Remove it later when the issue is resolved upstream #############

echo "Installing kmod..."
akmods --force --kernels "${KERNEL_VERSION}" --kmod nvidia

modinfo /usr/lib/modules/${KERNEL_VERSION}/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz \
    > /dev/null || (cat /var/cache/akmods/nvidia/*.failed.log && exit 1)

modinfo -l /usr/lib/modules/${KERNEL_VERSION}/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz
