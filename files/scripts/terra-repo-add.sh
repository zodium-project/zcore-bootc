#!/usr/bin/env bash

set -oue pipefail

echo 'this is terra repo setup script'
dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release -y
dnf upgrade --refresh -y
dnf reinstall --refresh -y terra-release
dnf upgrade --refresh -y
echo 'terra repo setup script completed'