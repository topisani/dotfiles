import util

# Setup kak-lsp
eval %sh{ RUST_BACKTRACE=1 kak-lsp --kakoune -v -v -v -s $kak_session --log /tmp/kak-lsp-%val{session}.log }
set global lsp_cmd "env RUST_BACKTRACE=1 RUST_LOG=debug kak-lsp -v -v -v --log /tmp/kak-lsp-%val{session}.log -s %val{session}"
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
        s 'enter-user-mode lsp'        'lsp...'
        , 'lsp-code-actions'        'lsp code actions'
        = 'lsp-format'        'lsp-format'
    }

    try %{
      lsp-enable
    }

    #set buffer idle_timeout 250
}

def lsp-restart -docstring "Restart lsp server" %{
    lsp-stop
    lsp-start
}

filetype-hook (javascript|php|python|java|rust|dart|haskell|ocaml) %{
  lsp-setup
}

filetype-hook make %{
    addhl window/wrap wrap -word -marker ">> "
}


def -hidden -override lsp-show-error -params 1 -docstring "Render error" %{
    echo -debug "kak-lsp:" %arg{1}
    echo -markup " {Error}%arg{1}"
}
