import util

# Setup kak-lsp
eval %sh{ RUST_BACKTRACE=1 kak-lsp --kakoune -v -s $kak_session }
set global lsp_cmd "env RUST_LOG=debug kak-lsp --log /tmp/kak-lsp-%val{session}.log -v -v -v -v -v -v -v -s %val{session}"

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
        s 'enter-user-mode lsp'        'lsp...'
    }

    try %{
      lsp-enable
    }
}

def lsp-restart -docstring "Restart lsp server" %{
    lsp-stop
    lsp-start
}

filetype-hook (javascript|php|python|java|rust) %{
  lsp-setup
}

filetype-hook make %{
    addhl window/wrap wrap -word -marker ">> "
}
