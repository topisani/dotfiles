# Setup kak-lsp

eval %sh{ kak-lsp --kakoune }

hook -always global KakEnd .* %{ nop %sh{
  rm /tmp/kak-lsp-$kak_session.log
}}

def lsp-log %{
  eval "edit -scroll -fifo /tmp/kak-lsp-%val[session].log *lsp-log*"
}

declare-option -hidden str lsp_auto_hover_selection

define-command lsp-check-auto-hover -override -params 1 %{
  eval %sh{
    [ "$kak_selection" = "$kak_opt_lsp_auto_hover_selection" ] && exit
    echo "$1"
    echo "set window lsp_auto_hover_selection %{$kak_selection_desc}"
  }
}

define-command lsp-auto-hover-enable -override -params 0..1 -client-completion \
    -docstring "lsp-auto-hover-enable [<client>]: enable auto-requesting hover info for current position

If a client is given, show hover in a scratch buffer in that client instead of the info box" %{
    evaluate-commands %sh{
        hover=lsp-hover
        [ $# -eq 1 ] && hover="lsp-hover-buffer $1"
        printf %s "hook -group lsp-auto-hover window NormalIdle .* %{ lsp-check-auto-hover '$hover' }"
    }
}

lsp-auto-signature-help-enable
set global lsp_auto_highlight_references true

set global lsp_hover_max_lines 20
set global lsp_hover_anchor false

# def -hidden lsp-insert-c-n %{
#  try %{
#    lsp-snippets-select-next-placeholders
#    exec '<a-;>d'
#  } catch %{
#    exec '<c-n>'
#  }
# }

# map global lsp R ': lsp-rename-prompt<ret>'                          -docstring 'Rename at point'
map global lsp 1 :lsp-enable<ret> -docstring "lsp-enable"
map global lsp w :lsp-enable-window<ret> -docstring "lsp-enable-window"
map global lsp 2 :lsp-disable<ret> -docstring "lsp-disable"
map global lsp W :lsp-disable-window<ret> -docstring "lsp-disable-window"
map global lsp F :lsp-formatting-sync<ret> -docstring "lsp-formatting-sync"
map global lsp n ': lsp-find-error -include-warnings<ret>'           -docstring 'Next diagnostic'
map global lsp p ': lsp-find-error -include-warnings -previuos<ret>' -docstring 'Previous diagnostic'
map global lsp j ': lsp-next-symbol<ret>' -docstring 'Next symbol'
map global lsp k ': lsp-previous-symbol<ret>' -docstring 'Prev symbol'
map global lsp J ': lsp-next-function<ret>' -docstring 'Next function'
map global lsp K ': lsp-previous-function<ret>' -docstring 'Prev function'
map global lsp "'" ': lsp-code-actions<ret>'    -docstring 'Code Actions...'

# Recommended mappings
map global user l %{:enter-user-mode lsp<ret>} -docstring "LSP mode"
map global goto d '<esc>:lsp-definition<ret>' -docstring 'definition'
map global goto r '<esc>:lsp-references<ret>' -docstring 'references'
map global goto y '<esc>:lsp-type-definition<ret>' -docstring 'type definition'

def lsp-setup %{
  lsp-enable-window
  # lsp-auto-hover-enable
  lsp-inlay-diagnostics-enable window
  lsp-inlay-code-lenses-enable window

  hook -group lsp window InsertCompletionShow .* %{
    unmap window insert <c-n>
  }
  hook -group lsp window InsertCompletionHide .* %{
    map window insert <c-n> '<a-;>: lsp-snippets-select-next-placeholders<ret>'
  }
  
  map window insert <c-n> '<a-;>: lsp-snippets-select-next-placeholders<ret>'
  # map window normal <c-n> ': lsp-snippets-select-next-placeholders<ret>'
  
  map window filetype s   ': enter-user-mode lsp<ret>' -docstring 'lsp...'
  map window normal <c-e> ': enter-user-mode lsp<ret>' -docstring 'lsp...'
  map window filetype ,   ': lsp-code-actions<ret>'    -docstring 'lsp code actions'
  map window filetype =   ': lsp-format<ret>'          -docstring 'lsp-format'
 
  map window object a '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
  map window object <a-a> '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
  map window object e '<a-semicolon>lsp-object Function Method<ret>' -docstring 'LSP function or method'
  map window object k '<a-semicolon>lsp-object Class Interface Struct<ret>' -docstring 'LSP class interface or struct'
  map window object d '<a-semicolon>lsp-diagnostic-object --include-warnings<ret>' -docstring 'LSP errors and warnings'
  map window object D '<a-semicolon>lsp-diagnostic-object<ret>' -docstring 'LSP errors'
}

# def lsp-restart -docstring "Restart lsp server" %{
#   lsp-stop
#   lsp-start
# }

filetype-hook make %{
  addhl window/wrap wrap -word -marker ">> "
}

def -hidden -override lsp-show-error -params 1 -docstring "Render error" %{
  echo -debug "kak-lsp:" %arg{1}
  echo -markup " {Error}%arg{1}"
}

# def -hidden -override lsp-perform-code-action -params .. %{
#   popup -title "Code Actions" -h 15 -w 80 krc-fzf menu %arg{@}
# }

# def -hidden -override lsp-menu -params .. %{
#   popup krc-fzf menu %arg{@}
# }

# def -hidden -override lsp-show-goto-choices -params 2 -docstring "Render goto choices" %{
#   connect bottom-panel sh -c "echo '%arg{@}' | krc-fzf jump"
# }

def lsp-enable-semantic-tokens %{
  hook window -group semantic-tokens BufReload .* lsp-semantic-tokens
  hook window -group semantic-tokens NormalIdle .* lsp-semantic-tokens
  hook window -group semantic-tokens InsertIdle .* lsp-semantic-tokens
  
  hook -once -always window WinSetOption filetype=.* %{
    remove-hooks window semantic-tokens
  }
}

filetype-hook (css|scss|typescript|javascript|php|python|java|dart|haskell|ocaml|latex|markdown|toml|zig|go|templ) %{
  lsp-setup
  lsp-enable-semantic-tokens
}

# Modeline progress
declare-option -hidden str modeline_lsp_progress ""
define-command -hidden -params 6 -override lsp-handle-progress %{
    set global modeline_lsp_progress %sh{
        if ! "$6"; then
            echo "$2${5:+" ($5%)"}${4:+": $4"} "
        fi
    }
}


define-command tsserver-organize-imports -docstring "Ask the typescript language server to organize imports in the buffer" %{
    lsp-execute-command _typescript.organizeImports """[\""%val{buffile}\""]"""
}

 
require-module jump

define-command -override -hidden jump-select %{
    evaluate-commands -draft %{
        execute-keys ',xs^([^:\n]+):(\d+):(\d+)?<ret>'
        set-register a %reg{1} %reg{2} %reg{3}
    }
}

define-command -override -hidden jump-select-next %{
    # First jump to end of buffer so that if jump_current_line == 0
    # 0g<a-l> will be a no-op and we'll jump to the first result.
    # Yeah, thats ugly...
    execute-keys ge %opt{jump_current_line}g<a-l> /^[^:\n]+:\d+:<ret>
}

define-command -override -hidden jump-select-previous %{
    # See comment in jump-select-next
    execute-keys ge %opt{jump_current_line}g<a-h> <a-/>^[^:\n]+:\d+:<ret>
}

define-command -override -hidden jump %{
    evaluate-commands -save-regs a %{ # use evaluate-commands to ensure jumps are collapsed
        jump-select
        try %{
            set-option buffer jump_current_line %val{cursor_line}
            evaluate-commands -try-client %opt{jumpclient} -verbatim -- edit -existing -- %reg{a}
            try %{ focus %opt{jumpclient} }
        }
    }
}

declare-option line-specs jump_opt_locations

define-command -override -hidden jump-opt-select %{
    evaluate-commands -draft %{
        eval %sh{
            eval "set -- $kak_quoted_opt_jump_opt_locations"
            shift
            printf "%s\n" "$@" | awk -F'|' -v cur=$kak_opt_jump_current_line '
                $1 == cur { gsub(":", " ", $2); print "set-register a " $2 }
            '
        }
    }
}

define-command -override -hidden jump-opt-select-next %{
    exec %sh{
        eval "set -- $kak_quoted_opt_jump_opt_locations"
        shift
        printf "%s\n" "$@" | awk -F'|' -v cur=$kak_opt_jump_current_line '
            NR == 1 { loc=$1 }
            prev == cur { loc=$1; exit }
            { prev=$1 }
            END { print loc "g" }
        '
    }
}

define-command -override -hidden jump-opt-select-previous %{
    exec %sh{
        eval "set -- $kak_quoted_opt_jump_opt_locations"
        shift
        printf "%s\n" "$@" | awk -F'|' -v cur=$kak_opt_jump_current_line '
            $1 == cur { exit }
            { loc=$1 }
            END { print loc "g" }
        '
    }
}

define-command -override -hidden jump-opt-convert %{
    eval -draft %{
        execute-keys '%<a-s>s^([^:\n]+):(\d+):(:?(\d+))?<ret>i<c-r>#|<esc>Gh'
        set buffer jump_opt_locations %val{timestamp} %val{selections}
        execute-keys <a-:>Ld
        alias buffer jump-select jump-opt-select
        alias buffer jump-select-previous jump-opt-select-previous
        alias buffer jump-select-next jump-opt-select-next
    }
}


define-command -override -hidden lsp-show-document-symbol -params 2 -docstring "Render document symbols" %{
    evaluate-commands -save-regs '"' -try-client %opt[docsclient] %{
        edit! -scratch *symbols*
        set-option buffer jump_current_line 0
        set-option buffer lsp_project_root "%arg{1}/"
        set-option buffer buffer_kind jump
        set-register '"' %arg{2}
        execute-keys Pgg
        addhl buffer/lsp-symbols-tree regex '[├└─│]' 0:comment
        addhl buffer/lsp-symbols-types regex '\([^()]+\)' 0:+di@type
        addhl buffer/lsp-symbols-line line '%opt{jump_current_line}' ,black+b
        jump-opt-convert
        map buffer normal <ret> ':jump<ret>'
    }
}

rmhooks global idetest
hook global -group idetest WinDisplay .* %{
  try %{
    eval %sh{ [ $kak_client = docs ] && echo fail }
  } catch %{
    rmhl window/numbers
    hook window -once -group idetest WinClose .* %{
      eval -client docs quit
    }
  }
}

set global lsp_semantic_tokens %{
  [
    { token = "", modifiers = [ "documentation", ], face = "documentation" },
    { token = "variable", modifiers = [ "mutable" ], face = "+i@variable" },
    { token = "", modifiers = [ "deprecated" ], face = "+u" },
    { token = "", modifiers = [ "intraDocLink" ], face = "+u" },
    { token = "method", modifiers = [ "trait" ], face = "memberFunction" },
    { token = "type", face = "type" },
    { token = "struct", face = "type" },
    { token = "class", face = "type" },
    { token = "interface", face = "type" },
    { token = "typeAlias", face = "type" },
    { token = "union", face = "type" },
    { token = "variable", face = "variable" },
    { token = "namespace", face = "module" },
    { token = "function", face = "function" },
    { token = "namespace", face = "module" },
    { token = "typeParameter", face = "type" },
    { token = "macro", face = "cppMacro" },
    { token = "formatSpecifier", face = "value" },
  ]
}

rmhooks global lsp-filtype-python
hook -group lsp-filetype-python global BufSetOption filetype=python %{
  set buffer lsp_servers %sh{
    root=$(eval "$kak_opt_lsp_find_root" pyproject.toml .git .hg $(: kak_buffile))
    cat <<EOF
    [pylsp]
    command = "sh"
    args = ["-c", "cd '$root' && python-env-run pylsp"]
    settings_section = "_"
    root = '$root'

    [pylsp.settings._]
    # See https://github.com/python-lsp/python-lsp-server#configuration
    # pylsp.configurationSources = ["flake8"]
    pylsp.plugins.jedi_completion.include_params = true
    pylsp.plugins.jedi_completion.fuzzy = true
    pylsp.plugins.rope_autoimport.enabled = true
    pylsp.plugins.rope_autoimport.memory = true

    # [language_server.pyright]
    # filetypes = ["python"]
    # roots = ["pyproject.toml", "requirements.txt", ".git"]
    # command = "python-env-run"
    # args = ["pyright-langserver", "--stdio"]
    # settings_section = "pyright"

    # [language_server.pyright.settings._]

    [ruff]
    command = "sh"
    args = ["-c", "cd '$root'; python-env-run ruff-lsp"]
    settings_section = "_"
    root = '$root'

    [ruff.settings._.globalSettings]
    organizeImports = true
    fixAll = true
EOF
  }
}

rmhooks global lsp-filetype-c-family
hook -group lsp-filetype-c-family global BufSetOption filetype=(?:c|cpp|objc) %{
    set-option buffer lsp_servers %exp{
        [clangd]
        command = "sh"
        args = [ '-c', 'TMPDIR=~/.cache/clangd/ clangd --query-driver=/home/topisani/**,/usr/**,arm-none-eabi-gcc,arm-none-eabi-*,arm-none-eabi-g++,**']
        root = '%sh{eval "$kak_opt_lsp_find_root" compile_commands.json .clangd .git .hg $(: kak_buffile)}'
    }
}

hook global BufSetOption filetype=(css|scss|typescript|javascript|php|python|java|dart|haskell|ocaml|latex|markdown|toml|zig) %{
  lsp-setup
  lsp-enable-semantic-tokens
}
