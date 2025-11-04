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
export LESS="$LESS --mouse"

alias l='eza --group-directories-first -F'
alias ll='l -lh --git'
alias la='ll -a'
alias llg='ll --grid'
# alias cd='z'

export BAT_THEME=base16
alias bat='bat --style=plain'
# Fancy bat
alias fat='bat --style=full'

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

alias st=subterranean
alias j=just

alias ssh="TERM=xterm-256color ssh"

# Call less if there is only one argument and it is a filename. Otherwise, call ls
less_or_ls() {
    ([ "$#" -eq "1" ] && [ -f "$1" ] && bat "$@" ) || ls "$@"
}
alias ls=less_or_ls

function mkd() { [[ $# == 1 ]] && mkdir -p -- "$1" && cd -- "$1" }
compdef _directories mkd

# Calculator
calc() {
    local IFS=' '
    bc -l <<<"scale=10;$@"
}

git_release() {
    version=${1//v}; shift &> /dev/null
    if [ -z "$version" ]; then
      echo "Usage: $0 <version> [git tag options...]"
      return 1
    fi
    git tag -a v$version -m "Release $version" "$@" && echo "Created tag v$version"
}

alias grel=git_release

whichpkg() (
    set -e
    file=$(which $1)
    la "$file"
    pacman -Qo "$file"
)

alias mods='OPENAI_API_KEY=$(pass openai-api-key) mods'

function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}
