hook global ModuleLoaded tmux %{
    # Commands
    define-command -override tmux-terminal-horizontal -params .. -docstring 'tmux-terminal-horizontal [<program>] [<arguments>]: Creates a new terminal to the right as a tmux pane.' %{
      tmux_impl split-window -e "KAKOUNE_SESSION=%val{session}" -e "KAKOUNE_CLIENT=%val{client}" -h %arg{@}
    }

    complete-command tmux-terminal-horizontal shell

    define-command -override tmux-terminal-vertical -params .. -docstring 'tmux-terminal-vertical [<program>] [<arguments>]: Creates a new terminal below as a tmux pane.' %{
      tmux_impl split-window -e "KAKOUNE_SESSION=%val{session}" -e "KAKOUNE_CLIENT=%val{client}" -v %arg{@}
    }

    complete-command tmux-terminal-vertical shell

    define-command -override tmux-terminal-window -params .. -docstring 'tmux-terminal-window [<program>] [<arguments>]: Creates a new terminal to the right as a tmux window.' %{
      tmux_impl new-window -e "KAKOUNE_SESSION=%val{session}" -e "KAKOUNE_CLIENT=%val{client}" -a %arg{@}
    }

    complete-command tmux-terminal-window shell

    define-command -override tmux-terminal-popup -params .. -docstring 'tmux-terminal-popup [<program>] [<arguments>]: Creates a new terminal as a tmux popup.' %{
      tmux_impl display-popup -e "KAKOUNE_SESSION=%val{session}" -e "KAKOUNE_CLIENT=%val{client}" -w 90% -h 90% -E %arg{@}
    }

    complete-command tmux-terminal-popup shell

    define-command -override tmux-terminal-panel -params .. -docstring 'tmux-terminal-panel [<program>] [<arguments>]: Creates a new terminal as a tmux panel.' %{
      tmux_impl split-window -e "KAKOUNE_SESSION=%val{session}" -e "KAKOUNE_CLIENT=%val{client}" -h -b -l 30 -t '{left}' %arg{@}
    }

    complete-command tmux-terminal-panel shell

    define-command -override tmux-focus -params ..1 -docstring 'tmux-focus [<client>]: Moves focus to the given client, or the current one.' %{
      evaluate-commands -try-client %arg{1} %{
        tmux_impl switch-client -t %val{client_env_TMUX_PANE}
      }
    }

    complete-command tmux-focus client

    define-command -override -hidden tmux_impl -params .. %{
      nop %sh{
        TMUX=$kak_client_env_TMUX TMUX_PANE=$kak_client_env_TMUX_PANE nohup tmux "$@" < /dev/null > /dev/null 2>&1 &
      }
    }


    define-command -override tmux-terminal-bottom-panel -params .. -shell-completion -docstring 'tmux-terminal-bottom-panel <program> [arguments]: create a new terminal as a tmux bottom panel' %{
      tmux_impl split-window -v -l 20 -c %sh{pwd} %arg{@}
    }
    define-command -override tmux-terminal-auto -params .. -shell-completion -docstring 'tmux-terminal-auto <program> [arguments]: create a new terminal as a tmux pane with autosplit' %{
      nop %sh{
        tmux-autosplit -c "$PWD" "$@"
      }
    }

    define-command -override tmux-terminal-popup -params .. -docstring 'tmux-terminal-popup [options] [<program>] [<arguments>]: Creates a new terminal as a tmux popup.
    Options:
    -title <title>
    -w width: Width of popup, in characters or percentage
    -h height: Height of popup, in characters or percentage
    -x x: X Position
    -y y: Y Position' %{
      nop %sh{
        popup_args=""
        title=""
        while true; do
          case $1 in
            -title)
              shift
              title=" $1 "
              shift
              ;;
            -w)
              shift
              popup_args="$popup_args -w $1"
              shift
              ;;
            -h)
              shift
              popup_args="$popup_args -h $1"
              shift
              ;;
            -x)
              shift
              popup_args="$popup_args -x $1"
              shift
              ;;
            -y)
              shift
              popup_args="$popup_args -y $1"
              shift
              ;;
            *)
              break
              ;;
          esac
        done
        TMUX=$kak_client_env_TMUX TMUX_PANE=$kak_client_env_TMUX_PANE nohup tmux \
          display-popup -e "KAKOUNE_SESSION=$kak_session" -e "KAKOUNE_CLIENT=$kak_client" -d $PWD -T "$title" $popup_args -E "$@" \
          < /dev/null > /dev/null 2>&1 &
      }
    }
}

hook global ModuleLoaded zellij %{
    define-command -hidden -override -params 2.. zellij-run %{ nop %sh{
        zellij_run_options=$1
        shift
        zellij --session "$kak_client_env_ZELLIJ_SESSION_NAME" run -c $zellij_run_options -- "$@"
    }}

    define-command -override -hidden -params 1.. zellij-terminal-window %{
        zellij-run "--close-on-exit" %arg{@}
    }
    complete-command zellij-terminal-window shell

    define-command -override zellij-terminal-vertical -params 1.. -docstring '
    zellij-terminal-vertical <program> [<arguments>]: create a new terminal as a zellij pane
    The current pane is split into two, top and bottom
    The program passed as argument will be executed in the new terminal' \
    %{
        zellij-run "--direction down --close-on-exit" %arg{@}
    }
    complete-command zellij-terminal-vertical shell

    define-command -override zellij-terminal-horizontal -params 1.. -docstring '
    zellij-terminal-horizontal <program> [<arguments>]: create a new terminal as a zellij pane
    The current pane is split into two, left and right
    The program passed as argument will be executed in the new terminal' \
    %{
        zellij-run "--direction right --close-on-exit" %arg{@}
    }
    complete-command zellij-terminal-horizontal shell

    define-command -override zellij-focus -params ..1 -docstring '
    zellij-focus [<client>]: focus the given client
    If no client is passed then the current one is used' \
    %{ evaluate-commands %sh{
        if [ $# -eq 1 ]; then
            printf "evaluate-commands -client '%s' focus" "$1"
        elif [ -n "${kak_client_env_ZELLIJ}" ]; then
            # use this if the command is available
            zellij action focus-pane-by-id "${kak_client_env_ZELLIJ_PANE_ID}" && exit 0
            # Otherwise, here is a dirty hack:
            output=$(mktemp -d "${TMPDIR:-/tmp}"/kak-zellij.XXXXXXXX)/dump-screen
            pane_count=0
            while [ $((pane_count+=1)) -lt 10 ]; do
                 if zellij action dump-screen "$output" && grep "${kak_client}@\[$kak_session\]" "$output" > /dev/null ; then
                     break;
                 fi
                 zellij action focus-next-pane
            done
            rm -r $(dirname $output)
        fi
    }}
    complete-command -menu zellij-focus client

    ## The default behaviour for the `new` command is to open an horizontal pane in a zellij session
    alias global focus zellij-focus

    define-command zellij-terminal-popup -override -params .. -docstring 'zellij-terminal-popup [options] [<program>] [<arguments>]: Creates a new terminal as a zellij popup.
    Options:
    -title <title>
    -w width: Width of popup, in characters or percentage
    -h height: Height of popup, in characters or percentage
    -x x: X Position
    -y y: Y Position' %{
      nop %sh{
        popup_args="--floating "
        title=""
        while true; do
          case $1 in
            -title)
              shift
              title="$1"
              shift
              ;;
            -w)
              shift
              popup_args="$popup_args --width $1"
              shift
              ;;
            -h)
              shift
              popup_args="$popup_args --height $1"
              shift
              ;;
            -x)
              shift
              popup_args="$popup_args -x $1"
              shift
              ;;
            -y)
              shift
              popup_args="$popup_args -y $1"
              shift
              ;;
            *)
              break
              ;;
          esac
        done
        printf %s "$popup_args"
        zellij --session "$kak_client_env_ZELLIJ_SESSION_NAME" run -c $popup_args --name "$title" -- "$@"
      }
    }
    complete-command zellij-terminal-popup shell

    define-command -override zellij-terminal-panel -params 1.. %{
        zellij-run "--direction left --size 40" %arg{@}
    }
    complete-command zellij-terminal-panel shell

    define-command zellij-terminal-bottom-panel -params 1.. %{
        zellij-run "--direction down --size 18" %arg{@}
    }
    complete-command zellij-terminal-bottom-panel shell

    alias global zellij-terminal-auto zellij-terminal-window
}
