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
export DISABLE_ZSH_AUTOSUGGESTIONS=1

## to override system default plugins/alias use ENV-variables ##
# export DISABLE_ZSH_SYNTAX_HIGHLIGHTING=1
# export DISABLE_STARSHIP=1
# export DISABLE_ZOXIDE=1
# export DISABLE_EZA_ALIASES=1
# export DISABLE_ZOXIDE_CD=1
# export DISABLE_FD_ALIAS=1