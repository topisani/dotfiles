#!/bin/sh

export MONITOR_FILT=${1:-$WAYBAR_MONITOR}
if [ -z "$MONITOR_FILT" ]; then
    MONITOR_FILT=$(hyprctl activeworkspace -j | jq -r ".monitor")
fi
bar_format() {
    (hyprctl -j clients; hyprctl -j workspaces; hyprctl -j monitors) | jq --unbuffered --compact-output '
    {"text": (. as $clients
        | input as $workspaces
        | input as $monitors
        | $monitors | map(select(.name == $ENV.MONITOR_FILT))[0] | .activeWorkspace.id as $ws
        | $workspaces | map(select(.id == $ws))[0] | .lastwindow as $focused_addr
        | ($clients[] | select(.address == $focused_addr)) as $focused
        | [$clients[] | select(.workspace.id == $focused.workspace.id)]
            | group_by(.at[0])
            | map(sort_by(.at[1])) as $columns
        | ($columns | map(map(.address)) | to_entries | map(select(.value | contains([$focused_addr]))) | .[0].key) as $focused_col_idx
        # | {
        #     "1": "•"
        #     # "1": "·",
        #     # "2": ":",
        #     # "3": "⁝",
        #     # "4": "⋮"
        # } as $box_chars
        | ([$columns[:$focused_col_idx][], $focused.title, $columns[$focused_col_idx + 1:][]]
              | map(if type == "string" then
                  if length > 80 then .[:77] + "..." else . end
                  | @html
                else
                  "<span foreground=\"gray\" weight=\"heavy\"> • </span>"
                  # (length as $count | "<span foreground=\"gray\" weight=\"heavy\"> \($box_chars[$count | tostring] // $box_chars["1"]) </span>")
                end)
          )
        | join(" ")
        ) // ""
    }
    '
}

while : ; do
    set -ex
    (echo "go" && socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock) \
        | while read -r line; do bar_format "$@"; done
done 2> /dev/null
