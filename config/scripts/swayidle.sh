#!/bin/sh

swayidle -w \
    timeout 300 'brightnessctl -s 10' resume 'brightnessctl -r' \
    timeout 600 'loginctl lock-session' \
    timeout 660 'niri msg action power-off-monitors' \
    timeout 1800 'systemctl suspend' \
    before-sleep 'loginctl lock-session' \
    lock "$HOME/.bin/lockscreen" \
