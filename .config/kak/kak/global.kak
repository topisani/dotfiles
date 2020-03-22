# Global settings

hook global WinCreate .* %{
  # Show line numbers
  addhl window/numbers number-lines -hlcursor -separator ' '
  # highlight matching parens
  addhl window/matching show-matching

  set window space_indent true
}

# Disable clippy
set global ui_options ncurses_assistant=none

set global tabstop 2
set global indentwidth 2
decl -docstring "Whether to indent with spaces instead of tabs. Must be set in window scope" \
bool space_indent true

# Deindent on backspace
hook global WinSetOption 'space_indent=true' %{
  hook -group space-indent window InsertDelete ' ' %{ try %{
    exec -draft "hGh<a-k>\A([<space>]{%opt[indentwidth]})*<space>\z<ret>i<space><esc><lt>"
  }}
  hook -group space-indent window InsertChar \t %{ try %{ 
    #exec -draft 'h<a-h><a-k>\A\h+\z<ret><a-;>;@'
    exec -draft 'h<a-;>;@'
  }}
}

hook global WinSetOption 'space_indent=false' %{
	rmhooks window space-indent
}

# Tab completion
hook global InsertCompletionShow .* %{ try %{
  execute-keys -draft 'h<a-K>\h<ret>'
  map window insert <tab> <c-n>
  map window insert <s-tab> <c-p>
}}
hook global InsertCompletionHide .* %{
  unmap window insert <tab> <c-n>
  unmap window insert <s-tab> <c-p>
}

def -hidden universal-snippets-next-placeholders %{
  try %{
    lsp-snippets-select-next-placeholders
  } catch %{
    snippets-select-next-placeholders
  } catch %{
    exec -with-maps -with-hooks '<c-n>'
  }
}
def -hidden insert-mode-tab %{
  try %{
    try %{
      lsp-snippets-select-next-placeholders
    } catch %{
      snippets-select-next-placeholders
    }
    # On the next key, start replacing the placeholder contents
    on-key %{ exec "<esc>c%val{key}"  }
  } catch %{
    exec -with-hooks '<c-n>'
  }
}
map global insert <c-n> "<a-;>: insert-mode-tab<ret>"
map global normal <c-n> ": universal-snippets-next-placeholders<ret>"

# <c-i> is the same as <tab>, so move <c-i>/<c-o> to <c-o>/<c-p>
# map global normal <c-o> <c-i>
# map global normal <c-p> <c-o>

# space is my leader
map global normal <space> ': enter-user-mode user<ret>'  -docstring 'leader'
map global normal <backspace> <space> -docstring 'remove all sels except main'
map global normal <a-backspace> <a-space> -docstring 'remove main sel'
unmap global normal ,

map -docstring "Open shell" global user <ret> ': connect<ret>'

# Filetype mode

hook global BufSetOption filetype=.* %{
    try %{ declare-user-mode filetype }
}

map global normal , ': enter-user-mode filetype<ret>'
map global normal <C-f> ': enter-user-mode filetype<ret>'
map global insert <C-f> '<a-;>: enter-user-mode filetype<ret>'
