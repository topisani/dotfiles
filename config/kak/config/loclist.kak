define-command -override loclist-grep -docstring "grep and select matches with <a-s>
works best if grepcmd uses a regex flavor simlar to Kakoune's
" -params .. %{
  try %{
    evaluate-commands %sh{ [ -z "$1" ] && echo fail }
    set-register / "(?S)%arg{1}"
    grep %arg{@}
  } catch %{
    execute-keys -save-regs '' *
    evaluate-commands -save-regs l %{
      evaluate-commands -verbatim grep -- %sh{ printf %s "$kak_main_reg_slash" }
    }
  }
  loclist-map-quickselect
}
try %{ complete-command loclist-grep file }

define-command -override loclist-map-quickselect %{ evaluate-commands -save-regs 'l' %{
  evaluate-commands -try-client %opt{toolsclient} %sh{
    printf %s "map buffer=$kak_opt_loclist_buffer normal <tab> '"
    printf %s '%S^<ret><a-h>/^.*?:\d+(?::\d+)?:<ret>'
    printf %s '<a-semicolon>l<a-l>'
    printf %s "s$(printf %s "$kak_main_reg_slash" | sed s/"'"/"''"/g"; s/</<lt>/g")<ret>"
    printf %s "'"
  }
}}

declare-option -hidden str loclist_buffer
declare-option -hidden str-list loclist_stack

define-command -override loclist-jump -params 1 -docstring \
'loclist-jump <next|previous>: Jump to the next/previous match in a grep-like buffer' %{
  eval %sh{
  	[ -z "$kak_opt_loclist_buffer" ] && echo "fail No location list" && exit 0
    echo "lsp-$1-location $kak_opt_loclist_buffer"
  }
}

define-command -override loclist-stack-push -docstring "record location list buffer" %{
  evaluate-commands %sh{
    eval set -- $kak_quoted_opt_loclist_stack
    if printf '%s\n' "$@" | grep -Fxq -- "$kak_bufname"; then {
      exit
    } fi
    newbuf=$kak_bufname-$#
    echo "try %{ delete-buffer! $newbuf }"
    echo "rename-buffer $newbuf"
    echo "set-option -add global loclist_stack %val{bufname}"
  }
  set-option global loclist_buffer %val{bufname}
}

define-command -override loclist-stack-pop -docstring "restore location list buffer" %{
  evaluate-commands %sh{
    eval set -- $kak_quoted_opt_loclist_stack
    if [ $# -eq 0 ]; then {
      echo fail "loclist-stack-pop: no location list buffer to pop"
      exit
    } fi
    printf 'set-option global loclist_stack'
    top=
    while [ $# -ge 2 ]; do {
      top=$1
      printf ' %s' "$1"
      shift
    } done
    echo
    echo "delete-buffer $1"
    echo "set-option global loclist_buffer '$top'"
  }
  try %{
    evaluate-commands -try-client %opt{jumpclient} %{
      buffer %opt{loclist_buffer}
      grep-jump
    }
  }
}
define-command -override loclist-stack-clear -docstring "clear location list buffers" %{
  evaluate-commands %sh{
    eval set --  $kak_quoted_opt_loclist_stack
    printf 'try %%{ delete-buffer %s }\n' "$@"
  }
  set-option global loclist_stack
}

# set-option global disabled_hooks (?:.*)-insert|grep-jump|(?!grep)(?!lsp-goto)(?:.*)-highlight
set-option global disabled_hooks (?:.*)-insert|grep-jump
declare-option regex loclist_buffer_regex \*(?:callees|callers|diagnostics|goto|find|grep|implementations|lint-output|references)\*(?:-\d+)?

hook -group loclist global WinDisplay %opt{loclist_buffer_regex} %{
  loclist-stack-push
}

hook -group loclist global GlobalSetOption '^loclist_buffer=(.*)$' %{
  alias "buffer=%opt{loclist_buffer}" w grep-write
}

alias global buffers-pop loclist-stack-pop
alias global buffer-clear loclist-stack-clear
