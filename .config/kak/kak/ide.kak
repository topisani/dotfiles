import utils

decl -hidden str toolsclient_tmux_pane

def ide-setup %{

    set global jumpclient client0

    tmux-terminal-impl "split-window -p 0" kak -c %val{session} -e 'rename-client tools; ide-hide-tools'
    set global toolsclient tools

    hook -group ide global ClientClose "^(?!tools).*$" %{
        eval -client tools %sh{
            if [[ $(echo "$kak_client_list" | wc -w)  == 2 ]]; then
                echo "remove-hooks global ide"
                echo "quit"
            fi
        }
    }

    hook global WinDisplay .* %{
        eval %sh{
            if [[ "$kak_client" == "$kak_opt_toolsclient" ]]; then
                echo ide-show-tools
                echo "map window tmux d ':ide-hide-tools<ret>'"
            fi 
        }
    }

    hook global WinClose .* %{
        eval %sh{
            if [[ "$kak_client" == "$kak_opt_toolsclient" ]]; then
                echo "ide-hide-tools"
            fi
        }
    }

    hook global BufClose .* %{
        eval %sh{
            if [[ "$kak_client" == "$kak_opt_toolsclient" ]]; then
                echo "ide-hide-tools"
            fi
        }
    }
}

def ide-hide-tools %{
    eval -client tools %{
        buffer *debug*
        eval %sh{
        TMUX=${kak_client_env_TMUX:-$TMUX}
        tmux new-session -ds "kakoune-background" &> /dev/null
        pane=$(tmux break-pane -dP -t "kakoune-background:")
        [[ $? == 0 ]] && echo "set global toolsclient_tmux_pane '$pane'"
    }}
}

def ide-show-tools %{
    eval %sh{
        [[ $kak_client != "tools" ]] && echo "set global jumpclient '$kak_client'"
        tmux=${kak_client_env_TMUX:-$TMUX}
        if [ -z "$tmux" ]; then
            echo "echo -markup '{Error}This command is only available in a tmux session'"
            exit
        fi
        TMUX=$tmux tmux join-pane -p 40 -vs "${kak_opt_toolsclient_tmux_pane}" < /dev/null > /dev/null 2>&1 &
    }
}
