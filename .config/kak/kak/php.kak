# Detection
# ‾‾‾‾‾‾‾‾‾

hook global BufCreate .*[.](php) %{
    set-option buffer filetype php
}

# Highlighters
# ‾‾‾‾‾‾‾‾‾‾‾‾

add-highlighter shared/php regions
add-highlighter shared/php/code  default-region group
add-highlighter shared/php/double_string region '"'    (?<!\\)(\\\\)*" group
add-highlighter shared/php/single_string region "'"    (?<!\\)(\\\\)*' fill string
add-highlighter shared/php/doc_comment   region ///    '$'             group
add-highlighter shared/php/doc_comment2  region /\*\*  \*/             ref php/doc_comment
add-highlighter shared/php/comment1      region //     '$'             fill comment
add-highlighter shared/php/comment2      region /\*    \*/             fill comment
add-highlighter shared/php/comment3      region '#'    '$'             fill comment

add-highlighter shared/php/code/ regex (&?\$|->)\w* 0:variable
add-highlighter shared/php/code/ regex '\w+\s*(?=\()' 0:function
add-highlighter shared/php/code/ regex \b(false|null|parent|self|this|true)\b 0:value
add-highlighter shared/php/code/ regex "-?[0-9]*\.?[0-9]+" 0:value
add-highlighter shared/php/code/ regex \b((string|int|bool)|[A-Z][a-z].*?)\b 0:type
add-highlighter shared/php/code/ regex \B/[^\n/]+/[gimy]* 0:meta
add-highlighter shared/php/code/ regex '<\?(php)?|\?>' 0:meta

add-highlighter shared/php/double_string/ fill string
add-highlighter shared/php/double_string/ regex (?<!\\)(\\\\)*(\$\w+)(->\w+)* 0:variable
add-highlighter shared/php/double_string/ regex \{(?<!\\)(\\\\)*(\$\w+)(->\w+)*\} 0:variable

# Highlight doc comments
add-highlighter shared/php/doc_comment/ fill string
add-highlighter shared/php/doc_comment/ regex '`.*?`' 0:module
add-highlighter shared/php/doc_comment/ regex '@\w+' 0:meta 

# Keywords are collected at
# http://php.net/manual/en/reserved.keywords.php
add-highlighter shared/php/code/ regex \b(__halt_compiler|abstract|and|array|as|break|callable|case|catch|class|clone|const|continue|declare|default|die|do|echo|else|elseif|empty|enddeclare|endfor|endforeach|endif|endswitch|endwhile|eval|exit|extends|final|finally|for|foreach|function|global|goto|if|implements|include|include_once|instanceof|insteadof|interface|isset|list|namespace|new|or|print|private|protected|public|require|require_once|return|static|switch|throw|trait|try|unset|use|var|while|xor|yield|__CLASS__|__DIR__|__FILE__|__FUNCTION__|__LINE__|__METHOD__|__NAMESPACE__|__TRAIT__)\b 0:keyword

# Highlighter for html with php tags in it, i.e. the structure of conventional php files
add-highlighter shared/php-file regions
add-highlighter shared/php-file/html default-region ref html
add-highlighter shared/php-file/php  region '<\?(php)?'     '\?>'      ref php

# Commands
# ‾‾‾‾‾‾‾‾

define-command -hidden php-filter-around-selections %{
    # remove trailing white spaces
    try %{ execute-keys -draft -itersel <a-x> s \h+$ <ret> d }
}

define-command -hidden php-indent-on-char %<
    evaluate-commands -draft -itersel %<
        # align closer token to its opener when alone on a line
        try %/ execute-keys -draft <a-h> <a-k> ^\h+[\]}]$ <ret> m s \A|.\z <ret> 1<a-&> /
    >
>

define-command -hidden php-indent-on-new-line %<
    evaluate-commands -draft -itersel %<
        # copy // comments prefix and following white spaces
        try %{ execute-keys -draft k <a-x> s ^\h*\K#\h* <ret> y gh j P }
        # preserve previous line indent
        try %{ execute-keys -draft \; K <a-&> }
        # filter previous line
        try %{ execute-keys -draft k : php-filter-around-selections <ret> }
        # indent after lines beginning / ending with opener token
        try %_ execute-keys -draft k <a-x> <a-k> ^\h*[[{]|[[{]$ <ret> j <a-gt> _
    >
>

define-command -hidden php-trim-autoindent %{
    # remove the line if it's empty when leaving the insert mode
    try %{ execute-keys -draft <a-x> 1s^(\h+)$<ret> d }
}

define-command -hidden php-indent-on-newline %< evaluate-commands -draft -itersel %<
    execute-keys \;
    try %<
        # if previous line is part of a comment, do nothing
        execute-keys -draft <a-?>/\*<ret> <a-K>^\h*[^/*\h]<ret>
    > catch %<
        # else if previous line closed a paren, copy indent of the opening paren line
        execute-keys -draft k<a-x> 1s(\))(\h+\w+)*\h*(\;\h*)?$<ret> m<a-\;>J <a-S> 1<a-&>
    > catch %<
        # else indent new lines with the same level as the previous one
        execute-keys -draft K <a-&>
    >
    # remove previous empty lines resulting from the automatic indent
    try %< execute-keys -draft k <a-x> <a-k>^\h+$<ret> Hd >
    # indent after an opening brace or parenthesis at end of line
    try %< execute-keys -draft k <a-x> s[{[(]\h*$<ret> j <a-gt> >
    # indent after a statement not followed by an opening brace
    try %< execute-keys -draft k <a-x> <a-k>\b(if|else|for|while)\h*\(.+?\)\h*$<ret> j <a-gt> >
> >

define-command -hidden php-indent-on-opening-curly-brace %[
    # align indent with opening paren when { is entered on a new line after the closing paren
    try %[ execute-keys -draft -itersel h<a-F>)M <a-k> \A\(.*\)\h*\n\h*\{\z <ret> <a-S> 1<a-&> ]
]

define-command -hidden php-indent-on-closing-curly-brace %[
    # align to opening curly brace when alone on a line
    try %[ execute-keys -itersel -draft <a-h><a-:><a-k>^\h+\}$<ret>hm<a-S>1<a-&> ]
]

define-command -hidden php-insert-on-newline %[ evaluate-commands -itersel -draft %[
    execute-keys \;
    try %[
        evaluate-commands -draft %[
            # copy the commenting prefix
            execute-keys -save-regs '' k <a-x>1s^\h*(//+\h*)<ret> y
            try %[
                # if the previous comment isn't empty, create a new one
                execute-keys <a-x><a-K>^\h*//+\h*$<ret> j<a-x>s^\h*<ret>P
            ] catch %[
                # if there is no text in the previous comment, remove it completely
                execute-keys d
            ]
        ]
    ]
    try %[
        # if the previous line isn't within a comment scope, break
        execute-keys -draft k<a-x> <a-k>^(\h*/\*|\h+\*(?!/))<ret>

        # find comment opening, validate it was not closed, and check its using star prefixes
        execute-keys -draft <a-?>/\*<ret><a-H> <a-K>\*/<ret> <a-k>\A\h*/\*([^\n]*\n\h*\*)*[^\n]*\n\h*.\z<ret>

        try %[
            # if the previous line is opening the comment, insert star preceeded by space
            execute-keys -draft k<a-x><a-k>^\h*/\*<ret>
            execute-keys -draft i*<space><esc>
        ] catch %[
           try %[
                # if the next line is a comment line insert a star
                execute-keys -draft j<a-x><a-k>^\h+\*<ret>
                execute-keys -draft i*<space><esc>
            ] catch %[
                try %[
                    # if the previous line is an empty comment line, close the comment scope
                    execute-keys -draft k<a-x><a-k>^\h+\*\h+$<ret> <a-x>1s\*(\h*)<ret>c/<esc>
                ] catch %[
                    # if the previous line is a non-empty comment line, add a star
                    execute-keys -draft i*<space><esc>
                ]
            ]
        ]

        # trim trailing whitespace on the previous line
        try %[ execute-keys -draft s\h+$<ret> d ]
        # align the new star with the previous one
        execute-keys K<a-x>1s^[^*]*(\*)<ret>&
    ]
] ]

# Initialization
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾

hook -group php-highlight global WinSetOption filetype=php %{ add-highlighter window/ ref php-file }

hook global WinSetOption filetype=php %{
    hook window ModeChange insert:.* -group php-hooks  php-filter-around-selections
    hook window InsertChar \n php-insert-on-newline
    hook window InsertChar \n php-indent-on-newline
    hook window InsertChar \{ php-indent-on-opening-curly-brace
    hook window InsertChar \}|.* php-indent-on-char
}

hook -group php-highlight global WinSetOption filetype=(?!php).* %{ remove-highlighter window/php-file }

hook global WinSetOption filetype=(?!php).* %{
    remove-hooks window php-indent
    remove-hooks window php-hooks
}

# Customization
# -------------

define-command php-format %{
    write
    nop %sh{ php-cs-fixer fix $kak_buffile &> /dev/null }
    edit %val{buffile}
    echo "Formatted"
}

filetype-hook php %{
  map-all filetype %{
    = 'php-format' 'Format file'
  }
}
