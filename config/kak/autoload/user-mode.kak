# Util functions
def repl-ask %{
  prompt "Run:" 'repl "confirm-exit %val{text}"'
}
  
def filetype-hook -params 2 %{ 
  hook global WinSetOption "filetype=%arg{1}" %arg{2}
}

map global normal -docstring "Comment line" '#' ': comment-line<ret>'
map global normal -docstring "Comment block" '<a-#>' ': comment-block<ret>'

define-command file-delete -docstring "Delete current file" -override %{
   prompt "Delete file [Y/n]? " '%sh{ ([ "$kak_text" = "y" ] || [ "$kak_text" = "Y" ])   && rm $kak_buffile && echo "delete-buffer" }' 
}

def -hidden -override my-fzf-config-popup %{
    popup -title "Config Files" krc-fzf files %val{config} %sh{printf '%s' "$HOME/.config/kak-lsp"} %sh{printf '%s' "$HOME/.config/kak-tree-sitter"}
}

declare-user-mode files
map global user  f ': enter-user-mode files<ret>'                                 -docstring 'Files...'
map global files f ': popup -title "Open file..." krc-fzf files<ret>'             -docstring 'List files'
map global files F ': popup -title "Open file (all)..." krc-fzf files -uuu<ret>'  -docstring 'List files (including hidden)'
map global files r ": popup -title 'Ranger' ranger<ret>"                          -docstring 'Ranger'
map global files w ': write<ret>'                                                 -docstring 'Write file' 
map global files c ": my-fzf-config-popup<ret>"                                   -docstring 'Open config dir'
map global files d ': file-delete<ret>'                                           -docstring 'Delete current file'

declare-user-mode buffers
map global user b    ': enter-user-mode buffers<ret>'                             -docstring 'Buffers...'
map global buffers b ': popup -title "Buffers" krc-fzf buffers<ret>'              -docstring "List Buffers" 
map global buffers n ': buffer-next<ret>'                                         -docstring "Next Buffer" 
map global buffers p ': buffer-previous<ret>'                                     -docstring "Prev buffer" 
map global buffers d ': delete-buffer<ret>'                                       -docstring "Delete buffer"
map global buffers u ': buffer *debug*<ret>'                                      -docstring "Debug buffer"

def tmux-new -params 1.. -docstring '
tmux-new <type> [<commands>]: open a new kakoune client and run kakoune commands
type: vertical,horizontal,panel,popup
' %{
  "tmux-terminal-%arg{1}" kak -c %val{session} -e %exp{
    evaluate-commands -save-regs ^ %%{
      try %%{
        execute-keys -draft -client %val{client} -save-regs '' Z
          execute-keys z
            echo # clear message from z
      }
      %sh{
        shift
        for arg
          do
            printf %s "'$(printf %s "$arg" | sed "s/'/''/g")' "
          done
      }
    }
  }
}

declare-user-mode my-tmux
map global user    w     ': enter-user-mode my-tmux<ret>'        -docstring 'Tmux...'
map global normal  <c-w> ': enter-user-mode my-tmux<ret>'        -docstring 'Tmux...'

map global my-tmux h     ': nop %sh{ tmux select-pane -L }<ret>' -docstring 'Select pane to the left'
map global my-tmux j     ': nop %sh{ tmux select-pane -D }<ret>' -docstring 'Select pane below'
map global my-tmux k     ': nop %sh{ tmux select-pane -U }<ret>' -docstring 'Select pane above'
map global my-tmux l     ': nop %sh{ tmux select-pane -R }<ret>' -docstring 'Select pane to the right'

map global my-tmux <tab> ': nop %sh{ tmux last-pane }<ret>'      -docstring 'Select last pane'
map global my-tmux J     ': nop %sh{ tmux swap-pane -D }<ret>'   -docstring 'Swap pane below'
map global my-tmux K     ': nop %sh{ tmux swap-pane -U }<ret>'   -docstring 'Swap pane above'

map global my-tmux <ret> ': tmux-new autosplit<ret>'             -docstring 'Autosplit'
map global my-tmux s     ': tmux-new vertical<ret>'              -docstring 'Split horizontally'
map global my-tmux v     ': tmux-new horizontal<ret>'            -docstring 'Split vertically'
map global my-tmux p     ': tmux-new popup<ret>'                 -docstring 'Popup client'
map global my-tmux o     ': tmux-new bottom-panel<ret>'          -docstring 'Bottom panel client'

map global my-tmux d     ': quit<ret>'                           -docstring 'Delete pane'

map global my-tmux <c-h>     ': nop %sh{ tmux select-pane -L }<ret>' -docstring 'Select pane to the left'
map global my-tmux <c-j>     ': nop %sh{ tmux select-pane -D }<ret>' -docstring 'Select pane below'
map global my-tmux <c-k>     ': nop %sh{ tmux select-pane -U }<ret>' -docstring 'Select pane above'
map global my-tmux <c-l>     ': nop %sh{ tmux select-pane -R }<ret>' -docstring 'Select pane to the right'

map global my-tmux <c-tab>   ': nop %sh{ tmux last-pane }<ret>'      -docstring 'Select last pane'
map global my-tmux <c-J>     ': nop %sh{ tmux swap-pane -D }<ret>'   -docstring 'Swap pane below'
map global my-tmux <c-K>     ': nop %sh{ tmux swap-pane -U }<ret>'   -docstring 'Swap pane above'

map global my-tmux <c-ret>   ': tmux-new autosplit<ret>'             -docstring 'Autosplit'
map global my-tmux <c-s>     ': tmux-new vertical<ret>'              -docstring 'Split horizontally'
map global my-tmux <c-v>     ': tmux-new horizontal<ret>'            -docstring 'Split vertically'
map global my-tmux <c-p>     ': tmux-new popup<ret>'                 -docstring 'Popup client'
map global my-tmux <c-o>     ': tmux-new bottom-panel<ret>'          -docstring 'Bottom panel client'

map global my-tmux <c-d>     ': quit<ret>'                           -docstring 'Delete pane'

declare-user-mode git
map global user   g ': enter-user-mode git<ret>'   -docstring "Git..."
map global git    g ': connect terminal tig<ret>'  -docstring 'Open tig'
map global git    f ': fzf-git<ret>'               -docstring 'Open files in repo'
map global git    p ':git '                        -docstring 'Open git prompt'
map global git    b ': git-blame<ret>'             -docstring 'Toggle git blame'
map global git    B ': git blame-jump<ret>'        -docstring 'Show blamed commit'
map global git    j ': git next-hunk<ret>'         -docstring 'Next hunk'
map global git    k ': git prev-hunk<ret>'         -docstring 'Prev hunk'
map global git    s ': git status<ret>'            -docstring 'Show status'
map global git    d ': git diff<ret>'              -docstring 'git diff'

declare-user-mode ui
map global user v ': enter-user-mode ui<ret>' -docstring 'View...'
map global ui   n ': toggle-numbers<ret>' -docstring 'Toggle Line numbers'

map global user q ':delete-buffer<ret>' -docstring "Close Buffer"
