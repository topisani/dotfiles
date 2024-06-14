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

define-command -override winplace -params 2.. %{
   eval %{
      set local windowing_placement %arg{1}
      eval %sh{
         shift
         printf '%s ' "$@"
      }
   }
}

def -hidden -override my-fzf-config-popup %{
    winplace popup connect terminal krc-fzf files %val{config} %sh{printf '%s' "$HOME/.config/kak-lsp"} %sh{printf '%s' "$HOME/.config/kak-tree-sitter"}
}

def -hidden -override my-fzf-bundle-popup %{
    winplace popup connect terminal krc-fzf files %sh{printf '%s' "$HOME/.config/kak/bundle"}
}

def sidetree -override %{ winplace panel connect terminal sidetree --select %val{buffile} }

def broot -override -params .. %{
  connect terminal sh -c %{
    cfgfile="$(mktemp -t kak-broot-XXXXXX.toml)"
    trap 'rm -rf -- "$cfgfile"' EXIT
    file=$1; shift
    (echo '
    [[verbs]]
    key = "enter"
    external = "krc open {file} {line}"
    apply_to = "text_file"
    [[verbs]]
    invocation = "kcd"
    key = "c-e"
    external = "krc send cd {directory}"
    apply_to = "directory"
    [[verbs]]
    invocation = "ksel"
    key = "c-r"'
    echo "execution = \":select $file\""
    echo '
    apply_to = "directory"
    ') > "$cfgfile"
    broot --conf "$cfgfile;$HOME/.config/broot/conf.hjson" "$@"
  } broot %val{buffile} %arg{@}
}

try %{ declare-user-mode my-tmux }
try %{ declare-user-mode files }
try %{ declare-user-mode buffers }
try %{ declare-user-mode undo }
try %{ declare-user-mode edit }

def -override trailing-whitespace-remove %{
  exec -draft '%s\h+$<ret>d'
}
map global edit w ':trailing-whitespace-remove<ret>' -docstring "Clear trailing whitespace"

map global undo u 'u' -docstring "undo last change"
map global undo U 'U' -docstring "redo last change"
map global undo j '<c-j>' -docstring "move forward in changes history"
map global undo k '<c-k>' -docstring "move backward in changes history"

# map global files f ':winplace popup terminal -title "Open file..." krc-fzf files<ret>'             -docstring 'List files'
# map global files F ':winplace popup terminal -title "Open file (all)..." krc-fzf files -uuu<ret>'  -docstring 'List files (including hidden)'
map global files f ':winplace popup terminal krc-fzf files<ret>'             -docstring 'List files'
map global files F ':winplace popup terminal krc-fzf files -uuu<ret>'        -docstring 'List files (including hidden)'
map global files b ':winplace popup broot<ret>'                                        -docstring 'broot popup'
map global files B ':winplace window broot<ret>'                                       -docstring 'broot window'
map global files e ':winplace panel broot<ret>'                                        -docstring 'broot panel'
map global files w ':w<ret>'                                                           -docstring 'Write file'
map global files c ":my-fzf-config-popup<ret>"                                         -docstring 'Open config dir'
map global files C ":my-fzf-bundle-popup<ret>"                                         -docstring 'Open plugin dir'
map global files d ':my-file-delete<ret>'                                              -docstring 'Delete current file'
map global files r ':my-file-rename<ret>'                                              -docstring 'Rename current file'
map global files R ':winplace window terminal ranger<ret>'                             -docstring 'Ranger'

map global buffers b ':winplace popup terminal krc-fzf buffers<ret>'                   -docstring "List Buffers"
map global buffers n ':buffer-next<ret>'                                               -docstring "Next Buffer"
map global buffers p ':buffer-previous<ret>'                                           -docstring "Prev buffer"
map global buffers d ':delete-buffer<ret>'                                             -docstring "Delete buffer"
map global buffers q ':delete-buffer<ret>'                                             -docstring "Delete buffer"
map global buffers D ':delete-buffer!<ret>'                                            -docstring "Delete buffer (force)"
map global buffers Q ':delete-buffer!<ret>'                                            -docstring "Delete buffer (force)"
map global buffers u ':buffer *debug*<ret>'                                            -docstring "Debug buffer"

map global my-tmux <tab>     ':nop %sh{ tmux last-pane }<ret>'      -docstring 'Select last pane'
map global my-tmux J         ':nop %sh{ tmux swap-pane -D }<ret>'   -docstring 'Swap pane below'
map global my-tmux K         ':nop %sh{ tmux swap-pane -U }<ret>'   -docstring 'Swap pane above'

map global my-tmux <ret>     ':winplace auto new<ret>'             -docstring 'Autosplit'
map global my-tmux s         ':winplace vertical new<ret>'              -docstring 'Split horizontally'
map global my-tmux v         ':winplace horizontal new<ret>'            -docstring 'Split vertically'
map global my-tmux p         ':winplace popup new<ret>'                 -docstring 'Popup client'
map global my-tmux o         ':winplace bottom-panel new<ret>'          -docstring 'Bottom panel client'
map global my-tmux d         ':q<ret>'                                  -docstring 'Delete pane'
map global my-tmux q         ':q<ret>'                                  -docstring 'Delete pane'
map global my-tmux t         ':ide-tools<ret>'                          -docstring 'Toggle the tools client'
map global my-tmux T         ':ide-hide-tools<ret>'                     -docstring 'Hide the tools client'

map global my-tmux <c-h>     ':nop %sh{ tmux select-pane -L }<ret>' -docstring 'Select pane to the left'
map global my-tmux <c-j>     ':nop %sh{ tmux select-pane -D }<ret>' -docstring 'Select pane below'
map global my-tmux <c-k>     ':nop %sh{ tmux select-pane -U }<ret>' -docstring 'Select pane above'
map global my-tmux <c-l>     ':nop %sh{ tmux select-pane -R }<ret>' -docstring 'Select pane to the right'

map global my-tmux <c-tab>   ':nop %sh{ tmux last-pane }<ret>'      -docstring 'Select last pane'
map global my-tmux <c-J>     ':nop %sh{ tmux swap-pane -D }<ret>'   -docstring 'Swap pane below'
map global my-tmux <c-K>     ':nop %sh{ tmux swap-pane -U }<ret>'   -docstring 'Swap pane above'

map global my-tmux <c-ret>   ':winplace autos new<ret>'             -docstring 'Autosplit'
map global my-tmux <c-s>     ':winplace vertical new<ret>'              -docstring 'Split horizontally'
map global my-tmux <c-v>     ':winplace horizontal new<ret>'            -docstring 'Split vertically'
map global my-tmux <c-p>     ':winplace popup new<ret>'                 -docstring 'Popup client'
map global my-tmux <c-o>     ':winplace bottom-panel new<ret>'          -docstring 'Bottom panel client'

map global my-tmux <c-d>     ':q<ret>'                           -docstring 'Delete pane'
map global my-tmux <c-t>     ':ide-tools<ret>'                   -docstring 'Toggle the tools client'
map global my-tmux <c-T>     ':ide-hide-tools<ret>'              -docstring 'Hide the tools client'


try %{ set-option global autocomplete insert|prompt|no-regex-prompt }
require-module grep
alias global g grep
map global normal <c-n> %{:jump-next %opt{jump_buffer_recent}<ret>} -docstring 'next Location'
map global normal <c-p> %{:jump-previous %opt{jump_buffer_recent}<ret>} -docstring 'previous Location'
map global normal <c-r> %{:buffer-pop<ret>} -docstring 'pop grep/git buffer'

declare-option str jump_buffer_recent ''

hook global BufSetOption jump_current_line=[^0].* %{
   echo -debug "jump_buffer_recent=%val{bufname}, %val{hook_param}"
   set global jump_buffer_recent %val{bufname}
}

map global normal <c-t> ":enter-user-mode tree-sitter<ret>" -docstring 'Tree sitter...'
map global normal <c-T> ":enter-user-mode tree-sitter-nav-sticky<ret>" -docstring 'Tree sitter nav...'


try %{ declare-user-mode ui }
map global ui   n ':toggle-numbers<ret>' -docstring 'Toggle Line numbers'

# user mode
map global normal  <c-w> ':enter-user-mode my-tmux<ret>'        -docstring 'Tmux...'

map global user e ':enter-user-mode edit<ret>' -docstring "Edit..."

map global user s ':surround-mode<ret>' -docstring 'Surround mode'
map global user r ':enter-replace-mode<ret>' -docstring 'Replace'

map global user u ':enter-user-mode undo<ret>' -docstring 'undo...'
map global user w ':enter-user-mode my-tmux<ret>' -docstring 'Tmux...'
map global user g ':enter-user-mode git<ret>'     -docstring "Git..."
map global user v ':enter-user-mode ui<ret>'      -docstring 'View...'
map global user f ':enter-user-mode files<ret>'   -docstring 'Files...'
map global user b ':enter-user-mode buffers<ret>' -docstring 'Buffers...'

map global user q ':i-delete-buffer<ret>'        -docstring "Close buffer"

map global user <ret> ':winplace auto connect terminal<ret>' -docstring 'Open terminal'
map global user <c-p> ':winplace popup connect terminal<ret>' -docstring 'Popup Terminal'
map global user <tab> ':sidetree<ret>' -docstring 'sidetree'

# System Clipboard
map global user p '<a-!>clip -o<ret>' -docstring 'System paste after'
map global user P '!clip -o<ret>' -docstring 'System paste before'
map global user R '|clip -o<ret>' -docstring 'System replace'
map global user y '<a-|>clip<ret>' -docstring 'System yank'

map global user m ':make<ret>' -docstring 'make'
