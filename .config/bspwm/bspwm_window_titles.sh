#!/usr/bin/env bash

icon_map=$( cat "$( dirname "$( readlink -f "$0" )" )/bspwm_window_titles_icon_map.txt" )

mon_name=${1:-$MONITOR}

monitor=$(bspc query -M -m "$mon_name")

# subscribe to events on which the window title list will get updated
bspc subscribe node_focus node_remove desktop_focus | while read -r evt mon _; do
    [[ "$mon" != "$monitor" ]] && continue

    # get last focused desktop on given monitor
    last_focused_desktop=$( bspc query -D -m "$monitor" -d .active )

    # get windows from last focused desktop on given monitor
    winids_on_desktop=$( bspc query -N -n .window -m "$monitor" -d "$last_focused_desktop" )

    # get number of windows on desktop
    number_of_windows=$( printf "$winids_on_desktop" | tr '\n' ' ' | wc -w  )

    # get a list of all windows
    # replace all spaces and tabs with single spaces for easier cutting
    winlist=$( wmctrl -l -x | tr -s '[:blank:]' )

    for window_id in $winids_on_desktop; do
        window=$( echo "$winlist" | grep -i "$window_id")
        # get window name
        window_name=$( echo "$window" | cut -d " " -f 5- )
        # longer window titles if there is only one window
        [[ "$number_of_windows" == "1" ]] && char_cut="40" || char_cut="20"
        # cut the window name
        window_name_short=$( echo "$window_name" | cut -c1-"$char_cut" )

        # get window class and match after a dot to get app name
        window_class=$( echo "$window" | cut -d " " -f 3 | sed 's/.*\.//')

        focused=$(bspc query -N -n focused)

        # if window id matched with list == not empty
        if [[ -n "$window_name" ]]; then

            # trim window name
            window_name=$( echo "$window_name_short" | sed -e 's/^[[:space:]]*//' )

            # get icon for class name
            window_icon=$( grep "$window_class" <<< "$icon_map" | cut -d " " -f2 )

            # fallback icon if class not found
            if [[ -z "$window_icon" ]]; then
                window_icon=$( grep "Fallback" <<< "$icon_map" | cut -d " " -f2 )
            fi

            # join icon and name
            window_name_with_icon="${window_icon} ${window_name}"

            # wrap window name in square brackets if it's active
            [[ "$window_id" == "$focused" ]] && curr_wins+="%{R} ${window_name_with_icon} %{R}" || curr_wins+="%{A1:bspc node -f $window_id:} ${window_name_with_icon} %{A}"

        fi
    done

    # don't print names if there is only one
    # turned on with 'nomonocle'
    #if [[ "$1" == "nomonocle" ]]; then
        #[[ "$number_of_windows" == "1" ]] && windows_print="" || windows_print="$curr_wins"
    #else
        windows_print="$curr_wins"
    #fi

    # print out the window names to files for use in a bar
    echo "$windows_print"
    unset curr_wins

done
