hook global BufCreate .*[.](MD) %{
    set-option buffer filetype markdown
}

add-highlighter shared/markdown/content/bracket_links regex (\[.*?\])(\(.*?\)) 1:link 2:link

filetype-hook markdown %{
    addhl buffer/wrap wrap -word -indent -width 120
}
