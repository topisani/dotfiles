#!/bin/bash

setxkbmap dk nodeadkeys -option ctrl:nocaps

killall compton
compton &
pgrep pa-applet || pa-applet &
pgrep nm-applet || nm-applet &
pgrep tilda || tilda &
