#!/usr/bin/env bash
set -euo pipefail
set -x

dnf install \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

dnf install \
  rpmfusion-free-release-tainted \
  rpmfusion-nonfree-release-tainted

dnf check-upgrade

#### a backup for bling module ###