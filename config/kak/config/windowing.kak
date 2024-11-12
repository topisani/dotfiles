load-conf tmux

set global windowing_modules 'tmux' 'screen' 'zellij' 'wezterm' 'kitty' 'sway' 'wayland'

hook global ModuleLoaded wezterm %{
    define-command wezterm-terminal-popup -params 1.. %{
        # wezterm-terminal-impl split-pane --cwd "%val{client_env_PWD}" --top --percent 30 --pane-id "%val{client_env_WEZTERM_PANE}" -- %arg{@}
        # See https://github.com/wez/wezterm/pull/5576
        wezterm-terminal-impl spawn --cwd "%val{client_env_PWD}" --floating-pane --pane-id "%val{client_env_WEZTERM_PANE}" -- %arg{@}
    }
    complete-command wezterm-terminal-popup shell

    define-command wezterm-terminal-auto -override -params 1.. %{
        set local windowing_placement %sh{
            if [ $((kak_window_height * 2 > kak_window_width)) = 0 ]; then
                echo "horizontal"
            else
                echo "vertical"
            fi
        }
        terminal %arg{@}
    }
    complete-command wezterm-terminal-auto shell

    define-command wezterm-terminal-panel -params 1.. %{
        wezterm-terminal-impl split-pane --cwd "%val{client_env_PWD}" --left --cells 35 --pane-id "%val{client_env_WEZTERM_PANE}" -- %arg{@}
    }
    complete-command wezterm-terminal-panel shell

    define-command wezterm-terminal-bottom-panel -params 1.. %{
        wezterm-terminal-impl split-pane --cwd "%val{client_env_PWD}" --bottom --cells 18 --pane-id "%val{client_env_WEZTERM_PANE}" -- %arg{@}
    }
    complete-command wezterm-terminal-bottom-panel shell
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
