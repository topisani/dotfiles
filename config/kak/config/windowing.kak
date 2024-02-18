load-conf tmux
# cork wezterm https://github.com/Anomalocaridid/wezterm.kak

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
