# Util functions
provide-module -override my-utils %{

  def repl-ask %{
      prompt "Run:" 'repl "confirm-exit %val{text}"'
  }

  # Define user mode

  def new-mode -params 1.. -docstring \
  "new-mode <name> [key] [flags..] [body]: Declare a new user mode
  options:
      <name>: Name of mode.
      [key]: If provided, this key will be mapped to enter the mode.
      [body]: sent to map-all'.
  flags:
      -scope to register keybinds in.
      -docstring <str>: Docstring for keybind. Defaults to '<name>...'
      -parent <mode>: Mode to register keybinding in. Defaults to 'user'" \
  %{ eval %sh{
    source ~/.config/kak/scripts/utils.sh
    new_mode "$@"
  }}

  def map-all -params 2.. -docstring \
  "map-all <mode> <body> [flags..]: Map all keys in <body> to <mode>
  options:
      <body>: lines expanded to 'map-mode <mode> {line}'.
  flags:
      all flags are forwarded to every keybind. See map-mode"\
  %{ eval %sh{
    source ~/.config/kak/scripts/utils.sh
    map_all "$@"
  }}

  def map-mode -params 3.. -docstring \
  "map-mode <mode> <key> <command> [docstring] [flags..]:
  map <key> in <mode> to <command>
  options:
      [docstring] defaults to <command>
  flags:
      -scope <scope>: register key in <scope>
      -raw: interpret <command> as raw keypresses
      -sh: run <command> in a shell, ignoring the output
      -repeat: After execution, return to <mode>
      -norepeat: force this entry to skip repetition" \
  %{ eval %sh{
    source ~/.config/kak/scripts/utils.sh
    map_mode "$@"
  }}

  def filetype-hook -params 2.. -docstring \
  "filetype-hook <filetype> [switches] <command>:
  Add hook for opening a buffer matching <filetype>
  options:
      <command>: Command to run on hook
  switches:
      -scoppe: window or buffer.
      -group: Group to add hook to.
  "\
  %{ eval %sh{
      filetype=$1; shift
      flags=''
      hook=WinSetOption
      while [[ $# != 0 ]] && [[ "$1" =~ "^-" ]]; do
          case $1 in
              -group)
                  shift
                  flags="$flags -group $1"
                  ;;
              -scope)
                  shift
                  [[ "$1" == "window" ]] && hook="WinSetOption"
                  [[ "$1" == "buffer" ]] && hook="BufSetOption"
                  ;;
          esac
          shift
      done
      echo "hook $flags global $hook filetype=$filetype %{$@}"
  }}
}

provide-module user-mode %{
  require-module my-utils

  map-all normal %{
    '#' comment-line "Comment line"
    '<a-#>' comment-block "Comment line"
  }

  def file-delete -docstring \
  "Delete current file" %{
     prompt "Delete file [Y/n]? " '%sh{ [[ "$kak_text" =~ [yY] ]] && rm $kak_buffile && echo "delete-buffer" }' 
  }

  new-mode files f %{
      f "fzf-file"                               "List files"
      t 'lf %reg[percent]'                       "File tree (current file)"
      T "lf ."                                   "File tree (current dir)"
      w "write"                                  "Write file" 
      c "fzf-file ~/.config/kak/"                "Open config dir"
      d "file-delete"                            "Delete current file"
  }

  new-mode buffers b %{
      b fzf-buffer      "List Buffers" 
      n buffer-next     "Next Buffer" 
      p buffer-previous "Prev buffer" 
      d delete-buffer   "Delete buffer"
      u 'buffer *debug*' "Debug buffer"
  }

  def tmux-new-vertical -params .. -command-completion %{
    tmux-terminal-vertical kak -c %val{session} -e "%arg{@}"
  }

  def tmux-new-horizontal -params .. -command-completion %{
    tmux-terminal-horizontal kak -c %val{session} -e "%arg{@}"
  }

  new-mode my-tmux w %{
      h     'tmux select-pane -L' 'Select pane to the left'  -sh
      j     'tmux select-pane -D' 'Select pane below'        -sh
      k     'tmux select-pane -U' 'Select pane above'        -sh
      l     'tmux select-pane -R' 'Select pane to the right' -sh

      <tab> 'tmux last-pane'      'Select last pane'         -sh
      J     'tmux swap-pane -D'   'Swap pane below'          -sh
      K     'tmux swap-pane -U'   'Swap pane above'          -sh

      s     'tmux-new-vertical'   'Split horizontally'
      v     'tmux-new-horizontal' 'Split vertically'
      d     quit                  'Delete pane'
  }

  def git-blame-toggle %{
      try %[
          addhl window/git-blame flag_lines Info git_blame_flags
          rmhl window/git-blame
          git blame
      ] catch %[
          git hide-blame
      ]
  }

  new-mode git g %{
      g     'repl tig'            'Open tig'
      f     'fzf-git'             'Open files in repo'
      p     ':git '               'Open git prompt' -raw
      b     'git-blame-toggle'    'Toggle git blame'
  }

  # switch windows
  map-all user -sh %{
      1 'tmux-select-pane 1'  'Select pane 1'
      2 'tmux-select-pane 2'  'Select pane 2'
      3 'tmux-select-pane 3'  'Select pane 3'
      4 'tmux-select-pane 4'  'Select pane 4'
      5 'tmux-select-pane 5'  'Select pane 5'
      6 'tmux-select-pane 6'  'Select pane 6'
      7 'tmux-select-pane 7'  'Select pane 7'
      8 'tmux-select-pane 8'  'Select pane 8'
      9 'tmux-select-pane 9'  'Select pane 9'
      0 'tmux-select-pane 10' 'Select pane 10'
  }
}
