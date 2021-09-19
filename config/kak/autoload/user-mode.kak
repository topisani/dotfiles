# Util functions
def repl-ask %{
  prompt "Run:" 'repl "confirm-exit %val{text}"'
}
  
def filetype-hook -params 2 %{ 
  hook global WinSetOption "filetype=%arg{1}" %arg{2}
}

map global normal -docstring "Comment line" '#' ': comment-line<ret>'
map global normal -docstring "Comment block" '<a-#>' ': comment-block<ret>'

define-command file-delete -docstring "Delete current file" %{
   prompt "Delete file [Y/n]? " '%sh{ [[ "$kak_text" =~ [yY] ]] && rm $kak_buffile && echo "delete-buffer" }' 
}

declare-user-mode files
map global user  f ': enter-user-mode files<ret>'                 -docstring 'Files...'
map global files f ': connect bottom-panel kcr fzf files<ret>'    -docstring 'List files'
map global files t ': lf %reg[percent]<ret>'                      -docstring 'File tree (current file)'
map global files T ': lf .<ret>'                                  -docstring 'File tree (current dir)'
map global files w ': write<ret>'                                 -docstring 'Write file' 
map global files c ": connect bottom-panel kcr fzf files %val{config}<ret>"               -docstring 'Open config dir'
map global files d ': file-delete<ret>'                           -docstring 'Delete current file'

declare-user-mode buffers
map global user b    ': enter-user-mode buffers<ret>'  -docstring 'Buffers...'
map global buffers b ': connect bottom-panel kcr fzf buffers<ret>'               -docstring "List Buffers" 
map global buffers n ': buffer-next<ret>'              -docstring "Next Buffer" 
map global buffers p ': buffer-previous<ret>'          -docstring "Prev buffer" 
map global buffers d ': delete-buffer<ret>'            -docstring "Delete buffer"
map global buffers u ': buffer *debug*<ret>'           -docstring "Debug buffer"

def tmux-new-vertical -params .. -command-completion %{
  tmux-terminal-vertical kak -c %val{session} -e "%arg{@}"
}

def tmux-new-horizontal -params .. -command-completion %{
  tmux-terminal-horizontal kak -c %val{session} -e "%arg{@}"
}

declare-user-mode my-tmux
map global user    w     ': enter-user-mode my-tmux<ret>'        -docstring 'Tmux...'
map global my-tmux h     ': nop %sh{ tmux select-pane -L }<ret>' -docstring 'Select pane to the left'
map global my-tmux j     ': nop %sh{ tmux select-pane -D }<ret>' -docstring 'Select pane below'
map global my-tmux k     ': nop %sh{ tmux select-pane -U }<ret>' -docstring 'Select pane above'
map global my-tmux l     ': nop %sh{ tmux select-pane -R }<ret>' -docstring 'Select pane to the right'

map global my-tmux <tab> ': nop %sh{ tmux last-pane }<ret>'      -docstring 'Select last pane'
map global my-tmux J     ': nop %sh{ tmux swap-pane -D }<ret>'   -docstring 'Swap pane below'
map global my-tmux K     ': nop %sh{ tmux swap-pane -U }<ret>'   -docstring 'Swap pane above'

map global my-tmux s     ': tmux-new-vertical<ret>'              -docstring 'Split horizontally'
map global my-tmux v     ': tmux-new-horizontal<ret>'            -docstring 'Split vertically'
map global my-tmux d     ': quit<ret>'                           -docstring 'Delete pane'

def git-blame-toggle %{
  try %[
    addhl window/git-blame flag_lines Info git_blame_flags
    rmhl window/git-blame
    git blame
  ] catch %[
    git hide-blame
  ]
}

declare-user-mode git
map global user   g ': enter-user-mode git<ret>'   -docstring "Git..."
map global git    g ': connect terminal tig<ret>'  -docstring 'Open tig'
map global git    f ': fzf-git<ret>'               -docstring 'Open files in repo'
map global git    p ':git '                        -docstring 'Open git prompt'
map global git    b ': git-blame-toggle<ret>'      -docstring 'Toggle git blame'
