import util

def lsp-rename-ask %{
    prompt "Rename to:" 'lsp-rename %val{text}'
}

def lsp-setup %{
    map-all lsp -scope buffer %{
        # r 'lsp-rename-ask'                             'Rename at point'
        n 'lsp-find-error -include-warnings'           'Next diagnostic'
        n 'lsp-find-error -include-warnings -previuos' 'Previous diagnostic'
    }

    map-all filetype -scope buffer %{
        s 'enter-user-mode lsp'        'lsp...'
    }

    lsp-start
}

def lsp-restart -docstring "Restart lsp server" %{
    lsp-stop
    lsp-start
}

def lsp-find-error -params 0..2 -docstring \
"lsp-find-error [--previous] [--include-warnings]
Jump to the next or previous diagnostic error" %{
    evaluate-commands %sh{
        previous=false
        errorCompare="DiagnosticError"
        if [ $1 = "-previous" ]; then
            previous=true
            shift
        fi
        if [ $1 = "-include-warnings" ]; then
            errorCompare="Diagnostic"
        fi
        #expand quoting, stores option in $@
        eval "set -- ${kak_opt_lsp_errors}"
         first=""
        current=""
        prev=""
        selection=""
        for e in "$@"; do
            if [ -z "${e##*${errorCompare}*}" ]; then # e contains errorCompare
                e=${e%,*}
                line=${e%.*}
                column=${e#*.}
                if [ $line -eq $kak_cursor_line ] && [ $column -eq $kak_cursor_column ]; then
                    continue #do not return the current location
                fi
                current="$line $column"
                if [ -z "$first" ]; then
                    first="$current"
                fi
                if [ $line -gt $kak_cursor_line ] || { [ $line -eq $kak_cursor_line ] && [ $column -gt $kak_cursor_column ]; }; then
                    #after the cursor
                    if $previous; then
                        selection="$prev"
                    else 
                        selection="$current"
                    fi
                    if [ ! -z "$selection" ]; then
                        # if a selection is found
                        break
                    fi
                else
                    prev="$current"
                fi
            fi
        done
        if [ -z "$first" ]; then
            # if nothing found
            echo "echo -markup '{Error}No errors found'" 
        fi
        if [ -z "$selection" ]; then #if nothing found past the cursor
            if $previous; then
                selection="$current"
            else 
                selection="$first"
            fi
        fi    
        printf "edit %b %b" "$kak_buffile" "$selection"
    }
}
