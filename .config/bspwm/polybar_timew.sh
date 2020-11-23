#!/bin/bash

action=${1:-status}

xrdb_col() {
  xrdb -query | grep -oP "color$1:\\h+\\K.*"
}

if [[ $action == "status" ]]; then
  if ! timew >> /dev/null; then
    echo "%{B$(xrdb_col 4)}%{A1:$0 start:}  %{A}%{B-}"
  else
    tags=$(timew | grep -oP "^Tracking\\h+\\K.*")
    time=$(timew | grep -oP "^  Total +\\K.*" | cut -d: -f1,2)
    echo "%{B$(xrdb_col 4)}%{A1:timew stop:}  $tags $time %{A}%{B-}"
  fi
elif [[ $action == "start" ]]; then
  tag=$(timew tags | sed '1,3d;/^$/d' | cut -d' ' -f1 | rofi -dmenu -p "timew start")
  [[ $? != 0 ]] && exit 0
  timew start $tag
fi
