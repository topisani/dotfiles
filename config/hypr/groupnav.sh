#! /bin/sh

is_first() {
    hyprctl activewindow -j | jq -e ".address == .grouped[0] or .grouped == []" 
}

is_last() {
    hyprctl activewindow -j | jq -e ".address == .grouped[-1] or .grouped == []" 
}

bar_format() {
    export MONITOR_FILT=${1:-$WAYBAR_MONITOR}
    if [ -z "$MONITOR_FILT" ]; then
        MONITOR_FILT=$(hyprctl activeworkspace -j | jq -r ".monitor")
    fi
    # Waybar custom module
    (hyprctl monitors -j; hyprctl workspaces -j; hyprctl clients -j) | jq --unbuffered --compact-output '
    . as $monitors | input as $workspaces | input as $clients 
        | $monitors | map(select(.name == $ENV.MONITOR_FILT))[0] | .activeWorkspace.id as $ws
        | $workspaces | map(select(.id == $ws))[0] | .lastwindow as $active_addr
        | $clients | map(select(.address == $active_addr))[0] as $active
        | ( if $active == null then 
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
        bar_format "$@"
        socat -U - UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do bar_format "$@"; done
    done 2> /dev/null
}

cmd=$1; shift

case "$cmd" in
    move)
        case "$1" in
            l)
                if ! is_first; then
                    hyprctl dispatch movegroupwindow b
                else
                    hyprctl dispatch movewindoworgroup l
                fi
                ;;
            r)
                if ! is_last; then
                    hyprctl dispatch movegroupwindow f
                else
                    hyprctl dispatch movewindoworgroup r
                fi
                ;;
            u)
                hyprctl dispatch movewindoworgroup u
                ;;
            d)
                hyprctl dispatch movewindoworgroup d
                ;;
        esac
        ;;
    focus)
        case "$1" in
            l)
                if ! is_first; then
                    hyprctl dispatch changegroupactive b
                else
                    hyprctl dispatch movefocus l
                fi
                ;;
            r)
                if ! is_last; then
                    hyprctl dispatch changegroupactive f
                else
                    hyprctl dispatch movefocus r
                fi
                ;;
            u)
                hyprctl dispatch movefocus u
                ;;
            d)
                hyprctl dispatch movefocus d
                ;;
        esac
        ;;
    group)
        case "$cmd" in
            f)
                is_last || hyprctl dispatch changegroupactive f
                ;;
                
            b)
                is_first || hyprctl dispatch changegroupactive b       
                ;;
        esac
        ;;
    bar)
        bar "$@"
        ;;
    bar-fmt)
        bar_format "$@"
        ;;
esac
