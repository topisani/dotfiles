#!/bin/sh

if ! [ -e "$NIRI_SOCKET" ]; then
    echo "NIRI_SOCKET not set" > /dev/stderr
    exit 1
fi

NMARK_FILE=${NIRI_SOCKET%%.sock}.marks.list

nmark::read() {
    marks=$(cat $NMARK_FILE 2> /dev/null)
    empty="{}"
    echo "${marks:-$empty}"
}

nmark::list() {
    # Get windows data safely
    windows_data=$(niri msg -j windows)
    if [ $? -ne 0 ] || [ -z "$windows_data" ]; then
        echo "Error: Failed to get windows from niri" >&2
        exit 1
    fi

    marks_data=$(nmark::read)

    marks=$(jq -n --argjson windows "$windows_data" --argjson marks "$marks_data" '
        reduce ($marks | to_entries[]) as $mark (
            {};
            .[$mark.key] = ($windows[] | select(.id == $mark.value))
        )
    ')
    echo "$marks"
}

nmark::set() {
    key=$1
    window=$2
    [ -n "$window" ] || window=$(niri msg -j focused-window | jq -r .id)

    # Update the marks file
    nmark::read | jq --arg key "$key" --arg window "$window" '.[$key] = ($window | tonumber)' > "$NMARK_FILE"
    echo "Set mark $key to window $window"
}

nmark::focus() {
    key=$1
    if [ -z "$key" ]; then
        echo "Usage: focus <key>" >&2
        exit 1
    fi

    window_id=$(nmark::read | jq -r --arg key "$key" '.[$key] // empty')
    if [ -n "$window_id" ]; then
        niri msg action focus-window --id "$window_id"
        echo "Focused window with mark $key"
    else
        echo "Mark $key not found" >&2
        exit 1
    fi
}


nmark::get() {
    window=$1
    [ -n "$window" ] || window=$(niri msg -j focused-window | jq -r .id)

    if [ -z "$window" ] || [ "$window" = "null" ]; then
        echo "Error: No window specified and no focused window found" >&2
        exit 1
    fi

    marks=$(nmark::read | jq -r --arg window "$window" '
        to_entries | map(select(.value == ($window | tonumber))) | map(.key) | join(" ")
    ')

    if [ -n "$marks" ]; then
        echo "$marks"
    else
        echo "No marks found for window $window" >&2
        exit 1
    fi
}

nmark::usage() {
    cat <<EOF
Usage:
  $0 set <key> [window]: 	Set the window with the given id or the active window to mark <key>
  $0 focus <key>: 			Focus the window marked with <key>
  $0 get [window]:			Get marks for the given window id or the active window
  $0 list: 					list marked windows as json
EOF
}

cmd=$1; shift
case $cmd in
    list)
        nmark::list "$@"
        ;;
    set)
        nmark::set "$@"
        ;;
    focus)
        nmark::focus "$@"
        ;;
    get)
        nmark::get "$@"
        ;;
    *)
        nmark::usage
        ;;
esac
