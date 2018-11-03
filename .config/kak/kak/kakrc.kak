def eval-selection -param .. %{ %sh{
    echo $@
}}

filetype-hook kak %{
    map-all filetype -scope buffer %{
        e eval-selection 'Run selected commands'
    }
}
