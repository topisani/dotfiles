# Util functions

provide-module -override my-utils %{

  def repl-ask %{
      prompt "Run:" 'repl "confirm-exit %val{text}"'
  }

  # Define user mode

  def new-mode -params 1.. -docstring \
  "new-mode <name> [key] [flags..] [body]: Declare a new user mode
  options:
      <name>: Name of mode.
      [key]: If provided, this key will be mapped to enter the mode.
      [body]: sent to map-all'.
  flags:
      -scope to register keybinds in.
      -docstring <str>: Docstring for keybind. Defaults to '<name>...'
      -parent <mode>: Mode to register keybinding in. Defaults to 'user'" \
  %{ eval %sh{
      name=$1; shift
      key=${1:-}; shift
      docstring="$name..."
      parent="user"
      scope="global"
      while [[ ! $# == 0 ]] && [[ "$1" =~ "^-" ]]; do
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
      [[ -n "$key" ]] && echo map $scope $parent $key %{:enter-user-mode $name\<ret\>} -docstring %{$docstring}
      [[ $# != 0 ]] && echo "map-all $name -scope $scope %{ $@ }"

  }}

  def map-all -params 2.. -docstring \
  "map-all <mode> <body> [flags..]: Map all keys in <body> to <mode>
  options:
      <body>: lines expanded to 'map-mode <mode> {line}'.
  flags:
      all flags are forwarded to every keybind. See map-mode"\
  %{ eval %sh{
      mode=$1; shift
      flags=''
      while [[ $# > 1 ]]; do
          flags="$flags $1"; shift
      done
      while read line; do
          [[ -n "$line" ]] && echo try %{map-mode $mode $line $flags}
      done <<< $1
  }}

  def map-mode -params 3.. -docstring \
  "map-mode <mode> <key> <command> [docstring] [flags..]:
  map <key> in <mode> to <command>
  options:
      [docstring] defaults to <command>
  flags:
      -scope <scope>: register key in <scope>
      -raw: interpret <command> as raw keypresses
      -sh: run <command> in a shell, ignoring the output
      -repeat: After execution, return to <mode>
      -norepeat: force this entry to skip repetition" \
  %{ eval %sh{
      mode=$1; shift
      key=$1; shift
      command=$1; shift
      docstring=$command
      run=":$command<ret>"
      scope="global"
      repeat=''
      [[ ! "$1" =~ ^- ]] && docstring=$1 && shift
      while [[ ! $# == 0 ]]; do
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
                  repeat=${repeat:-":enter-user-mode $mode<ret>"}
                  ;;
              -norepeat)
                  repeat=":nop<ret>"
          esac
          shift
      done
      echo "map $scope $mode $key %{$run$repeat} -docstring %{$docstring}"
  }}


  def filetype-hook -params 2.. -docstring \
  "filetype-hook <filetype> [switches] <command>:
  Add hook for opening a buffer matching <filetype>
  options:
      <command>: Command to run on hook
  switches:
      -scoppe: window or buffer.
      -group: Group to add hook to.
  "\
  %{ eval %sh{
      filetype=$1; shift
      flags=''
      hook=WinSetOption
      while [[ $# != 0 ]] && [[ "$1" =~ "^-" ]]; do
          case $1 in
              -group)
                  shift
                  flags="$flags -group $1"
                  ;;
              -scope)
                  shift
                  [[ "$1" == "window" ]] && hook="WinSetOption"
                  [[ "$1" == "buffer" ]] && hook="BufSetOption"
                  ;;
          esac
          shift
      done
      echo "hook $flags global $hook filetype=$filetype %{$@}"
  }}

  def filetype-import -params 2 -docstring \
  "filetype-import <filetype> <module>: Import <module> when first opening a <filetype>" \
  %{ eval %sh{
      echo "filetype-hook -scope buffer $1 %{ import $2 }"
  }}

  def runtime -docstring "Echo how long kakoune has been running" %{ eval %sh{
      #echo echo -debug Kakoune has run for $( echo $(date +%s.%N) - $(date +%s.%N --date="$(stat -c %x /proc/$KAK_PID)") | bc ) seconds
      echo echo -debug Kakoune started in $( echo $(date +%s.%N) - $KAK_START_TIME | bc ) seconds
      echo echo Kakoune started in $( echo $(date +%s.%N) - $KAK_START_TIME | bc ) seconds
  }}

}

require-module my-utils
