map_mode() {
  mode=$1; shift
  key=$1; shift
  command=$1; shift
  docstring=$command
  run=": $command<ret>"
  scope="global"
  repeat=''
  [ "$1" = "${1#-}" ] && docstring=$1 && shift
  while [ $# != 0 ]; do
    case $1 in
      -scope)
        shift
        scope="$1"
        ;;
      -raw)
        run=$command
        ;;
      -sh)
        run=":nop %sh{$command}<ret>"
        ;;
      -repeat)
        repeat=${repeat:-": enter-user-mode $mode<ret>"}
        ;;
      -norepeat)
        repeat=":nop<ret>"
    esac
    shift
  done
  echo "map $scope $mode "\'$key\'" %{$run$repeat} -docstring %{$docstring}"
}

map_all() {
  mode=$1; shift
  flags=''
  while [ $# > 1 ]; do
    flags="$flags $1"; shift
  done
  while read line; do
  	[ -n "$line" ] || continue
  	echo map-mode $mode "$line" $flags
  done <<< "$1"
}

new_mode() {
  name=$1; shift
  key=${1:-}; [ $# != 0 ] && shift
  docstring="$name..."
  parent="user"
  scope="global"
  while ! [ $# == 0 ] && ! [ "$1" = "${1#-}" ]; do
    case $1 in
      -scope)
        shift
        scope=$1
        ;;
      -docstring)
        shift
        docstring=$1
        ;;
      -parent)
        shift
        parent=$1
        ;;
    esac
    shift
  done
  echo declare-user-mode $name
  [ -n "$key" ] && echo map $scope $parent $key %{: enter-user-mode $name\<ret\>} -docstring %{$docstring}
  [ $# != 0 ] && map_all $name -scope $scope "$*"
}
