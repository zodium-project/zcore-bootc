# ==============================================================
#  ~/.zshrc — User Zsh configuration
#  Zodium Project : github.com/zodium-project
# ==============================================================

# ── History ───────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=3000
SAVEHIST=3000

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