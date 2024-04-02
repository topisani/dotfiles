declare-option str himalaya_account ""
declare-option int himalaya_page 1
declare-option str himalaya_folder ""

remove-hooks global himalaya

hook -group himalaya global BufSetOption filetype=himalaya-list %{
    add-highlighter buffer/himalaya-list group
    add-highlighter buffer/himalaya-list/ regex '^(?:((?:ID|FLAGS|SUBJECT|FROM|DATE) *)│?)+' 0:+u@title
    add-highlighter buffer/himalaya-list/ regex '│' 0:+a@comment
    add-highlighter buffer/himalaya-list/ regex '^#[^\n]*' 0:comment
    add-highlighter buffer/himalaya-list/ regex '^\d+' 0:builtin
    add-highlighter buffer/himalaya-list/ regex '^\d+ *│[^│]*✷[^\n]*' 0:+b
    hook -once -always buffer BufSetOption filetype=.* %{ remove-highlighter buffer/himalaya-list } 
    
    map buffer normal <ret> :himalaya-jump<ret>
}

define-command -override himalaya -params .. %{ eval %sh{

    kakquote() {
        printf "%s" "$1" | sed "s/'/''/g; 1s/^/'/; \$s/\$/'/"
    }
    perlquote() {
        printf "%s" "$1" | sed "s/\\\\/\\\\\\\\/g; s/'/\\\\'/g; 1s/^/'/; \$s/\$/'/"
    }

    himalaya_show_output() {
        local filetype
        cmd=$(cat)
        filetype=${1:-himalaya}
        buffer=${2:-*himalaya*}
        client=${3:-${kak_opt_toolsclient}}
        output=$(mktemp -d "${TMPDIR:-/tmp}"/kak-himalaya.XXXXXXXX)/fifo
        echo "$cmd" >&2
        mkfifo ${output}
        ( (
            eval "$cmd"
        ) > ${output} 2>&1 & ) > /dev/null 2>&1 < /dev/null

        printf %s "evaluate-commands -try-client '$client' '
                  try %{
                      delete-buffer! ${buffer}
                  }
                  edit! -fifo ${output} ${buffer}
                  set-option buffer filetype ${filetype}
                  hook -always -once buffer BufCloseFifo .* %{
                      nop %sh{ rm -r $(dirname ${output}) }
                  }
        '"
    }
    
    himalaya_list() {
        args=""
        [ -n $kak_opt_himalaya_account ] && args="$args --account '$kak_opt_himalaya_account'"
        [ -n $kak_opt_himalaya_folder ] && args="$args --folder '$kak_opt_himalaya_folder'"
        [ -n $kak_opt_himalaya_page ] && args="$args --page '$kak_opt_himalaya_page'"
        
        himalaya_show_output himalaya-list *himalaya-list* <<EOF
            himalaya envelope list --page-size 1000 -w $kak_window_width | sed '/./,\$!d'
EOF
    }
    
    himalaya_read() {
        [ -n "$kak_opt_himalaya_account" ] && args="$args --account $kak_opt_himalaya_account"
        [ -n "$kak_opt_himalaya_folder" ] && args="$args --folder $kak_opt_himalaya_folder"
        echo "himalaya message read $@ $args" | himalaya_show_output mail "" "$kak_opt_jumpclient"
    }
    
    himalaya_flag() {
        [ -n "$kak_opt_himalaya_account" ] && args="$args --account $kak_opt_himalaya_account"
        [ -n "$kak_opt_himalaya_folder" ] && args="$args $kak_opt_himalaya_folder"
        echo "himalaya-select-id"
        op=$1; shift
        echo "
            nop %sh{ himalaya flags $op $args $@ \$kak_reg_dot }
            himalaya-list
        "
    }
    
    cmd=${1:-list}; shift
    "himalaya_$cmd" "$@"
} }

define-command -override himalaya-list %{
    evaluate-commands -try-client %opt{toolsclient} -save-regs ab %{
        try %{
            himalaya-select-id 
            set-register b "^%reg{.}\b"
        } catch "set-register b ''"
        edit! -scratch *himalaya-list*
        set-option buffer filetype ""
        set-option buffer filetype himalaya-list
        set buffer himalaya_account %opt{himalaya_account}
        set buffer himalaya_page %opt{himalaya_page}
        set buffer himalaya_folder %opt{himalaya_folder}
        set-register a %sh{
            [ -n "$kak_opt_himalaya_account" ] && args="$args --account $kak_opt_himalaya_account"
            [ -n "$kak_opt_himalaya_page" ] && args="$args --page $kak_opt_himalaya_page"
            [ -n "$kak_opt_himalaya_folder" ] && args="$args $kak_opt_himalaya_folder"
            echo "# himalaya envelope list$args "
            himalaya envelope list --page-size 1000 -w $(($kak_window_width - 7)) $args "$@" | sed '/./,$!d'
        }
        exec -draft '%"aR'
        try %{ exec 'gk"bn' }
    }
}

define-command -override -hidden himalaya-select-id %{
   try %{ exec xs^\d+<ret> } catch %{ fail "Could not find email ID on line" }
}

define-command -override himalaya-jump %{
    eval -draft %{
        himalaya-select-id
        himalaya read %reg{.}
    }
}

define-command -override himalaya-account -params 1 %{
    set global himalaya_account %arg{1}
    try %{ eval -buffer *himalaya-list* himalaya-list }
}
complete-command -menu himalaya-account shell-script-candidates %{ himalaya account list -o json | jq -r '.[].name' }

define-command -override himalaya-folder -params 1 %{
    set global himalaya_folder %arg{1}
    try %{ eval -buffer *himalaya-list* himalaya-list }
}
complete-command -menu himalaya-folder shell-script-candidates %{ himalaya folder list -o json | jq -r '.[].name' }
