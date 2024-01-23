filetype-hook rust %{
  lsp-setup
  # lsp-enable-semantic-tokens
  lsp-inlay-hints-enable window
  
  set window gdb_program rust-gdb
  # gdbrepeat is defined in c++.kak
  map window filetype  d       ': enter-user-mode -lock gdbrepeat<ret>'  -docstring 'GDB...'
}
