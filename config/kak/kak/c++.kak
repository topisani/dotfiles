# C++
#import lsp

# Highlight qualifiers
addhl shared/cpp/code/ regex %{([\w_0-9]+)::} 1:module

# Highlight attributes
addhl shared/cpp/code/ regex '(\[\[)([^\]]*)(\]\])' 2:meta

# Highlight doc comments

rmhl shared/cpp/line_comment
rmhl shared/cpp/comment

add-highlighter shared/cpp/doc_comment region /\*\* \*/ group
add-highlighter shared/cpp/doc_comment2 region /// $ ref cpp/doc_comment

add-highlighter shared/cpp/comment region /\* \*/ group
add-highlighter shared/cpp/line_comment region // $ group

add-highlighter shared/cpp/comment/ fill comment
add-highlighter shared/cpp/line_comment/ ref cpp/comment
add-highlighter shared/cpp/comment/ regex '(TODO|NOTE|NOTES|PREV|FIXME)' 1:identifier

add-highlighter shared/cpp/doc_comment/ fill string
add-highlighter shared/cpp/doc_comment/ regex '\h*(///|\*/?|/\*\*+)' 1:comment 
add-highlighter shared/cpp/doc_comment/ regex '`.*?`' 0:module
add-highlighter shared/cpp/doc_comment/ regex '\\\w+' 0:module

#addhl shared/c/comment/ regex '[^/]*(///([^/].*)?)' 1:string
#addhl shared/c/comment/ regex '[^/]*(/\*\*[^/].*\*/)' 0:string
#addhl shared/c/comment/ regex '`.*?`' 0:module
#
define-command -hidden -override c-family-insert-on-newline %[ evaluate-commands -itersel -draft %[
    execute-keys \;
    try %[
        evaluate-commands -draft -save-regs '/"' %[
            # copy the commenting prefix
            execute-keys -save-regs '' k <a-x>1s^\h*(//+\h*)<ret> y
            try %[
                # if the previous two comments aren't empty, create a new one
                execute-keys K<a-x><a-K>^(\h*//+\h*\n){2}<ret> jj<a-x>s^\h*<ret>P
            ] catch %[
                # if there is no text in the previous comment, remove it completely
                execute-keys d
            ]
        ]
    ]
    try %[
        # if the previous line isn't within a comment scope, break
        execute-keys -draft k<a-x> <a-k>^(\h*/\*|\h+\*(?!/))<ret>

        # find comment opening, validate it was not closed, and check its using star prefixes
        execute-keys -draft <a-?>/\*<ret><a-H> <a-K>\*/<ret> <a-k>\A\h*/\*([^\n]*\n\h*\*)*[^\n]*\n\h*.\z<ret>

        try %[
            # if the previous line is opening the comment, insert star preceeded by space
            execute-keys -draft k<a-x><a-k>^\h*/\*<ret>
            execute-keys -draft i*<space><esc>
        ] catch %[
           try %[
                # if the next line is a comment line insert a star
                execute-keys -draft j<a-x><a-k>^\h+\*<ret>
                execute-keys -draft i*<space><esc>
            ] catch %[
                try %[
                    # if the previous line is an empty comment line, close the comment scope
                    /*
                    execute-keys -draft kK<a-x><a-k>^(\h+\*\h+\n){2}<ret> ;<a-x>d <a-x>1s\*(\h*)<ret>c/<esc>
                ] catch %[
                    # if the previous line is a non-empty comment line, add a star
                    execute-keys -draft i*<space><esc>
                ]
            ]
        ]

        # trim trailing whitespace on the previous line
        try %[ execute-keys -draft s\h+$<ret> d ]
        # align the new star with the previous one
        execute-keys K<a-x>1s^[^*]*(\*)<ret>&
    ]
] ]

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
}
map-mode gdbrepeat N ":gdb-session-new " 'new session' -raw

def clang-format -docstring "Format buffer using clang-format" %{
    exec -draft '%|clang-format<ret>'
    echo "Formatted selection"
}

set global c_include_guard_style pragma

decl str other_file
set global modeline_vars -add other_file

def other-or-alt -docstring \
"Jump to alternative file.
If the current buffer has an 'other_file' option, use that.
Otherwise, calls :alt" \
%{ eval %sh{
    if [[ -n "$kak_opt_other_file" ]]; then
        echo "try %[ edit -existing '$(dirname $kak_buffile)/$kak_opt_other_file' ] catch %[ alt ]"
    else
        echo alt
    fi
}}

# filetype hook
filetype-hook (cpp|c) %{
    lsp-start

    map-all filetype -scope window %{
        d     "enter-user-mode gdbrepeat" 'GDB...'
        <tab> "other-or-alt"              'Other file'
        =     "clang-format"              'clang-format selection'
    }

    set window tabstop 2
    set window indentwidth 2
}

