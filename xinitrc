#!/bin/bash

export LANG="en_DK.UTF-8"
source /etc/profile.d/locale.sh

# Set cursor from X to pointer
xrdb ~/.Xresources
setxkbmap dk nodeadkeys -option ctrl:nocaps

xsetroot -cursor_name left_ptr &

# wmutils
# $HOME/.bin/wm/autostart
# exec $HOME/.bin/xwait 

# windowchef
export WM_SCRIPT_DIR=$HOME/.config/windowchef/scripts
export WM_TMP_DIR=/tmp/windowchef_$(whoami)_$DISPLAY

logged_windowchef() {
   windowchef &> $HOME/windowchef.log
}

${WM:-logged_windowchef}

pid_file=$WM_TMP_DIR/pids

if [[ -f $pid_file ]]; then
   while read pid; do
       kill $pid
   done < $pid_file
   :> $pid_file
fi
