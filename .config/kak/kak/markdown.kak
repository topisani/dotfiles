hook global BufCreate .*[.](MD|mdx) %{
    set-option buffer filetype markdown
}

def -hidden markdown-indent -params 1 %{
  try %{
    exec -draft "<a-x><a-k>\h*<minus><ret><%arg{1}t>"
  }
}

filetype-hook markdown %{
  add-highlighter window/wrap wrap -word -indent -width 120
  map-all filetype -scope window %{
    'n' spell-next      "next spelling error"
    ',' spell-replace   "replace spelling error"
  }
  map buffer insert <tab> "<a-;>:markdown-indent g<ret>"
  map buffer insert <s-tab> "<a-;>:markdown-indent l<ret>"
  hook window NormalIdle .* spell
  hook window InsertIdle .* spell
}
