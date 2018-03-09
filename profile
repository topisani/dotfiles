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
PATH="$HOME/.bin:$HOME/.local/bin:/usr/local/bin:$PATH"

PATH="$(ruby -rrubygems -e 'puts Gem.user_dir')/bin:$PATH"

# Kill the GNU
export CC=/usr/bin/clang
export CXX=/usr/bin/clang++


export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.cabal/bin:$PATH"
alias termbin="nc termbin.com 9999"

# Use gtk theme for qt
export QT_QPA_PLATFORMTHEME="qt5ct"

# Use GTK3 for mullvad - See comments https://aur.archlinux.org/packages/mullvad
# Needed to fix a wxpython issue
export MULLVAD_USE_GTK3=yes

# Auto make flags
export NUMCPUS=`grep -c '^processor' /proc/cpuinfo`
export MAKEFLAGS="-j$NUMCPUS --load-average=$NUMCPUS"
alias tb="nc termbin.com 9999"

export EDITOR=kak
export VISUAL=kak
