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
define-command -override tmux-terminal-autosplit -params .. -shell-completion -docstring 'tmux-terminal-autosplit <program> [arguments]: create a new terminal as a tmux pane with autosplit' %{
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


# Hooks
# tmux detection
# Ensure that we’re running on tmux.
remove-hooks global tmux-detection
hook -group tmux-detection global ClientCreate '.*' %{
  trigger-user-hook "TMUX=%val{client_env_TMUX}"
}

hook -group tmux-integration global User 'TMUX=(.+?),(.+?),(.+?)' %{
  alias global terminal tmux-terminal-horizontal
  alias global terminal-horizontal tmux-terminal-horizontal
  alias global terminal-vertical tmux-terminal-vertical
  alias global terminal-tab tmux-terminal-window
  alias global terminal-window tmux-terminal-window
  alias global terminal-popup tmux-terminal-popup
  alias global terminal-panel tmux-terminal-panel
  alias global focus tmux-focus
  
  alias global panel tmux-terminal-panel
  alias global bottom-panel tmux-terminal-bottom-panel
  alias global terminal tmux-terminal-autosplit
  alias global popup tmux-terminal-popup
}
