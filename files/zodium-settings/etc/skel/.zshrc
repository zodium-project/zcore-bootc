## User Zsh settings ( confiure zsh here) ##
## Default zsh settings, you can override them by copying this file to ~/.zshrc and edit it there ##
## Dont edit file in /etc/skel/ directly, it will be overwritten on update, copy it to your home directory and edit there ##
HISTFILE=~/.zsh_history
HISTSIZE=1250
SAVEHIST=1250
bindkey -e
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt CORRECT
autoload -Uz compinit
compinit -C

# this is basic zsh-shell configuration with zodium tweaks/extras