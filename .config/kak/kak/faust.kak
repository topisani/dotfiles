# Detection
# ‾‾‾‾‾‾‾‾‾

hook global BufCreate .*\.dsp$ %{
    set-option buffer filetype faust
}

# Highlighters
# ‾‾‾‾‾‾‾‾‾‾‾‾

add-highlighter shared/faust regions
add-highlighter shared/faust/code           default-region group
add-highlighter shared/faust/string         region '"' '(?<!\\)(\\\\)*"'     group
add-highlighter shared/faust/comment        region '/\*' '\*/'               group
add-highlighter shared/faust/line_comment   region '//' '$'                  ref faust/comment

add-highlighter shared/faust/comment/ fill comment
add-highlighter shared/faust/comment/ regex \b(FIXME|NOTE|NOTES|TODO|XXX)\b 0:keyword
add-highlighter shared/faust/string/ fill string
add-highlighter shared/faust/string/ regex @\w+@ 0:value

add-highlighter shared/faust/code/ regex \b(\w+)\b 1:variable
add-highlighter shared/faust/code/ regex '\b(_|!|\+|-|\*| / |%|<|>|>=|<=|!=|==|&|\^|\||<<|>>|:|,|<:|:>|~)\b' 0:operator
add-highlighter shared/faust/code/ regex (\w+)\h*\( 1:function
add-highlighter shared/faust/code/ regex (\w+)\h*=\h* 1:variable
add-highlighter shared/faust/code/ regex (\w+)\h*\. 1:module
add-highlighter shared/faust/code/ regex \b[-+]?(\d+|\d*\.\d+)\b 0:value
add-highlighter shared/faust/code/ regex \b(process|with|case|seq|par|sum|prod|import|component|library|environment|declare)\b 0:keyword

add-highlighter shared/faust/code/ regex \
\b(mem|prefix|int|float|rdtable|rwtable|select2|select3|ffunction|fconstant|fvariable|button|checkbox|vslider|hslider|nentry|vgroup|hgroup|tgroup|vbargraph|hbargraph|attach|acos|asin|atan|atan2|cos|sin|tan|exp|log|log10|pow|sqrt|abs|min|max|fmod|remainder|floor|ceil|rint)\b \
        0:builtin

# Commands
# ‾‾‾‾‾‾‾‾

define-command -hidden faust-filter-around-selections %{
    # remove trailing white spaces
    try %{ execute-keys -draft -itersel <a-x> s \h+$ <ret> d }
}

define-command -hidden faust-indent-on-new-line %{
    evaluate-commands -draft -itersel %{
        # copy '#' comment prefix and following white spaces
        try %{ execute-keys -draft k <a-x> s ^\h*\K#\h* <ret> y gh j P }
        # preserve previous line indent
        try %{ execute-keys -draft \; K <a-&> }
        # filter previous line
        try %{ execute-keys -draft k : faust-filter-around-selections <ret> }
    }
}

# Initialization
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾

hook -group faust-highlight global WinSetOption filetype=faust %{ add-highlighter window/faust ref faust }

hook global WinSetOption filetype=faust %{
    hook window ModeChange insert:.* -group faust-hooks  faust-filter-around-selections
    hook window InsertChar \n -group faust-indent faust-indent-on-new-line
}

hook -group faust-highlight global WinSetOption filetype=(?!faust).* %{ remove-highlighter window/faust }

hook global WinSetOption filetype=(?!faust).* %{
    remove-hooks window faust-indent
    remove-hooks window faust-hooks
}
