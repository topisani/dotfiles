#!/bin/bash
export USING_X11=true
export LANG="en_DK.UTF-8"
export QT_QPA_PLATFORMTHEME=qt5ct
source /etc/profile.d/locale.sh

# Set cursor from X to pointer
xrdb ~/.Xresources
setxkbmap dk nodeadkeys -option ctrl:nocaps -option compose:rctrl
xinput disable $(xinput | grep "Wacom HID 5113 Finger" | grep -oP 'id=\K\d+')
xinput set-prop $(xinput | grep SYNA | grep Touchpad | grep -oP 'id=\K\d+') 'libinput Natural Scrolling Enabled' 1

xsetroot -cursor_name left_ptr &

# wmutils
# $HOME/.bin/wm/autostart
# exec $HOME/.bin/xwait 

# windowchef
export WM_SCRIPT_DIR=$HOME/.bin/wm
export WM_TMP_DIR=/tmp/wm_$(whoami)_$DISPLAY

#logged_windowchef() {
   #windowchef &> $HOME/windowchef.log
#}
# 
# ${WM:-logged_windowchef}
# 
# pid_file=$WM_TMP_DIR/pids
# 
# if [[ -f $pid_file ]]; then
#    while read pid; do
#        kill $pid
#    done < $pid_file
#    :> $pid_file
# fi
xset r rate 600 25
#i3 &> i3.log
bspwm
