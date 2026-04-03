#!/usr/bin/env bash
# ================================================================
#  Docker CE — Container engine install script
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
say "${MAGENTA}${BOLD}║   ◈  Docker CE Installer          ◈      ║${NC}"
say "${MAGENTA}${BOLD}║   docker-ce · containerd · compose       ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""

# ── Add Docker CE Repository ──────────────────────────────────
info "Adding Docker CE repo..."

dnf config-manager addrepo \
    --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
dnf config-manager setopt docker-ce-stable.enabled=1
dnf config-manager setopt docker-ce-stable.priority=90
dnf --refresh makecache

ok "Docker CE repo added"

# ── Docker CE Packages ────────────────────────────────────────
DOCKER_PKGS=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
)

info "Installing Docker CE and plugins..."
for pkg in "${DOCKER_PKGS[@]}"; do
    say "  ${CYAN}◈${NC}  ${pkg}"
done

dnf install -y --setopt=install_weak_deps=False \
    "${DOCKER_PKGS[@]}"

ok "Docker CE packages installed"

# ── Enable Services ───────────────────────────────────────────
info "Enabling Docker and containerd services..."
systemctl enable docker.service
systemctl enable containerd.service
ok "Services enabled"

# ── DNF Cleanup ───────────────────────────────────────────────
info "Running DNF cleanup..."
dnf config-manager setopt docker-ce-stable.enabled=0
rm -f /etc/yum.repos.d/docker-ce.repo
dnf clean all
dnf autoremove -y
dnf clean packages
ok "Cleanup complete"

# ── Done ──────────────────────────────────────────────────────
say ""
say "${MAGENTA}${BOLD}╔══════════════════════════════════════════╗${NC}"
say "${MAGENTA}${BOLD}║   ◆  Docker CE Install Complete          ║${NC}"
say "${MAGENTA}${BOLD}╚══════════════════════════════════════════╝${NC}"
say ""