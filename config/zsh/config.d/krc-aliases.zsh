#!/bin/sh

function kak {
    test -n "$KAKOUNE_SESSION" && krc attach "$@" || command kak "$@"
}

function kman { test -n "$KAKOUNE_SESSION" && krc send-fg man "$@" || kak -e "man $*"; }
function edit { krc send-fg edit "$@"; }

function val { krc get "%val[$1]"; }
function opt { krc get "%opt[$1]"; }
function reg { krc get "%reg[$1]"; }

function setw { krc send-sync set window "$@"; }
function setb { krc send-sync set buffer "$@"; }
function setg { krc send-sync set global "$@"; }

function send { krc send "$@"; }
function :send { krc send-fg "$@"; }
function send-sync { krc send-sync "$@"; }

function buffers {
    eval set -- $(krc get -quoting shell %val[buflist])
    printf "%s\n" "$@"
}

function fifo {
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
alias e=edit
alias b=buffers
alias ke='eval $(krc-choose-env)'
