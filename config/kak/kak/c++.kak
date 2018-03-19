# C++
import lsp

def cquery-start %{
    %sh{
        pid_file=/tmp/kak-cquery-pid-$kak_session
        log_file=/tmp/kak-cquery-log-$kak_session
        if ! [[ -f $pid_file ]]; then
            ( python $HOME/.config/kak/scripts/kakoune-cquery/cquery.py $kak_session
              rm $pid_file $log_file
            ) > $log_file 2>&1 < /dev/null &
            echo &! > /tmp/kak-cquery-pid-${kak_session}
        fi
    }
    lsp-setup
}

def cquery-log %{
    %sh{
        log_file=/tmp/kak-cquery-log-$kak_session
        if ! [[ -f $log_file ]]; then
            echo "fail 'cquery does not seem to be running'"
        else
            echo "
            edit $log_file
            set buffer readonly true
            set buffer autoreload true
            "
        fi
    }
}

# Highlight qualifiers
addhl shared/cpp/code regex %{([\w_0-9]+)::} 1:module

# Highlight doc comments
addhl shared/cpp/comment regex '[^/]*(///([^/].*)?)' 1:string
addhl shared/cpp/comment regex '[^/]*(/\*\*[^/].*\*/)' 0:string
addhl shared/cpp/comment regex '`.*`' 0:module

import occivink/kakoune-gdb/gdb

new-mode gdbrepeat
map-all gdbrepeat -repeat %{
    n gdb-next              'step over (next)'
    s gdb-step              'step in (step)'
    f gdb-finish            'step out (finish)'
    a gdb-advace            'advance'
    r gdb-start             'start'
    R gdb-run               'run'
    c gdb-continue          'continue'
    g gdb-jump-to-location  'jump'
    G gdb-toggle-autojump   'toggle autojump'
    t gdb-toggle-breakpoint 'toggle breakpoint'
    T gdb-backtrace         'backtrace'
    p gdb-print             'print'
    q gdb-session-stop      'stop'
    N gdb-session-new       'new session' -norepeat
}

def clang-format -docstring "Format selection using clang-format" %{
    exec -draft "|clang-format<ret>"
    echo "Formatted selection"
}

# filetype hook
filetype-hook cpp %{
    cquery-start

    map-all filetype -scope buffer %{
        d     "enter-user-mode gdbrepeat" 'GDB...'
        <tab> "alt"                       'Other file'
        =     "clang-format"              'clang-format selection'
    }

    set buffer tabstop 2
    set buffer indentwidth 2 
}

