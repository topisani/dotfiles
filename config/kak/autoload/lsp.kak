provide-module lsp %{
  # Setup kak-lsp
  eval %sh{ kak-lsp --kakoune -s $kak_session --log /tmp/kak-lsp-%val{session}.log }
  set global lsp_cmd "kak-lsp -s %val{session} --log /tmp/kak-lsp-%val{session}.log "
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
  
  def -hidden lsp-insert-c-n %{
   try %{
     lsp-snippets-select-next-placeholders
     exec '<a-;>d'
   } catch %{
     exec -with-hooks '<c-n>'
   }
  }

  def lsp-setup %{
      map-all lsp -scope buffer %{
          R 'lsp-rename-prompt'                          'Rename at point'
          j 'lsp-find-error -include-warnings'           'Next diagnostic'
          k 'lsp-find-error -include-warnings -previuos' 'Previous diagnostic'
      }

      map-all filetype -scope buffer %{
          s 'enter-user-mode lsp' 'lsp...'
          , 'lsp-code-actions'    'lsp code actions'
          = 'lsp-format'          'lsp-format'
      }

      lsp-enable-window
      
      map global insert <c-n> "<a-;>: lsp-insert-c-n<ret>"
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

  filetype-hook (css|scss|typescript|javascript|php|python|java|dart|haskell|ocaml|latex) %{
    lsp-setup
  }
  
  filetype-hook rust %{
    lsp-setup
    lsp-enable-semantic-tokens
    
    hook window -group rust-inlay-hints BufReload .* rust-analyzer-inlay-hints
    hook window -group rust-inlay-hints NormalIdle .* rust-analyzer-inlay-hints
    hook window -group rust-inlay-hints InsertIdle .* rust-analyzer-inlay-hints
    hook -once -always window WinSetOption filetype=.* %{
      remove-hooks window rust-inlay-hints
    }
  }

  def lsp-enable-semantic-tokens %{
    hook window -group semantic-tokens BufReload .* lsp-semantic-tokens
    hook window -group semantic-tokens NormalIdle .* lsp-semantic-tokens
    hook window -group semantic-tokens InsertIdle .* lsp-semantic-tokens
    hook -once -always window WinSetOption filetype=.* %{
      remove-hooks window semantic-tokens
    }
  }
  
}
