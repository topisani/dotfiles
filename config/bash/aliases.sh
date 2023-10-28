# Enable colors by default 
alias ls='ls --color=auto'
alias grep='grep --colour=auto'
alias egrep='egrep --colour=auto'
alias fgrep='fgrep --colour=auto'

# General
alias cp="cp -i"                          # confirm before overwriting something
alias df='df -h'                          # human-readable sizes
alias du='du -h'
alias free='free -m'                      # show sizes in MB
alias np='nano -w PKGBUILD'
alias more=less

alias l='exa --group-directories-first -F'
alias ll='l -lh --git'
alias la='ll -a'
alias llg='ll --grid'
# alias cd='z'

export BAT_THEME=base16
alias cat=bat

# Directory stack
cd()
{
  if [ $# -eq 0 ]; then
    DIR="${HOME}"
  else
    DIR="$1"
  fi

  builtin pushd "${DIR}" > /dev/null
}
alias pushd='pushd > /dev/null'
alias pud=pushd
alias popd='popd > /dev/null'
alias dirs='dirs -p'

function mkcd {
  mkdir -p "$1"
  cd "$1"
}

# https://github.com/alexherbo2/kakoune.cr
alias kcr-tmux="kcr env | jq -r 'to_entries[] | \"tmux setenv \(.key) \(.value)\"' | sh"
alias k='krc edit'
alias K='krc-fzf-shell'
alias KK='K --working-directory .'
alias ks='kcr shell --session'
alias kl='kcr list'
alias a='kcr attach'
#alias :='kcr send'
#alias :br='KK broot'
#alias :cat='kcr cat --raw'

# Change the current directory for a tmux session, which determines
# the starting dir for new windows/panes:
function tmux_cwd {
  tmux command-prompt -I $PWD -p "New session dir:" "attach -c %1"
}

alias tcd='tmux-cwd'

# Tools
alias j=just
alias st=subterranean

# Projects
function ottobsp {
  cd ~/src/otto-bsp/
  source setup-environment build
  cd workspace/sources/otto-core
}
