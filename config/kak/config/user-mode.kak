# Util functions

define-command my-file-delete -docstring "Delete current file" -override %{
   prompt "Delete file [Y/n]? " '%sh{ ([ "$kak_text" = "y" ] || [ "$kak_text" = "Y" ])   && rm $kak_buffile && echo "delete-buffer" }' 
}

define-command -override my-file-rename %{
  prompt -init %val{buffile} 'rename to: ' '
  evaluate-commands %sh{
    line="$kak_cursor_line"
    column="$kak_cursor_column"
    mkdir -p "$(dirname "$kak_text")"
    mv "$kak_buffile" "$kak_text"
    echo delete-buffer
    echo edit -existing -- %val{text} $line $column
  }' -file-completion
}

define-command winplace -params 2.. %{
   with-option windowing_placement %arg{@} 
}

def -hidden -override my-fzf-config-popup %{
    winplace popup terminal -title "Config Files" krc-fzf files %val{config} %sh{printf '%s' "$HOME/.config/kak-lsp"} %sh{printf '%s' "$HOME/.config/kak-tree-sitter"}
}

def -hidden -override my-fzf-cork-popup %{
    winplace popup terminal -title "Plugin Files" krc-fzf files %val{config} %sh{printf '%s' "$HOME/.local/share/kak/cork/plugins"}
}

def my-sidetree -override %{ winplace panel connect terminal sidetree --select %val{buffile} }

declare-user-mode my-tmux
declare-user-mode files
declare-user-mode buffers
declare-user-mode undo

map global undo u 'u' -docstring "undo last change"
map global undo U 'U' -docstring "redo last change"
map global undo j '<c-j>' -docstring "move forward in changes history"
map global undo k '<c-k>' -docstring "move backward in changes history"

map global files f ':winplace popup terminal -title "Open file..." krc-fzf files<ret>'             -docstring 'List files'
map global files F ':winplace popup terminal -title "Open file (all)..." krc-fzf files -uuu<ret>'  -docstring 'List files (including hidden)'
map global files r ":winplace popup terminal -title 'Ranger' ranger<ret>"                          -docstring 'Ranger'
map global files w ':w<ret>'                                                     -docstring 'Write file' 
map global files c ":my-fzf-config-popup<ret>"                                   -docstring 'Open config dir'
map global files C ":my-fzf-cork-popup<ret>"                                   -docstring 'Open config dir'
map global files d ':my-file-delete<ret>'                                        -docstring 'Delete current file'
map global files r ':my-file-rename<ret>'                                        -docstring 'Rename current file'

map global buffers b ':winplace popup terminal -title "Buffers" krc-fzf buffers<ret>'              -docstring "List Buffers" 
map global buffers n ':buffer-next<ret>'                                         -docstring "Next Buffer" 
map global buffers p ':buffer-previous<ret>'                                     -docstring "Prev buffer" 
map global buffers d ':delete-buffer<ret>'                                       -docstring "Delete buffer"
map global buffers D ':delete-buffer!<ret>'                                       -docstring "Delete buffer (force)"
map global buffers u ':buffer *debug*<ret>'                                      -docstring "Debug buffer"
map global buffers m ':buffer *make*<ret>'                                       -docstring "*make*"
map global buffers M ':buffer make<ret>'                                         -docstring "make"
map global buffers g ':buffer %opt{my_grep_buffer}<ret>'                         -docstring "*grep* or equivalent"
map global buffers v ':buffer %opt{my_git_buffer}<ret>'                          -docstring "*git*"


map global my-tmux h     ':nop %sh{ tmux select-pane -L }<ret>' -docstring 'Select pane to the left'
map global my-tmux j     ':nop %sh{ tmux select-pane -D }<ret>' -docstring 'Select pane below'
map global my-tmux k     ':nop %sh{ tmux select-pane -U }<ret>' -docstring 'Select pane above'
map global my-tmux l     ':nop %sh{ tmux select-pane -R }<ret>' -docstring 'Select pane to the right'

map global my-tmux <tab> ':nop %sh{ tmux last-pane }<ret>'      -docstring 'Select last pane'
map global my-tmux J     ':nop %sh{ tmux swap-pane -D }<ret>'   -docstring 'Swap pane below'
map global my-tmux K     ':nop %sh{ tmux swap-pane -U }<ret>'   -docstring 'Swap pane above'

map global my-tmux <ret> ':winplace autosplit new<ret>'             -docstring 'Autosplit'
map global my-tmux s     ':winplace vertical new<ret>'              -docstring 'Split horizontally'
map global my-tmux v     ':winplace horizontal new<ret>'            -docstring 'Split vertically'
map global my-tmux p     ':winplace popup new<ret>'                 -docstring 'Popup client'
map global my-tmux o     ':winplace bottom-panel new<ret>'          -docstring 'Bottom panel client'
map global my-tmux d     ':q<ret>'                                  -docstring 'Delete pane'
map global my-tmux t     ':ide-tools<ret>'                          -docstring 'Toggle the tools client'
map global my-tmux T     ':ide-hide-tools<ret>'                     -docstring 'Hide the tools client'

map global my-tmux <c-h>     ':nop %sh{ tmux select-pane -L }<ret>' -docstring 'Select pane to the left'
map global my-tmux <c-j>     ':nop %sh{ tmux select-pane -D }<ret>' -docstring 'Select pane below'
map global my-tmux <c-k>     ':nop %sh{ tmux select-pane -U }<ret>' -docstring 'Select pane above'
map global my-tmux <c-l>     ':nop %sh{ tmux select-pane -R }<ret>' -docstring 'Select pane to the right'

map global my-tmux <c-tab>   ':nop %sh{ tmux last-pane }<ret>'      -docstring 'Select last pane'
map global my-tmux <c-J>     ':nop %sh{ tmux swap-pane -D }<ret>'   -docstring 'Swap pane below'
map global my-tmux <c-K>     ':nop %sh{ tmux swap-pane -U }<ret>'   -docstring 'Swap pane above'

map global my-tmux <c-ret>   ':winplace autosplit new<ret>'             -docstring 'Autosplit'
map global my-tmux <c-s>     ':winplace vertical new<ret>'              -docstring 'Split horizontally'
map global my-tmux <c-v>     ':winplace horizontal new<ret>'            -docstring 'Split vertically'
map global my-tmux <c-p>     ':winplace popup new<ret>'                 -docstring 'Popup client'
map global my-tmux <c-o>     ':winplace bottom-panel new<ret>'          -docstring 'Bottom panel client'

map global my-tmux <c-d>     ':q<ret>'                           -docstring 'Delete pane'
map global my-tmux <c-t>     ':ide-tools<ret>'                   -docstring 'Toggle the tools client'
map global my-tmux <c-T>     ':ide-hide-tools<ret>'              -docstring 'Hide the tools client'

try %{ set-option global autocomplete insert|prompt|no-regex-prompt }
# alias global m my-make
# alias global f my-find
alias global g boost-grep
map global normal <c-n> %{:locations-next<ret>} -docstring 'next Location'
map global normal <c-p> %{:locations-previous<ret>} -docstring 'previous Location'
map global normal <c-r> %{:buffers-pop<ret>} -docstring 'pop grep/git buffer'


declare-user-mode ui
map global ui   n ':toggle-numbers<ret>' -docstring 'Toggle Line numbers'

# user mode
map global normal  <c-w> ':enter-user-mode my-tmux<ret>'        -docstring 'Tmux...'

map global user s ':surround-mode<ret>' -docstring 'Surround mode'
map global user r ':enter-replace-mode<ret>' -docstring 'Replace'

map global user u ':enter-user-mode undo<ret>' -docstring 'undo...'
map global user w ':enter-user-mode my-tmux<ret>' -docstring 'Tmux...'
map global user g ':enter-user-mode git<ret>'     -docstring "Git..."
map global user v ':enter-user-mode ui<ret>'      -docstring 'View...'
map global user f ':enter-user-mode files<ret>'   -docstring 'Files...'
map global user b ':enter-user-mode buffers<ret>' -docstring 'Buffers...'

map global user q ':ide-quit-notlast<ret>'        -docstring "Close the client, unless it is the last one"

map global user <ret> ':winplace autosplit connect terminal<ret>' -docstring 'Open terminal'
map global user <c-p> ':winplace popup connect<ret>' -docstring 'Popup Terminal'
map global user <tab> ':my-sidetree<ret>' -docstring 'sidetree'
