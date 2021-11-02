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

# Paru in the correct order
alias paru='paru --bottomup'

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

alias st=subterranean

export EDITOR='kak'
export FZF_DEFAULT_OPTS='--multi --layout=reverse --preview-window=down:60% --color=16'

# Change the current directory for a tmux session, which determines
# the starting dir for new windows/panes:
function tmux-cwd {
  tmux command-prompt -I $PWD -p "New session dir:" "attach -c %1"
}

alias tcd='tmux-cwd'

# Projects
function ottobsp {
  cd ~/src/otto-bsp/
  source setup-environment build
  cd workspace/sources/otto-core
}

alias ghcup='TMPDIR=$HOME/.ghcup/tmp ghcup'
alias ssh="TERM=xterm-256color ssh"
alias tb="nc termbin.com 9999"
alias termbin="nc termbin.com 9999"

# Call less if there is only one argument and it is a filename. Otherwise, call ls
less_or_ls() {
    ([ "$#" -eq "1" ] && [ -f "$1" ] && bat $@ ) || ls $@
}
alias ls=less_or_ls

mkcd() {
    mkdir -p "$@"
    cd "$@"
}

# Calculator
calc() {
    local IFS=' '
    bc -l <<<"scale=10;$@"
}
