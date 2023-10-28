#! /bin/sh

is_first() {
    hyprctl activewindow -j | jq -e ".address == .grouped[0] or .grouped == []" 
}

is_last() {
    hyprctl activewindow -j | jq -e ".address == .grouped[-1] or .grouped == []" 
}

bar_format() {
    # Waybar custom module
    (hyprctl activewindow -j; hyprctl clients -j) | jq --unbuffered --compact-output '
    . as $active | input as $clients 
        | ( if $active == {} then 
                ""
            else
                $active.grouped 
                | ( if . == [] then
                        $active.title
                    else 
                        . | map(. as $id | $clients | map(select(.address == $id))[0])
                        | map(.active = (.address == $active.address)) 
                        | map((if .active then 
                                "<span>" + .title + "</span>" 
                            else 
                                "<span foreground=\"gray\">" + .title + "</span>" 
                            end))
                        | join("   ")
                    end)
            end)
        | {"text": .}
    '
}

bar() {
    while : ; do
        bar_format
        socat -U - UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do bar_format; done
    done 2> /dev/null
}

case "$*" in
    "move l")
        if ! is_first; then
            hyprctl dispatch movegroupwindow b
        else
            hyprctl dispatch movewindoworgroup l
        fi
        ;;
    "move r")
        if ! is_last; then
            hyprctl dispatch movegroupwindow f
        else
            hyprctl dispatch movewindoworgroup r
        fi
        ;;
    "focus l")
        if ! is_first; then
            hyprctl dispatch changegroupactive b
        else
            hyprctl dispatch movefocus l
        fi
        ;;
    "focus r")
        if ! is_last; then
            hyprctl dispatch changegroupactive f
        else
            hyprctl dispatch movefocus r
        fi
        ;;
    "focus u")
        hyprctl dispatch movefocus u
        ;;
    "focus d")
        hyprctl dispatch movefocus d
        ;;
    "move u")
        hyprctl dispatch movewindoworgroup u
        ;;
    "move d")
        hyprctl dispatch movewindoworgroup d
        ;;
    
    "group f")
        is_last || hyprctl dispatch changegroupactive f
        ;;
        
    "group b")
        is_first || hyprctl dispatch changegroupactive b       
        ;;
        
    "bar")
        bar
        ;;
    "bar-fmt")
        bar_format
        ;;
esac
