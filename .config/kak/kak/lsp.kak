import util

def lsp-setup %{
    map-all lsp -scope buffer %{
        R 'lsp-rename-prompt'                          'Rename at point'
        n 'lsp-find-error -include-warnings'           'Next diagnostic'
        n 'lsp-find-error -include-warnings -previuos' 'Previous diagnostic'
    }

    map-all filetype -scope buffer %{
        s 'enter-user-mode lsp'        'lsp...'
    }

    lsp-start
}

def lsp-restart -docstring "Restart lsp server" %{
    lsp-stop
    lsp-start
}
