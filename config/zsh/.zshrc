# base config for oh my zsh

export ZSH="/home/topisani/.oh-my-zsh"

plugins=(
  git
  zsh-autosuggestions
)
source $ZSH/oh-my-zsh.sh

export TMPDIR="/tmp"

# user-defined overrides
[ -d ~/.config/zsh/config.d/ ] && source ~/.config/zsh/config.d/*

# Fix for foot terminfo not installed on most servers
alias ssh="TERM=xterm-256color ssh"

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
source <(kitty + complete setup zsh)
