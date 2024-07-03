hook global BufCreate .*/Kconfig[^/]* %{
    set-option buffer filetype kconfig
}

hook global WinSetOption filetype=kconfig %{
    require-module kconfig
}

hook -group kconfig-highlight global WinSetOption filetype=kconfig %{
    add-highlighter window/kconfig ref kconfig
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/kconfig }
}

provide-module kconfig %{

add-highlighter shared/kconfig regions
add-highlighter shared/kconfig/code default-region group
add-highlighter shared/kconfig/comment  region '#' '$' fill comment

add-highlighter shared/kconfig/code/value regex '\b(m|M|n|N|y|Y|\d+)\b' 0:value
add-highlighter shared/kconfig/code/keyword regex '\b(choice|comment|config|endchoice|endif|endmenu|if|mainmenu|menu|menuconfig|source|rsource|allnoconfig_y|defconfig_list|default|depends on|help|imply|modules|option|prompt|range|select|visible if|bool|def_bool|def_tristate|hex|int|string|tristate)\b' 0:keyword
add-highlighter shared/kconfig/code/operator regex '\b(\|\||&&|!)\b' 0:operator

add-highlighter shared/kconfig/quoted region %{(?<!\\)(?:\\\\)*\K"} %{(?<!\\)(?:\\\\)*"} group

add-highlighter shared/kconfig/quoted/ fill string
add-highlighter shared/kconfig/quoted/ regex '\$\{\w+\}' 0:variable
}
