#!/bin/sh

# Usage:
# tabc.sh <tabbed-id> <command>
# Commands:
#    add <window-id> 	- Add window to tabbed
#    remove <window-id> - Remove window from tabbed
#    list		- List all clients of tabbed

TABBED_CONFIG="-c -k -o #18191c -O #fcfefb -t #005973 -T #fcfefb"
#
# Functions
#

# Get wid of root window
get_root_wid () {
	xwininfo -root | awk '/Window id:/{print $4}'
}

# Get children of tabbed
get_clients () {
	id=$1
	xwininfo -id $id -children | sed -n '/[0-9]\+ \(child\|children\):/,$s/ \+\(0x[0-9a-z]\+\).*/\1/p'
}

# Get class of a wid
get_class () {
	id=$1
	xprop -id $id | sed -n '/WM_CLASS/s/.*, "\(.*\)"/\1/p'
}

is_tabbed () {
  test "$(get_class $1)" == "tabbed"
}

#
# Main Program
#

tabbed=$1; shift
cmd=$1; shift
wid=$1
if ! is_tabbed $tabbed; then
	# It looks like what supposed to be an id of a tabbed window is not a
	# tabbed.
	if [ $cmd = "add" ]; then
  	if is_tabbed $wid; then
    	tmp=$wid
    	wid=$tabbed
    	tabbed=$tmp
    else
  		# But this is the `add` command so lets join booth windows in a
  		# new tabbed instance. First start tabbed, add the target window
  		# and then proceed to normal `add`.
  		sibling=$tabbed
  		tabbed=$(tabbed $TABBED_CONFIG -d) && xdotool windowreparent $sibling $tabbed || exit 2
		fi
	else
		# For other commands we need tunning tabbed instance
		echo "$tabbed is not an instance of tabbed"
		exit 1
	fi
fi

add_window() {
  wid=$1
  if is_tabbed $wid; then
    xdotool windowreparent $(get_clients $wid | head -1) $(get_root_wid)
    if [[ $(get_clients $wid | wc -l) == 1 ]]; then
      xdotool windowreparent $(get_clients $wid | head -1) $(get_root_wid)
    fi
  else
    xdotool windowreparent $wid $tabbed
  fi
}

case $cmd in
	add)
		add_window $wid
		;;
	remove)
		# When there isn't supplied an id of a window to be removed
		# from tabbed then remove the currently active one.
		test -n "$win" || wid=$(get_clients $tabbed | head -1)
		xdotool windowreparent $wid $(get_root_wid)
		;;
	list)
		get_clients $tabbed
		;;
esac

if [[ $(get_clients $tabbed | wc -l) == 1 ]]; then
  xdotool windowreparent $(get_clients $tabbed | head -1) $(get_root_wid)
fi
