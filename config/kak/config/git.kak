## Blame current line
set-face global GitBlameLineRef red,black
set-face global GitBlameLineSummary green,black
set-face global GitBlameLineAuthor blue,black
set-face global GitBlameLineTime default,black@comment

define-command git-blame-current-line %{
  echo -markup {Information}Press <ret> to jump to blamed commit, b to enable blame view
  on-key %{
    eval %sh{
      [ $kak_key = '<ret>' ] && echo "git blame-jump" && exit
      [ $kak_key = 'b' ] && echo "git blame" && exit
      echo "exec -with-maps -with-hooks $kak_key"
    }
  }

  info -markup -style above -anchor "%val{cursor_line}.%val{cursor_column}" -- %sh{
    git blame -L$kak_cursor_line,$kak_cursor_line $kak_bufname --incremental | awk '\
BEGIN {
  ref = ""
  author = ""
  time = ""
  summary = ""
}

/^[a-f0-9]+ [0-9]+ [0-9]+ [0-9]+$/ {
  ref = substr($1, 0, 8)
}

/summary/ {
  for (i = 2; i < NF; i++) {
    summary = summary $i " "
  }

  summary = summary $NF
}

/author / {
  for (i = 2; i < NF; i++) {
    author = author $i " "
  }

  author = author $NF
}

/author-time/ {
  time = strftime("%a %d %b %Y, %H:%M:%S", $2)
}

END {
  first = sprintf("{GitBlameLineRef}%s {GitBlameLineSummary}%s", ref, summary)
  second = sprintf("{GitBlameLineAuthor}%s {GitBlameLineTime}on %s", author, time)

  max_len = length(first)
  second_len = length(second)
  if (second_len > max_len) {
    max_len = second_len
  }
  fmt_string = sprintf("%%-%ds", max_len)

  printf fmt_string "\n", first
  printf fmt_string, second
}'
  }
}

map global object m %{c^[<lt>=|]{4\,}[^\n]*\n,^[<gt>=|]{4\,}[^\n]*\n<ret>} -docstring 'conflict markers'
map global git    g ':connect terminal tig<ret>'  -docstring 'Open tig'
map global git    j ':git next-hunk<ret>'         -docstring 'Next hunk'
map global git    k ':git prev-hunk<ret>'         -docstring 'Prev hunk'
# map global git    s ':git status<ret>'            -docstring 'Show status'

map global git W %{:w<ret>: git add -f -- "%val{buffile}"<ret>} -docstring "write - Write and stage the current file (force)"
map global git w %{:w<ret>: git add -- "%val{buffile}"<ret>} -docstring "write - Write and stage the current file"
map global git Q %{:git-stack-clear<ret>} -docstring "Remove all *git* buffers"
map global git <ret> %{:git blame-jump<ret>} -docstring "jump"

map global git-blame b %{:git-blame-current-line<ret>} -docstring "blame popup"
map global git-blame <ret> %{:git blame-jump<ret>} -docstring "jump"

