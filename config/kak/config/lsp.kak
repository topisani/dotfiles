# Setup kak-lsp

eval %sh{ kak-lsp --kakoune -s $kak_session --log /tmp/kak-lsp-%val{session}.log }

hook -always global KakEnd .* %{ nop %sh{
  rm /tmp/kak-lsp-$kak_session.log
}}

def lsp-log %{
  eval "edit -scroll -fifo /tmp/kak-lsp-%val[session].log *lsp-log*"
}


lsp-auto-hover-enable
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
map global lsp n ': lsp-find-error -include-warnings<ret>'           -docstring 'Next diagnostic'
map global lsp p ': lsp-find-error -include-warnings -previuos<ret>' -docstring 'Previous diagnostic'
map global lsp j ': lsp-next-symbol<ret>' -docstring 'Next symbol'
map global lsp k ': lsp-previous-symbol<ret>' -docstring 'Prev symbol'
map global lsp J ': lsp-next-function<ret>' -docstring 'Next function'
map global lsp K ': lsp-previous-function<ret>' -docstring 'Prev function'
map global lsp "'" ': lsp-code-actions<ret>'    -docstring 'Code Actions...'

def lsp-setup %{
  map window filetype s   ': enter-user-mode lsp<ret>' -docstring 'lsp...'
  map window normal <c-e> ': enter-user-mode lsp<ret>' -docstring 'lsp...'
  map window filetype ,   ': lsp-code-actions<ret>'    -docstring 'lsp code actions'
  map window filetype =   ': lsp-format<ret>'          -docstring 'lsp-format'

  lsp-enable-window
  lsp-inlay-diagnostics-enable window
  lsp-inlay-code-lenses-enable window

  hook -group lsp window InsertCompletionShow .* %{
    unmap window insert <c-n>
  }
  hook -group lsp window InsertCompletionHide .* %{
    map window insert <c-n> '<a-;>: lsp-snippets-select-next-placeholders<ret>'
  }
  map window insert <c-n> '<a-;>: lsp-snippets-select-next-placeholders<ret>'
  map window normal <c-n> ': lsp-snippets-select-next-placeholders<ret>'
  
  map window object a '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
  map window object <a-a> '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
  map window object e '<a-semicolon>lsp-object Function Method<ret>' -docstring 'LSP function or method'
  map window object k '<a-semicolon>lsp-object Class Interface Struct<ret>' -docstring 'LSP class interface or struct'
  map window object d '<a-semicolon>lsp-diagnostic-object --include-warnings<ret>' -docstring 'LSP errors and warnings'
  map window object D '<a-semicolon>lsp-diagnostic-object<ret>' -docstring 'LSP errors'
 

  #set buffer idle_timeout 250
}

def lsp-restart -docstring "Restart lsp server" %{
  lsp-stop
  lsp-start
}

filetype-hook make %{
  addhl window/wrap wrap -word -marker ">> "
}

def -hidden -override lsp-show-error -params 1 -docstring "Render error" %{
  echo -debug "kak-lsp:" %arg{1}
  echo -markup " {Error}%arg{1}"
}

def -hidden -override lsp-perform-code-action -params .. %{
  popup -title "Code Actions" -h 15 -w 80 krc-fzf menu %arg{@}
}

def -hidden -override lsp-menu -params .. %{
  popup krc-fzf menu %arg{@}
}

# def -hidden -override lsp-show-goto-choices -params 2 -docstring "Render goto choices" %{
#   connect bottom-panel sh -c "echo '%arg{@}' | krc-fzf jump"
# }

filetype-hook (css|scss|typescript|javascript|php|python|java|dart|haskell|ocaml|latex|markdown) %{
  lsp-setup
}

def lsp-enable-semantic-tokens %{
  hook window -group semantic-tokens BufReload .* lsp-semantic-tokens
  hook window -group semantic-tokens NormalIdle .* lsp-semantic-tokens
  hook window -group semantic-tokens InsertIdle .* lsp-semantic-tokens
  
  hook -once -always window WinSetOption filetype=.* %{
    remove-hooks window semantic-tokens
  }
}
