#!/bin/bash
# Save this as ~/.config/waybar/scripts/hyprsunset.sh
# Make it executable: chmod +x ~/.config/waybar/scripts/hyprsunset.sh

get_status() {
    if systemctl --user is-active --quiet hyprsunset.service; then
        temp=$(hyprctl hyprsunset temperature 2>/dev/null | grep -oP '\d+' || echo "N/A")
        echo "{\"text\": \" \", \"tooltip\": \"Hyprsunset: Active\\nTemperature: ${temp}K\", \"class\": \"active\"}"
    else
        echo '{"text": "<span foreground=\"gray\"> </span>", "tooltip": "Hyprsunset: Inactive", "class": "inactive"}'
    fi # 󰖨
}

toggle_service() {
    if systemctl --user is-active --quiet hyprsunset.service; then
        systemctl --user stop hyprsunset.service
    else
        systemctl --user start hyprsunset.service
    fi
}


adjust_temperature() {
    if systemctl --user is-active --quiet hyprsunset.service; then
        current=$(hyprctl hyprsunset temperature 2>/dev/null | grep -oP '\d+')
        if [ -n "$current" ]; then
            case "$1" in
                up)
                    new=$((current + 100))
                    [ $new -gt 6500 ] && new=6500
                    ;;
                down)
                    new=$((current - 100))
                    [ $new -lt 1000 ] && new=1000
                    ;;
            esac
            hyprctl hyprsunset temperature $new
        fi
    fi
}

case "$1" in
    toggle)
        toggle_service
        ;;
    up)
        adjust_temperature up
        ;;
    down)
        adjust_temperature down
        ;;
    *)
        get_status
        ;;
esac
