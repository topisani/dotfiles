import utils

def lsp-start %{
    %sh{
        pid_file=/tmp/kak-lspc-pid-$kak_session
        log_file=/tmp/kak-lspc-log-$kak_session
        if ! [[ -f $pid_file ]]; then
            ( python $HOME/.config/kak/scripts/kakoune-cquery/lspc.py $kak_session
              rm $pid_file $log_file
            ) > $log_file 2>&1 < /dev/null &
            echo &! > /tmp/kak-lspc-pid-${kak_session}
        fi
    }
    lsp-setup
}

def lsp-log %{
    %sh{
        log_file=/tmp/kak-lspc-log-$kak_session
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

# Commands for language servers
decl str lsp_servers %{
    cpp:/home/topisani/.config/kak/scripts/start-cquery
    python:pyls
    #php:phpls
}

def lsp-rename-ask %{
    prompt "Rename to:" 'lsp-rename %val{text}'
}

def lsp-setup %{
    # Manual completion and signature help when needed
    map buffer insert <a-c> '<a-;>:eval -draft %(exec b; lsp-complete)<ret>'
    map buffer insert <a-h> '<a-;>:lsp-signature-help<ret>'

    # Hover and diagnostics on idle
    hook -group lsp buffer NormalIdle .* %{
        lsp-diagnostics info
        lsp-hover echo
    }

    # Aggressive diagnostics
    hook -group lsp buffer InsertEnd .* lsp-sync

    map-all filetype -scope buffer %{
        . 'lsp-goto-definition'              'Goto definition'
        ? 'lsp-references'                   'Select references'
        h 'lsp-hover info'                   'Show documentation'
        j 'lsp-diagnostics-jump next cursor' 'Next diagnostic'
        k 'lsp-diagnostics-jump prev cursor' 'Previous diagnostic'
        r 'lsp-rename-ask'                   'Rename at point'
    }

#    set buffer autoshowcompl false
}

filetype-hook (python|php) %{
    lsp-start
}

define-command lsp-enable-autocomplete -docstring "Add lsp completion candidates to the completer" %{
    set-option window completers "option=lsp_completions:%opt{completers}"
    hook window -group racer-autocomplete InsertIdle .* %{ try %{
        execute-keys -draft <a-h><a-k>([\w\.]|::).\z<ret>
        lsp-complete
    } }
    alias window complete lsp-complete
}

define-command lsp-disable-autocomplete -docstring "Disable lsp completion" %{
    set-option window completers %sh{ printf %s\\n "'${kak_opt_completers}'" | sed 's/option=lsp_completions://g' }
    remove-hooks window lsp-autocomplete
    unalias window complete lsp-complete
}


# Ignore E501 for python (Line length > 80 chars)
# decl str lsp-python-disabled-diagnostics '^E501'

# Example keybindings
