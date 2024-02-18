declare-option str git_branch_name
declare-option str git_work_tree

# # Main hook (git branch update, gutters)
# hook global -group git-main-hook NormalIdle .* %{
#   # Update git diff column signs
#   try %{ git update-diff }

#   # Update branch name
#   set-option global git_branch_name %sh{ git rev-parse --is-inside-work-tree &> /dev/null && echo " $(git rev-parse --abbrev-ref HEAD)"}
# }

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


eval %{

  define-command -override my-git-edit -params 1 %{
    edit -existing -- %arg{@}
  } -menu -shell-script-candidates %{ git ls-files }
  try %{ complete-command -menu my-git-edit shell-script-candidates %{ git ls-files } }
  define-command -override my-git-edit-root -params 1 %{
    edit -existing -- %arg{@}
  }
  try %{ complete-command -menu my-git-edit-root shell-script-candidates %{ git ls-files "$(git rev-parse --show-toplevel)" } }


  declare-option -hidden str my_git_buffer
  declare-option -hidden str-list my_git_stack
  define-command -override git-stack-push -docstring "record *git* buffer" %{
    evaluate-commands %sh{
      eval set -- $kak_quoted_opt_my_git_stack
      if printf '%s\n' "$@" | grep -Fxq -- "$kak_bufname"; then {
        exit
      } fi
      newbuf=$kak_bufname-$#
      echo "try %{ delete-buffer! $newbuf }"
      echo "rename-buffer $newbuf"
      echo "set-option -add global my_git_stack %val{bufname}"
    }
    set-option global my_git_buffer %val{bufname}
  }
  define-command -override git-stack-pop -docstring "restore *git* buffer" %{
    evaluate-commands %sh{
      eval set -- $kak_quoted_opt_my_git_stack
      if [ $# -eq 0 ]; then {
        echo fail "git-stack-pop: no *git* buffer to pop"
        exit
      } fi
      printf 'set-option global my_git_stack'
      top=
      while [ $# -ge 2 ]; do {
        top=$1
        printf ' %s' "$1"
        shift
      } done
      echo
      echo "delete-buffer $1"
      echo "set-option global my_git_buffer '$top'"
    }
    try %{
      evaluate-commands -try-client %opt{jumpclient} %{
        buffer %opt{my_git_buffer}
      }
    }
  }
  define-command -override git-stack-clear -docstring "clear *git* buffers" %{
    evaluate-commands %sh{
      eval set --  $kak_quoted_opt_my_git_stack
      printf 'try %%{ delete-buffer %s }\n' "$@"
    }
    set-option global my_git_stack
  }

  define-command -override my-conflict-1 -docstring "choose the first side of a conflict hunk" %{
    evaluate-commands -draft %{
      execute-keys <a-l>l<a-/>^<lt>{4}<ret>xd
      execute-keys h/^={4}|^\|{4}<ret>
      execute-keys ?^>{4}<ret>xd
    }
  }
  define-command -override my-conflict-2 -docstring "choose the second side of a conflict hunk" %{
    evaluate-commands -draft %{
      execute-keys <a-l>l<a-/>^<lt>{4}<ret>
      execute-keys ?^={4}<ret>xd
      execute-keys />{4}<ret>xd
    }
  }
  define-command -override tig -params .. %{
    connect terminal tig %arg{@}

  }
  define-command -override tig-blame-here -docstring "Run tig blame on the current line" %{
    tig -C %sh{git rev-parse --show-toplevel} blame -C "+%val{cursor_line}" -- %sh{
      dir="$(git rev-parse --show-toplevel)"
      printf %s "${kak_buffile##$dir/}"
    }
  }
  define-command -override tig-blame-selection -docstring "Run tig -L on the selected lines" %{
    evaluate-commands -save-regs d %{
      evaluate-commands -draft %{
        execute-keys <a-:>
        set-register d %sh{git rev-parse --show-toplevel}
      }
      tig -C %reg{d} %sh{
        anchor=${kak_selection_desc%,*}
        anchor_line=${anchor%.*}
        cursor=${kak_selection_desc#*,}
        cursor_line=${cursor%.*}
        d=$kak_reg_d
        printf %s "-L$anchor_line,$cursor_line:${kak_buffile##$d/}"
      }
    }
  }
  define-command -override my-git-enter %{ evaluate-commands -save-regs c %{
    try %{
      evaluate-commands -draft %{
        try %{
          execute-keys s\S{2,}<ret>
          evaluate-commands %sh{
            [ "$(git rev-parse --revs-only "$kak_selection")" ] || echo fail
          }
        } catch %{
          try %{ execute-keys <semicolon><a-i>w }
          evaluate-commands %sh{
            [ "$(git rev-parse --revs-only "$kak_selection")" ] || echo fail
          }
        }
        set-register c %val{selection}
      }
      git show %reg{c} --
    } catch %{
      require-module diff
      diff-jump %opt{git_work_tree}
    }
  }}
  define-command -override my-git-select-commit %{
    try %{
      execute-keys %{<a-/>^commit \S+<ret>}
      execute-keys %{1s^commit (\S+)<ret>}
    } catch %{
      try %{
        execute-keys <a-i>w
        evaluate-commands %sh{
          [ "$(git rev-parse --revs-only "$kak_selection")" ] || echo fail
        }
      } catch %{
        # oneline log
        execute-keys <semicolon>x
        try %{ execute-keys %{s^[0-9a-f]{4,}\b<ret>} }
      }
    }
  }
  define-command -override my-git-yank-reference %{ evaluate-commands -draft %{
    my-git-select-commit
    evaluate-commands %sh{
      x=$(git log -1 "${kak_selection}" --pretty=reference)
      printf %s "set-register dquote '$(printf %s "$x" | sed "s/'/''/g")'"
      printf %s "$x" | clip >/dev/null 2>&1
    }
  }}
  define-command -override my-git-yank-commit %{ evaluate-commands -draft %{
    my-git-select-commit
    exec '<a-|>clip<ret>'
  }}
  define-command -override my-git-yank -params 1 %{ evaluate-commands -draft %{
    my-git-select-commit
    evaluate-commands %sh{
      x=$(git log -1 "${kak_selection}" --format="$1")
      printf %s "set-register dquote '$(printf %s "$x" | sed "s/'/''/g")'"
      printf %s "$x" | clip >/dev/null 2>&1
    }
  }}
  define-command -override my-git-fixup %{ evaluate-commands -draft %{
    my-git-select-commit
    git commit --fixup %val{selection}
  }}

  define-command -override my-git -params 1.. %{ evaluate-commands -draft %{
    nop %sh{
      (
        export KAKOUNE_SESSION=$kak_session KAKOUNE_CLIENT=$kak_client
        response=my-git-log-default
        prepend_git=true
        while true; do {
          if [ "$1" = -no-refresh ]; then {
            response=nop
            shift
          } elif [ "$1" = -no-git ]; then {
            prepend_git=false
            shift
          } else {
            break
          } fi
        } done
        if $prepend_git; then
        set -- git "$@"
        fi
        commit=$kak_selection eval set -- "$@"
        escape2() { printf %s "$*" | sed "s/'/''''/g"; }
        escape3() { printf %s "$*" | sed "s/'/''''''''/g"; }
        if output=$(
          "$@" 2>&1
        ); then {
          response="'
          $response
          echo -debug $ ''$(escape2 "$@") <<<''
          echo -debug ''$(escape2 "$output")>>>''
          '"
        } else {
          response="'
          $response
          echo -debug failed to run ''$(escape2 "$@")''
          echo -debug ''git output: <<<''
          echo -debug ''$(escape2 "$output")>>>''
          hook -once buffer NormalIdle .* ''
          echo -markup ''''{Error}{\\}failed to run $(escape3 "$@"), see *debug* buffer''''
          ''
          '"
        } fi
        echo "evaluate-commands -client ${kak_client} $response" |
        kak -p ${kak_session}
      ) >/dev/null 2>&1 </dev/null &
    }
  }}

  define-command -override my-git-with-commit -params 1.. %{ evaluate-commands -draft %{
    try my-git-select-commit
    my-git %arg{@}
  }}
  define-command -override my-git-autofixup %{
    my-git autofixup %{"$(fork-point.sh)"}
  }
  define-command -override my-git-autofixup-and-apply %{
    evaluate-commands %sh{
      git-autofixup "$(fork-point.sh)" --exit-code >&2
      if [ $? -ge 2 ]; then {
        echo "fail 'error running git-autofixup $(fork-point.sh)'"
      } fi
    }
    my-git -c sequence.editor=true revise -i --autosquash %{"$(fork-point.sh)"}
  }
  define-command -override my-git-revise -params .. %{ my-git-with-commit revise %arg{@} }
  define-command -override my-git-log -params .. %{
    evaluate-commands %{
      try %{
        buffer *git-log*
        set-option global my_git_line %val{cursor_line}
      } catch %{
        set-option global my_git_line 1
      }
    }
    evaluate-commands -draft %{
      try %{
        buffer *git*
        rename-buffer *git*.bak
      }
    }
    try %{ delete-buffer *git-log* }
    git log --oneline %arg{@}
    hook -once buffer NormalIdle .* %{
      execute-keys %opt{my_git_line}g<a-h>
      execute-keys -draft \
      %{gk!} \
      %{git diff --quiet || echo "Unstaged changes";} \
      %{git diff --quiet --cached || echo "Staged changes";} \
      <ret>
    }
    rename-buffer *git-log*
    evaluate-commands -draft %{
      try %{
        buffer *git*.bak
        rename-buffer *git*
      }
    }
  }
  define-command -override my-git-log-default -params .. %{
    # my-git-log %exp{%sh{git-truth}@{1}..} %arg{@}
    my-git-log %exp{%sh{git-truth}..} %arg{@}
  }
  declare-option int my_git_line 1
  define-command -override my-git-diff -params .. %{
    evaluate-commands -draft %{
      try %{
        buffer *git*
        set-option global my_git_line %val{cursor_line}
      } catch %{
        set-option global my_git_line 1
      }
    }
    try %{ delete-buffer *git* }
    nop %sh{ git diff "$@" > "/tmp/fixdiff.$kak_session" }
    edit -scratch *git*
    set-option buffer filetype git-diff
    try %{
      set-option buffer git_work_tree %sh{git rev-parse --show-toplevel}
      map buffer normal <ret> %{:require-module diff; diff-jump %opt{git_work_tree}<ret>}
    }
    execute-keys %{|cat /tmp/fixdiff.$kak_session<ret>}
    execute-keys %opt{my_git_line}g
  }
  define-command -override my-git-show -params .. %{
    nop %sh{
      git show "$@" > "/tmp/fixdiff.$kak_session"
    }
    git show %arg{@}
  }
  define-command -override my-git-range-diff -params .. %{
    try %{ delete-buffer *git-range-diff* }
    edit -scratch *git-range-diff*
    set-option buffer filetype git-range-diff
    execute-keys "|git range-diff --color %arg{@}<ret>"
    ansi-render
  }
  define-command -override my-fixdiff %{
    write -force "/tmp/fixdiff.%val{session}.new"
    nop %sh{
      fixdiff "/tmp/fixdiff.$kak_session" "/tmp/fixdiff.$kak_session.new" &&
      rm "/tmp/fixdiff.$kak_session.new"
    }
  }
  define-command -override my-git-branchstack -params .. %{
    my-git-with-commit \
    -c rerere.autoUpdate=true branchstack -r %{"$(git-truth)"..} \
    %arg{@}
  }
  define-command -override my-git-branchstack-push %{ evaluate-commands -draft %{
    try my-git-select-commit
    evaluate-commands %sh{
      commit=${kak_selection}
      if ! branch=$(git branchstack-branch "$commit"); then {
        echo fail no branch
      } fi
      echo my-git -no-refresh -c rerere.autoUpdate=true branchstack -r '%{"$(git-truth)"..}' "$branch"
      maybe_force=$(test "$branch" != master && printf %s --force)
      push_remote=$(git config branch."$branch".pushRemote \
      || git config remote.pushDefault \
      || echo origin)
      echo my-git -no-refresh push $maybe_force "$push_remote" "$branch"
    }
  }}
  define-command -override my-git-branchstack-yank-branch %{ evaluate-commands -draft %{
    my-git-select-commit
    evaluate-commands %sh{
      x=$(git branchstack-branch "${kak_selection}")
      printf %s "set-register dquote '$(printf %s "$x" | sed "s/'/''/g")'"
      printf %s "$x" | clip >/dev/null 2>&1
    }
  }}

  hook -group my global BufCreate .*/git-revise-todo %{
    set-option buffer filetype git-rebase
  }
  hook -group my global WinSetOption filetype=git-rebase %{
    map window normal <ret> :my-git-enter<ret>
    set-option buffer extra_word_chars '_' '-'
  }
  hook -group my global WinSetOption filetype=(diff|git-diff|git-commit|mail) %{
    set-option buffer autowrap_column 72
  }
  hook -group my global WinSetOption filetype=git-log %{
    map buffer normal <ret> :my-git-enter<ret>
    hook -once -always window WinSetOption filetype=.* %{
      unmap buffer normal <ret> :my-git-enter<ret>
    }
  }
  hook -group my global BufCreate \*git\* %{
    alias buffer w my-fixdiff
    alias buffer buffers-pop git-stack-pop
    alias buffer buffers-clear git-stack-clear
  }
  hook -group my global WinDisplay \*git\* %{
    git-stack-push
  }
  hook -group my global BufClose \*git(-diff|-show)?\* %{
    nop %sh{
      rm -f "/tmp/fixdiff.$kak_session"
    }
  }

  hook -group my global BufCreate .*[.]gl|\*gl-issue\* %{
    set-option buffer filetype grep
    set-option buffer extra_word_chars '_' '-'
    set-option buffer comment_line >
    set-option buffer disabled_hooks "%opt{disabled_hooks}|my-editorconfig"
    declare-option str-list my_gl_static_words
    set-option buffer static_words %opt{my_gl_static_words}
    require-module diff
    add-highlighter -override buffer/my-gl-diff ref diff
    add-highlighter -override buffer/my-wrap wrap -word -indent -marker <
  }
}

try %{ declare-user-mode git }
try %{ declare-user-mode git-am }
try %{ declare-user-mode git-apply }
try %{ declare-user-mode git-bisect }
try %{ declare-user-mode git-blame }
try %{ declare-user-mode git-branchstack }
try %{ declare-user-mode git-cherry-pick }
try %{ declare-user-mode git-commit }
try %{ declare-user-mode git-diff }
try %{ declare-user-mode git-fetch }
try %{ declare-user-mode git-merge }
try %{ declare-user-mode git-push }
try %{ declare-user-mode git-rebase }
try %{ declare-user-mode git-reset }
try %{ declare-user-mode git-revert }
try %{ declare-user-mode git-revise }
try %{ declare-user-mode git-yank }
try %{ declare-user-mode git-stash }
try %{ declare-user-mode git-gl }

map global object m %{c^[<lt>=|]{4\,}[^\n]*\n,^[<gt>=|]{4\,}[^\n]*\n<ret>} -docstring 'conflict markers'

# map global normal <c-h> %{:my-git-enter<ret>}

map global git    g ':connect terminal tig<ret>'  -docstring 'Open tig'
map global git    j ':git next-hunk<ret>'         -docstring 'Next hunk'
map global git    k ':git prev-hunk<ret>'         -docstring 'Prev hunk'
map global git    s ':git status<ret>'            -docstring 'Show status'

map global git 1 %{:my-conflict-1<ret>} -docstring "conflict: use ours"
map global git 2 %{:my-conflict-2<ret>} -docstring "conflict: use theirs"

map global git a %{:enter-user-mode git-apply<ret>} -docstring "apply selection..."
map global git b %{:git-blame-current-line<ret>} -docstring "blame..."
map global git B %{:enter-user-mode git-bisect<ret>} -docstring 'bisect...'
map global git A %{:enter-user-mode git-cherry-pick<ret>} -docstring 'cherry-pick...'
map global git c %{:enter-user-mode git-commit<ret>} -docstring "commit..."
map global git d %{:enter-user-mode git-diff<ret>} -docstring "diff..."
map global git e %{:my-git-edit } -docstring "edit..."
map global git E %{:my-git-edit-root } -docstring "edit (repo root)..."
map global git f %{:enter-user-mode git-fetch<ret>} -docstring 'fetch...'
map global git F %{:gl-fetch<ret>} -docstring 'gl fetch'
map global git h %{:enter-user-mode git-branchstack<ret>} -docstring 'branchstack...'
map global git L %{:my-git-log-default<ret>} -docstring 'log'
map global git l %{:my-git-log } -docstring 'log'
map global git m %{:enter-user-mode git-am<ret>} -docstring 'am...'
map global git M %{:enter-user-mode git-merge<ret>} -docstring 'merge...'
map global git o %{:enter-user-mode git-reset<ret>} -docstring "reset..."
map global git p %{:enter-user-mode git-push<ret>} -docstring 'push...'
map global git r %{:enter-user-mode git-rebase<ret>} -docstring "rebase..."
# map global git s %{:my-git-show<ret>} -docstring 'git show'
map global git t %{:enter-user-mode git-revert<ret>} -docstring "revert..."
map global git u %{:enter-user-mode git-gl<ret>} -docstring 'gl...'
map global git v %{:enter-user-mode git-revise<ret>} -docstring "revise..."
map global git W %{:w<ret>: git add -f -- "%val{buffile}"<ret>} -docstring "write - Write and stage the current file (force)"
map global git w %{:w<ret>: git add -- "%val{buffile}"<ret>} -docstring "write - Write and stage the current file"
map global git y %{:enter-user-mode git-yank<ret>} -docstring "yank..."
map global git z %{:enter-user-mode git-stash<ret>} -docstring "stash..."

map global git-am a %{:my-git am --abort<ret>} -docstring 'abort'
map global git-am r %{:my-git am --continue<ret>} -docstring 'continue'
map global git-am s %{:my-git am --skip<ret>} -docstring 'skip'

map global git-apply a %{:git apply<ret>} -docstring 'apply'
map global git-apply 3 %{:git apply --3way<ret>} -docstring 'apply using 3way merge'
map global git-apply r %{:git apply --reverse<ret>} -docstring 'reverse'
map global git-apply s %{:git apply --cached<ret>} -docstring 'stage'
map global git-apply u %{:git apply --reverse --cached<ret>} -docstring 'unstage'
map global git-apply i %{:git apply --index<ret>} -docstring 'apply to worktree and index'

map global git-bisect B %{:my-git-with-commit bisect bad %{"$commit"}<ret>}
map global git-bisect G %{:my-git-with-commit bisect good %{"$commit"}<ret>}

# map global git-blame b %{:git-blame-current-line<ret>} -docstring 'blame current line'
# map global git-blame t %{:tig-blame-here<ret>} -docstring "tig blame"
# map global git-blame s %{:tig-blame-selection<ret>} -docstring "tig blame selection"
# map global git-blame a %{:git blame<ret>} -docstring "git blame"

map global git-branchstack s %{:my-git-branchstack %{"$(git branchstack-branch "$commit")"}<ret>} -docstring "export as branch"
map global git-branchstack f %{:my-git-branchstack %{"$(git branchstack-branch "$commit")"} --force<ret>} -docstring "export as branch (force)"
map global git-branchstack b %{:my-git-branchstack-yank-branch<ret>} -docstring "yank branch name"
map global git-branchstack p %{:my-git-branchstack-push<ret>} -docstring "push branch"

map global git-cherry-pick a %{:my-git cherry-pick --abort<ret>} -docstring 'abort'
map global git-cherry-pick p %{:my-git-with-commit cherry-pick %{"$commit"}<ret>} -docstring 'cherry-pick commit'
map global git-cherry-pick r %{:my-git cherry-pick --continue<ret>} -docstring 'continue'
map global git-cherry-pick s %{:my-git cherry-pick --skip<ret>} -docstring 'skip'

map global git-commit a %{:my-git commit --amend<ret>} -docstring 'amend'
map global git-commit A %{:my-git commit --amend --all<ret>} -docstring 'amend all'
map global git-commit r %{:my-git commit --amend --reset-author<ret>} -docstring 'amend resetting author'
map global git-commit c %{:my-git commit<ret>} -docstring 'commit'
map global git-commit C %{:my-git commit --all<ret>} -docstring 'commit all'
map global git-commit F %{:my-git commit --fixup=} -docstring 'fixup...'
map global git-commit f %{:my-git-fixup<ret>} -docstring 'fixup commit at cursor'
map global git-commit u %{:my-git-autofixup<ret>} -docstring 'autofixup'
map global git-commit o %{:my-git-autofixup-and-apply<ret>} -docstring 'autofixup and apply'

map global git-diff d %{:my-git-diff<ret>} -docstring "Show unstaged changes"
map global git-diff s %{:my-git-diff --staged<ret>} -docstring "Show staged changes"
map global git-diff h %{:my-git-diff HEAD<ret>} -docstring "Show changes between HEAD and working tree"
map global git-diff S %{:git status<ret>} -docstring "Show status"

map global git-fetch f %{:my-git pull --rebase<ret>} -docstring 'pull'
map global git-fetch a %{:my-git fetch --all<ret>} -docstring 'fetch all'
map global git-fetch o %{:my-git fetch origin<ret>} -docstring 'fetch origin'

map global git-merge a %{:my-git merge --abort<ret>} -docstring 'abort'
map global git-merge m %{:my-git-with-commit merge %{"$commit"}<ret>} -docstring 'merge'
map global git-merge r %{:my-git merge --continue<ret>} -docstring 'continue'
map global git-merge s %{:my-git merge --skip<ret>} -docstring 'skip'

map global git-push p %{:my-git push<ret>} -docstring 'push'
map global git-push f %{:my-git push --force<ret>} -docstring 'push --force'
map global git-push m %{:my-git-with-commit push %{"$(git config branch.master.pushRemote || git config remote.pushDefault || echo origin)"} %{"${commit}":master}<ret>} -docstring 'push commit to master'

map global git-rebase a %{:my-git rebase --abort<ret>} -docstring 'abort'
map global git-rebase b %{:my-git-with-commit rerebase %{"$commit"^}<ret>} -docstring 'rerebase'
map global git-rebase e %{:my-git rebase --edit-todo<ret>} -docstring 'edit todo'
map global git-rebase i %{:my-git-with-commit rebase --interactive %{"${kak_selection}"^}<ret>} -docstring 'interactive rebase commit'
map global git-rebase r %{:my-git rebase --continue<ret>} -docstring 'continue'
map global git-rebase s %{:my-git rebase --skip<ret>} -docstring 'skip'
map global git-rebase u %{:my-git rebase --interactive<ret>} -docstring 'interactive rebase'

map global git-reset o %{:my-git-with-commit reset %{"$commit"}<ret>} -docstring 'mixed reset'
map global git-reset s %{:my-git-with-commit reset --soft %{"$commit"}<ret>} -docstring 'soft reset'
map global git-reset O %{:my-git-with-commit reset --hard %{"$commit"}<ret>} -docstring 'hard reset'

map global git-revert a %{:my-git revert --abort<ret>} -docstring 'abort'
map global git-revert t %{:my-git-with-commit revert %{"$commit"}<ret>} -docstring 'revert'
map global git-revert r %{:my-git revert --continue<ret>} -docstring 'continue'
map global git-revert s %{:my-git revert --skip<ret>} -docstring 'skip'

map global git-revise a %{:my-git-revise --reauthor %{"$commit"}<ret>} -docstring 'reauthor'
map global git-revise e %{:my-git-revise --interactive --edit %{"$(fork-point.sh)"}<ret>} -docstring 'edit all since fork-point'
map global git-revise E %{:my-git-revise --interactive --edit %{"$commit"^}<ret>} -docstring 'edit all since commit'
map global git-revise f %{:my-git-revise %{"$commit"}<ret>} -docstring 'fixup selected commit'
map global git-revise i %{:my-git-revise --interactive %{"${kak_selection}^"}<ret>} -docstring 'interactive %(commit)'
map global git-revise u %{:my-git-revise --interactive %{"$(fork-point.sh)"}<ret>} -docstring 'interactive %{upstream}'
map global git-revise w %{:my-git-revise --edit %{"$commit"}<ret>} -docstring 'edit'

map global git-yank a %{:my-git-yank '%aN <lt>%aE>'<ret>} -docstring 'copy author'
map global git-yank m %{:my-git-yank '%s%n%n%b'<ret>} -docstring 'copy message'
map global git-yank c %{:my-git-yank-commit<ret>} -docstring 'copy commit'
map global git-yank r %{:my-git-yank-reference<ret>} -docstring 'copy pretty commit reference'

map global git-stash z %{:my-git stash push<ret>} -docstring 'push'
map global git-stash p %{:my-git stash pop<ret>} -docstring 'pop'

map global git-gl a %{Z<a-/>^(?:> )?\<plus><ret>x1s^(?:> )?\<plus>([^\n]*)<ret>yzpi```suggestion<ret><esc><semicolon>o```<esc>kx} -docstring "gl suggestion"
map global git-gl d %{:gl-discuss<ret>} -docstring 'gl discuss'
map global git-gl f %{:gl-fetch<ret>} -docstring 'gl fetch'
map global git-gl s %{:gl-submit<ret>} -docstring 'gl submit'
map global git-gl u %{:gl-url<ret>} -docstring 'gl url'
map global git-gl v %{:gl-visit } -docstring "gl visit"

