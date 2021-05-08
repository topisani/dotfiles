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

  filetype-hook (css|scss|typescript|javascript|php|python|java|rust|dart|haskell|ocaml|latex) %{
    lsp-setup
  }
}
