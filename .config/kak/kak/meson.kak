# Detection
# ‾‾‾‾‾‾‾‾‾

hook global BufCreate .*meson[.]build$ %{
    set-option buffer filetype meson
}

# Highlighters
# ‾‾‾‾‾‾‾‾‾‾‾‾

add-highlighter shared/meson regions
add-highlighter shared/meson/code           default-region group
add-highlighter shared/meson/string         region "'" "(?<!\\)(\\\\)*'"     group
add-highlighter shared/meson/tripple_string region "'''" "'''"               ref meson/string
add-highlighter shared/meson/comment        region '#' '$'                   group

add-highlighter shared/meson/comment/ fill comment
add-highlighter shared/meson/comment/ regex \b(FIXME|NOTE|NOTES|TODO|XXX)\b 0:keyword
add-highlighter shared/meson/string/ fill string
add-highlighter shared/meson/string/ regex @\w+@ 0:value

add-highlighter shared/meson/code/ regex \b(\w+)\b 1:variable
add-highlighter shared/meson/code/ regex \b(if|else|elif|endif|foreach|endforeach)\b 0:keyword
add-highlighter shared/meson/code/ regex \b(and|not|or)\b 0:operator
add-highlighter shared/meson/code/ regex (\w+)\h*\( 1:function
add-highlighter shared/meson/code/ regex (\w+)\h*:\h* 1:attribute
add-highlighter shared/meson/code/ regex (\w+)\h*=\h* 1:variable

add-highlighter shared/meson/code/ regex \
        \b(add_global_arguments|add_global_link_arguments|add_languages|add_project_arguments|add_project_link_arguments|add_test_setup|benchmark|both_libraries|build_machine|build_target|configuration_data|configure_file|custom_target|declare_dependency|dependency|disabler|environment|error|executable|files|find_library|find_program|generator|get_option|get_variable|gettext|host_machine|import|include_directories|install_data|install_headers|install_man|install_subdir|is_variable|jar|join_paths|library|meson|message|project|run_command|run_target|set_variable|shared_library|shared_module|static_library|subdir|subproject|target_machine|test|vcs_tag|warning)\b \
        0:builtin

# Commands
# ‾‾‾‾‾‾‾‾

define-command -hidden meson-filter-around-selections %{
    # remove trailing white spaces
    try %{ execute-keys -draft -itersel <a-x> s \h+$ <ret> d }
}

define-command -hidden meson-indent-on-new-line %{
    evaluate-commands -draft -itersel %{
        # copy '#' comment prefix and following white spaces
        try %{ execute-keys -draft k <a-x> s ^\h*\K#\h* <ret> y gh j P }
        # preserve previous line indent
        try %{ execute-keys -draft \; K <a-&> }
        # filter previous line
        try %{ execute-keys -draft k : meson-filter-around-selections <ret> }
    }
}

# Initialization
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾

hook -group meson-highlight global WinSetOption filetype=meson %{ add-highlighter window/meson ref meson }

hook global WinSetOption filetype=meson %{
    hook window ModeChange insert:.* -group meson-hooks  meson-filter-around-selections
    hook window InsertChar \n -group meson-indent meson-indent-on-new-line
}

hook -group meson-highlight global WinSetOption filetype=(?!meson).* %{ remove-highlighter window/meson }

hook global WinSetOption filetype=(?!meson).* %{
    remove-hooks window meson-indent
    remove-hooks window meson-hooks
}
