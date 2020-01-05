hook global BufCreate .*[.](MD|mdx) %{
    set-option buffer filetype markdown
}

filetype-hook markdown %{
  add-highlighter window/wrap wrap -word -indent -width 120
  map-all filetype -scope window %{
    'n' spell-next      "next spelling error"
    ',' spell-replace   "replace spelling error"
  }
  hook window NormalIdle .* spell
  hook window InsertIdle .* spell
}
