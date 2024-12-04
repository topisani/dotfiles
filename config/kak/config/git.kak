## blame current line
set-face global gitblamelineref red,black
set-face global gitblamelinesummary green,black
set-face global gitblamelineauthor blue,black
set-face global gitblamelinetime default,black@comment

define-command git-blame-current-line %{
  echo -markup {information}press <ret> to jump to blamed commit, b to enable blame view
  on-key %{
    eval %sh{
      [ $kak_key = '<ret>' ] && echo "git blame-jump" && exit
      [ $kak_key = 'b' ] && echo "git blame" && exit
      echo "exec -with-maps -with-hooks $kak_key"
    }
  }

  info -markup -style above -anchor "%val{cursor_line}.%val{cursor_column}" -- %sh{
    git blame -l$kak_cursor_line,$kak_cursor_line $kak_bufname --incremental | awk '\
begin {
  ref = ""
  author = ""
  time = ""
  summary = ""
}

/^[a-f0-9]+ [0-9]+ [0-9]+ [0-9]+$/ {
  ref = substr($1, 0, 8)
}

/summary/ {
  for (i = 2; i < nf; i++) {
    summary = summary $i " "
  }

  summary = summary $nf
}

/author / {
  for (i = 2; i < nf; i++) {
    author = author $i " "
  }

  author = author $nf
}

/author-time/ {
  time = strftime("%a %d %b %y, %h:%m:%s", $2)
}

end {
  first = sprintf("{gitblamelineref}%s {gitblamelinesummary}%s", ref, summary)
  second = sprintf("{gitblamelineauthor}%s {gitblamelinetime}on %s", author, time)

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
map global git    g ':connect terminal tig<ret>'  -docstring 'open tig'
map global git    j ':git next-hunk<ret>'         -docstring 'next hunk'
map global git    k ':git prev-hunk<ret>'         -docstring 'prev hunk'
# map global git    s ':git status<ret>'            -docstring 'show status'

map global git w %{:w<ret>: git add -f -- "%val{buffile}"<ret>} -docstring "write - write and stage the current file (force)"
map global git w %{:w<ret>: git add -- "%val{buffile}"<ret>} -docstring "write - write and stage the current file"
map global git q %{:git-stack-clear<ret>} -docstring "remove all *git* buffers"
map global git <ret> %{:git blame-jump<ret>} -docstring "jump"

map global git-blame b %{:git-blame-current-line<ret>} -docstring "blame popup"
map global git-blame <ret> %{:git blame-jump<ret>} -docstring "jump"

filetype-hook jj-describe %{
  add-highlighter window/jj-describe regions
  add-highlighter window/jj-describe/diff region "^JJ: diff --git [^\n]*"  "^\n" group
  add-highlighter window/jj-describe/diff/ regex "^JJ: " 0:comment
  add-highlighter window/jj-describe/diff/ regex "^JJ: ( [^\n]*\n)" 1:default
  add-highlighter window/jj-describe/diff/ regex "^JJ: (\+[^\n]*\n)" 1:green,default
  add-highlighter window/jj-describe/diff/ regex "^JJ: (-[^\n]*\n)" 1:red,default
  add-highlighter window/jj-describe/diff/ regex "^JJ: (@@[^\n]*@@)" 1:cyan,default
# If any trailing whitespace was introduced in diff, show it with red background
  add-highlighter window/jj-describe/diff/ regex "^JJ: \+[^\n]*?(\h+)\n" 1:default,red

  add-highlighter window/jj-describe/comment region "^JJ: " "$" fill comment
}

declare-user-mode jj

map global jj j %{:jj } -docstring 'jj...'
map global jj a %{:jj abandon<ret>} -docstring 'jj abandon'
map global jj l %{:jj log<ret>} -docstring 'jj log'
map global jj s %{:jj show --git<ret>} -docstring 'jj show'
map global jj e %{:jj edit<ret>} -docstring 'jj edit'
map global jj m %{:jj describe<ret>} -docstring 'jj describe'

complete-command jj shell-script-candidates -menu %{
    printf %s\\n \
        abandon \
        backout \
        describe \
        diff \
        edit \
        log \
        new \
        parallelize \
        rebase \
        show \
        squash \
        split \
        status \
        undo \
}
