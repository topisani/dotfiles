# Util functions

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
%{ %sh{
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
%{ %sh{
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
%{ %sh{
    mode=$1; shift
    key=$1; shift
    command=$1; shift
    docstring=$command
    run=":$command<ret>"
    scope="global"
    repeat=''
    [[ ! "$1" =~ "^-" ]] && docstring=$1 && shift
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
    -group: Group to add hook to.
"\
%{ %sh{
    filetype=$1; shift
    flags=''
    while [[ $# != 0 ]] && [[ "$1" =~ "^-" ]]; do
        case $1 in
            -group)
                shift
                flags="$flags -group $1"
                ;;
        esac
        shift
    done
    echo "hook $flags global BufSetOption filetype=$filetype %{$@}"
}}

def filetype-import -params 2 -docstring \
"filetype-import <filetype> <module>: Import <module> when first opening a <filetype>" \
%{ %sh{
    echo "filetype-hook $1 %{ import $2 }"
}}
