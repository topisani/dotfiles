hook global BufCreate .*[.](MD) %{
    set-option buffer filetype markdown
}

filetype-hook markdown %{
  add-highlighter window/wrap wrap -word -indent -width 120
}
