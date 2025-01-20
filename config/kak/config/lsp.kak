# Setup kak-lsp

eval %sh{ kak-lsp --kakoune }

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
set global lsp_file_watch_support true
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
  lsp-enable
  # lsp-auto-hover-enable
  lsp-inlay-diagnostics-enable global
  lsp-inlay-code-lenses-enable global

  hook -group lsp global InsertCompletionShow .* %{
    unmap window insert <c-n>
  }
  hook -group lsp global InsertCompletionHide .* %{
    map window insert <c-n> '<a-;>: lsp-snippets-select-next-placeholders<ret>'
  }

  map global insert <c-n> '<a-;>: lsp-snippets-select-next-placeholders<ret>'
  # map window normal <c-n> ': lsp-snippets-select-next-placeholders<ret>'

  map global object a '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
  map global object <a-a> '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
  map global object e '<a-semicolon>lsp-object Function Method<ret>' -docstring 'LSP function or method'
  map global object k '<a-semicolon>lsp-object Class Interface Struct<ret>' -docstring 'LSP class interface or struct'
  map global object d '<a-semicolon>lsp-diagnostic-object --include-warnings<ret>' -docstring 'LSP errors and warnings'
  map global object D '<a-semicolon>lsp-diagnostic-object<ret>' -docstring 'LSP errors'
}

map global filetype s   ': enter-user-mode lsp<ret>' -docstring 'lsp...'
map global normal <c-e> ': enter-user-mode lsp<ret>' -docstring 'lsp...'
map global filetype ,   ': lsp-code-actions<ret>'    -docstring 'lsp code actions'
map global filetype =   ': lsp-format<ret>'          -docstring 'lsp-format'
map global normal <c-h> ': lsp-hover<ret>'           -docstring 'lsp-hover'
map global normal <c-H> ': lsp-hover-buffer<ret>'    -docstring 'lsp-hover'


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
  hook window -group lsp-semantic-tokens BufReload .* lsp-semantic-tokens
  hook window -group lsp-semantic-tokens NormalIdle .* lsp-semantic-tokens
  hook window -group lsp-semantic-tokens InsertIdle .* lsp-semantic-tokens

  hook -once -always window WinSetOption filetype=.* %{
    remove-hooks window semantic-tokens
  }
}

filetype-hook (css|scss|typescript|javascript|php|python|java|dart|haskell|ocaml|latex|markdown|toml|zig|go|templ) %{
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

rmhooks global lsp-filetype-python
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
    args = ["-c", "cd '$root'; python-env-run ruff server"]
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

remove-hooks global lsp-filetype-rust
hook -group lsp-filetype-rust global BufSetOption filetype=rust %{
  set-option buffer lsp_servers %exp{
      [rust-analyzer]
      root_globs = ["Cargo.toml"]
      command = "sh"
      args = [
          "-c",
          """
              if path=$(rustup which rust-analyzer 2>/dev/null); then
                  exec "$path"
              else
                  exec rust-analyzer
              fi
          """,
      ]
      [rust-analyzer.experimental]
      commands.commands = ["rust-analyzer.runSingle"]
      hoverActions = true
      [rust-analyzer.settings.rust-analyzer]
      # See https://rust-analyzer.github.io/manual.html#configuration
      # cargo.features = []
      check.command = "clippy"
      # If you get 'unresolved proc macro' warnings, you have two options
      # 1. The safe choice is two disable the warning:
      # diagnostics.disabled = ["unresolved-proc-macro"]
      # 2. Or you can opt-in for proc macro support
      procMacro.enable = true
      procMacro.attributes.enable = true
      cargo.loadOutDirsFromCheck = true
      cargo.runBuildScripts = true
      cargo.features = "all"
      # default settings gives "can't find crate test" for no_std targets
      checkOnSave.allTargets = true
      checkOnSave.extraArgs = ["--bins"]
      checkOnSave.command = "clippy"
      check.allTargets = true
      check.extraArgs = ["--bins"]
      # See https://github.com/rust-analyzer/rust-analyzer/issues/6448
      inlayHints.expressionAdjustmentHints.enable = false
      inlayHints.closureReturnTypeHints.enable = true
      inlayHints.lifetimeElisionHints.enable = "skip_trivial"
      imports.granularity.group = "item"
      workspace.symbol.search.scope = "workspace"
      workspace.symbol.search.kind = "all_symbols"
      # These can fail on try blocks and similar syntax that is not implemented in RA
      # diagnostics.disabled = ["type-mismatch"]
    }
}

# rmhooks global lsp-filetype-devicetree
# hook -group lsp-filetype-devicetree global BufSetOption filetype=devicetree %{
#   set-option buffer lsp_servers %exp{
#       [ginko]
#       root_globs = [".git"]
#       command = "ginko_ls"
#   }
# }


rmhooks global lsp-project-zephyr
hook -group lsp-project-zephyr global BufSetOption filetype=(kconfig|conf) %{
   eval %sh{
      root=$(eval "$kak_opt_lsp_find_root" .west-lsp $(: kak_buffile))
      [ -e "$root/.west-lsp" ] || exit 0
      cat <<EOF
      set-option buffer lsp_servers %{
         [west]
         root = '$root'
         command = "west-lsp"
         args = ["kconfig-lsp"]
      }
EOF
   }
}

hook -group lsp-project-zephyr global BufSetOption filetype=(devicetree) %{
   eval %sh{
      root=$(eval "$kak_opt_lsp_find_root" .west/config $(: kak_buffile))

      settings=$(west-lsp dts-lsp-settings --root-dir "$root")

      cat <<EOF
      set-option buffer lsp_servers %{
         [devicetree]
         root = '$root'
         # command = "npm"
         # args = ["x", "--", "devicetree-language-server", "--stdio"]
         command = "node"
         args = ["/home/topisani/git/dts-lsp/server/dist/server.js", "--stdio"]
         settings_section = "_"

      $settings
      }
EOF
   }
}

lsp-setup
