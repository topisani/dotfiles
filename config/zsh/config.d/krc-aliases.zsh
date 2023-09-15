#!/bin/sh

function kak {
    test -n "$KAKOUNE_SESSION" && krc attach "$@" || command kak "$@"
}

function krc-man { test -n "$KAKOUNE_SESSION" && krc send-fg man "$@" || kak -e "man $*"; }
function krc-edit { krc send-fg edit "$@"; }

function krc-val { krc get "%val[$1]"; }
function krc-opt { krc get "%opt[$1]"; }
function krc-reg { krc get "%reg[$1]"; }

function krc-setw { krc send-sync set window "$@"; }
function krc-setb { krc send-sync set buffer "$@"; }
function krc-setg { krc send-sync set global "$@"; }

function krc-send { krc send "$@"; }
function krc-:send { krc send-fg "$@"; }
function krc-send-sync { krc send-sync "$@"; }

function krc-buffers {
    eval set -- $(krc get '%val[buflist]')
    printf "%s\n" "$@"
}

function krc-fifo {
    # Send output of argument command, or read stdin, to a fifo buffer.
    d=$(mktemp -d --suffix=-krc-fifo)
    fifo="$d/fifo"
    mkfifo "$fifo"
    trap "rm -rf $d" EXIT
    krc send edit! -fifo "$fifo" '*fifo*'
    if [[ $# -gt 0 ]]; then
        "$@" > "$fifo" 2>&1 &
    elif [[ ! -t 0 ]]; then
        cat > "$fifo"
    fi
}

alias k=kak
alias ke=krc-edit
alias kb=krc-buffers
alias kman=krc-man
alias krc-env='eval $(krc-choose-env)'
