# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin directories
PATH="$HOME/.bin:$HOME/.local/bin:/usr/local/bin:$HOME/.composer/vendor/bin:$PATH"
PATH="$HOME/dev/flutter/bin:$PATH"

PATH="$(ruby -rrubygems -e 'puts Gem.user_dir')/bin:$PATH"

# Kill the GNU
export CC=/usr/bin/clang
export CXX=/usr/bin/clang++


export PATH="$HOME/.cargo/bin:$PATH"
alias termbin="nc termbin.com 9999"

# Auto make flags
export NUMCPUS=`grep -c '^processor' /proc/cpuinfo`
export MAKEFLAGS="-j$NUMCPUS --load-average=$NUMCPUS"
alias tb="nc termbin.com 9999"
alias cht="cht.sh"

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

export EDITOR=kak
export VISUAL=kak
export TERMINAL=tmux-term

# Colors
default=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
purple=$(tput setaf 5)
orange=$(tput setaf 9)

# Less colors for man pages
export PAGER=less
# Begin blinking
export LESS_TERMCAP_mb=$red
# Begin bold
export LESS_TERMCAP_md=$orange
# End mode
export LESS_TERMCAP_me=$default
# End standout-mode
export LESS_TERMCAP_se=$default
# Begin standout-mode - info box
export LESS_TERMCAP_so=$purple
# End underline
export LESS_TERMCAP_ue=$default
# Begin underline
export LESS_TERMCAP_us=$green

SSH_ENV="$HOME/.ssh/environment"

function start_agent {
    echo "Initialising new SSH agent..."
    /usr/bin/ssh-agent | sed 's/^echo/#echo/' > "${SSH_ENV}"
    echo succeeded
    chmod 600 "${SSH_ENV}"
    . "${SSH_ENV}" > /dev/null
    /usr/bin/ssh-add;
}

export DOT_REPO="https://github.com/topisani/dotfiles.git"
export DOT_DIR="$HOME/.dotfiles"
fpath=($HOME/.zsh/dot $fpath)  # <- for completion
source $HOME/.zsh/dot/dot.sh

export PATH="$PATH:/usr/lib/dart/bin"
export PATH="$PATH:$HOME/dev/flutter/.pub-cache/bin"
export PATH="$HOME/.ghcup/bin:$PATH"
alias ghcup='TMPDIR=$HOME/.ghcup/tmp ghcup'
alias ssh="TERM=xterm-256color ssh"
alias google-chrome="google-chrome --force-dark-mode"


if [[ ! $DISPLAY && $XDG_VTNR -eq 1 ]]; then
  #export USING_X11=false
  #sway-start &
  #gnome-shell
  exec startx
else 
    # Source SSH settings, if applicable
    if [ -f "${SSH_ENV}" ]; then
        . "${SSH_ENV}" > /dev/null
        ps ${SSH_AGENT_PID} > /dev/null || {
          echo "starting ssh agent"
            start_agent;
        }
    else
          echo "starting ssh agent"
        start_agent;
    fi
fi

# Start fish
if [ -z "$BASH_EXECUTION_STRING" ] && [ -z "$NO_FISH" ]&& [[ $(ps --no-header --pid=$PPID --format=cmd) != "fish" ]]; then
  exec fish
fi

# vim: ft=sh
