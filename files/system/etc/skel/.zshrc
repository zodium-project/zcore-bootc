## User Zsh settings ( confiure zsh here) ##

HISTFILE=~/.zsh_history
HISTSIZE=1250
SAVEHIST=1250
bindkey -e
setopt AUTO_CD
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