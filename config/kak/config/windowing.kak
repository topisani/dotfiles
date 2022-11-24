cork tmux https://github.com/alexherbo2/tmux.kak %{
  define-command -override tmux-terminal-bottom-panel -params .. -shell-completion -docstring 'tmux-terminal-bottom-panel <program> [arguments]: create a new terminal as a tmux bottom panel' %{
    tmux_impl split-window -v -l 20 -c %sh{pwd} %arg{@}
  }
  define-command -override tmux-terminal-autosplit -params .. -shell-completion -docstring 'tmux-terminal-autosplit <program> [arguments]: create a new terminal as a tmux pane with autosplit' %{
    nop %sh{
      tmux-autosplit -c "$PWD" "$@"
    }
  }
  
  define-command -override tmux-terminal-popup -params .. -docstring 'tmux-terminal-popup [<program>] [<arguments>]: Creates a new terminal as a tmux popup.' %{
    # TODO: Remove -d flag.
    tmux_impl display-popup -e "KAKOUNE_SESSION=%val{session}" -e "KAKOUNE_CLIENT=%val{client}" -d %sh{pwd} -E %arg{@}
  }

}

cork wezterm https://github.com/Anomalocaridid/wezterm.kak

# Kitty from autoload

eval %sh{
  if [ -n "TMUX" ]; then
    echo ""
  elif [ -n "$KITTY_WINDOW_ID" ]; then
    echo "kitty-integration-enable"
  elif [ -n "$WEZTERM_UNIX_SOCKET" ]; then
    echo "wezterm-integration-enable"
    echo "alias global panel wezterm-terminal-horizontal"
    echo "alias global bottom-panel wezterm-terminal-vertical"
  fi
}

# Disable default tmux integration hook and rewrite here to disable clipboard synching.
remove-hooks global tmux-integration
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

