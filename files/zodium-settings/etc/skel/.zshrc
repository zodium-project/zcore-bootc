# ================================================================
#  ~/.zshrc — User Zsh configuration
#  Zodium Project : github.com/zodium-project
# ================================================================

# ── Note ──────────────────────────────────────────────────────
# Do not edit /etc/skel/.zshrc directly — it will be overwritten
# on update. Copy That file to ~/.zshrc if you want latest template
# and edit it there.

# Files in /etc like /etc/zshrc & /etc/zsh-zc-overrides are 
# system-wide configurations and you are not expected to edit /etc/zshrc &
# /etc/zsh-zc-overrides is only there to set/env that enable/disable features in /etc/zshrc

# ── History ───────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=1500
SAVEHIST=1500

# ── Keybindings ───────────────────────────────────────────────
bindkey -e

# ── Directory Navigation ──────────────────────────────────────
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# ── Correction ────────────────────────────────────────────────
setopt CORRECT

# ── Completion ────────────────────────────────────────────────
autoload -Uz compinit
compinit -C