filetype-hook (javascript|scss|css) %{
    map-all filetype -scope window %{
        =     "format"              'Format buffer'
    }
    set buffer tabstop 2
    set buffer indentwidth 2
}

filetype-hook javascript %{ set buffer formatcmd "prettier --parser babel" }
filetype-hook scss %{ set buffer formatcmd "prettier --parser scss" }
filetype-hook css %{ set buffer formatcmd "prettier --parser css" }


