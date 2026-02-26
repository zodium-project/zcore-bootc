#!/usr/bin/env bash

# Zodium Project

set -oue pipefail

mkdir -p /var/tmp
chmod 1777 /var/tmp

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
dnf clean all
dnf autoremove -y
dnf5 clean packages