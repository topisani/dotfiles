cork tmux https://github.com/alexherbo2/tmux.kak %{
  define-command -override tmux-terminal-bottom-panel -params .. -shell-completion -docstring 'tmux-terminal-bottom-panel <program> [arguments]: create a new terminal as a tmux bottom panel' %{
    tmux split-window -v -l 20 -t '{bottom}' -c %sh{pwd} %arg{@}
  }
  define-command -override tmux-terminal-autosplit -params .. -shell-completion -docstring 'tmux-terminal-autosplit <program> [arguments]: create a new terminal as a tmux pane with autosplit' %{
    nop %sh{
      tmux-autosplit -t '{bottom}' -c "$PWD" "$@"
    }
  }
}

cork wezterm https://github.com/Anomalocaridid/wezterm.kak

# Kitty from autoload

eval %sh{
  if [ -n "$TMUX" ]; then
    echo "tmux-integration-enable"
  elif [ -n "$KITTY_WINDOW_ID" ]; then
    echo "kitty-integration-enable"
  elif [ -n "$WEZTERM_UNIX_SOCKET" ]; then
    echo "wezterm-integration-enable"
    echo "alias global panel wezterm-terminal-horizontal"
    echo "alias global bottom-panel wezterm-terminal-vertical"
  fi
}

hook -group tmux-integration global User 'TMUX=(.+?),(.+?),(.+?)' %{
    alias global bottom-panel tmux-terminal-bottom-panel
    alias global terminal tmux-terminal-autosplit
}
