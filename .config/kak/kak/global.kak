# Global settings


hook global BufCreate .* %{
  # Show line numbers
  addhl buffer/numbers number-lines -hlcursor -separator ' '
  # highlight matching parens
  addhl buffer/matching show-matching
}

# Disable clippy
set global ui_options ncurses_assistant=none


hook -group tabstop global InsertChar \t %{ exec -draft -itersel h@ }
set global tabstop 2
set global indentwidth 2

hook global InsertKey <backspace> %{ try %{
    exec -draft hGh<a-k>\A\h+\Z<ret>gihyp<lt>
}}

# Tab completion
hook global InsertCompletionShow .* %{
    map window insert <tab> <c-n>
    map window insert <s-tab> <c-p>
}

hook global InsertCompletionHide .* %{
    unmap window insert <tab> <c-n>
    unmap window insert <s-tab> <c-p>
}

# space is my leader
map global normal <space> ':enter-user-mode user<ret>'  -docstring 'leader'
map global normal <backspace> <space> -docstring 'remove all sels except main'
map global normal <a-backspace> <a-space> -docstring 'remove main sel'
unmap global normal ,

map -docstring "Open shell" global user <ret> ':repl<ret>'

# For some reason the first call to this is mixed with the actual user mode
declare-user-mode noThankYou

# Filetype mode

hook global BufSetOption filetype=.* %{
    try %{ declare-user-mode filetype }
}

map global normal , ':enter-user-mode filetype<ret>'
map global normal <C-f> ':enter-user-mode filetype<ret>'
map global insert <C-f> '<a-;>:enter-user-mode filetype<ret>'
