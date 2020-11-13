decl -hidden str toolsclient_tmux_pane


def ide-setup %{
  ide-perform-setup
}

def ide-perform-setup -hidden %{
  require-module tmux

  set global jumpclient client0

  tmux-terminal-impl "split-window -p 0" kak -c %val{session} -e 'rename-client tools; ide-hide-tools'
  set global toolsclient tools

  hook -group ide global ClientClose .* %{
      eval -client tools %sh{
          if [[ ! " $kak_client_list " =~ \ client[0-9]+\  ]]; then
              echo "echo -debug '$kak_client_list'"
              echo "remove-hooks global ide"
              echo "quit"
          fi
      }
      try %{
        eval -client %opt[kaktreeclient] %sh{
          if [[ ! " $kak_client_list " =~ \ client[0-9]+\  ]]; then
            echo "quit"
          fi
        }
      }
  }

  hook global WinDisplay .* %{
      eval %sh{
          if [[ "$kak_client" == "$kak_opt_toolsclient" ]]; then
              echo ide-show-tools
              echo "map window my-tmux d ' :delete-buffer<ret> :ide-hide-tools<ret>'"
              echo "map window buffers d ' :delete-buffer<ret> :ide-hide-tools<ret>'"
              echo "focus %opt[toolsclient]"
          fi 
      }
  }

  hook global WinClose .* %{
      eval %sh{
          if [[ "$kak_client" == "$kak_opt_toolsclient" ]]; then
              echo "ide-hide-tools"
          fi
      }
  }

  hook global BufClose .* %{
      eval %sh{
          if [[ "$kak_client" == "$kak_opt_toolsclient" ]]; then
              echo "ide-hide-tools"
          fi
      }
  }
}

def ide-hide-tools %{
    eval -client tools %{
        buffer *debug*
        eval %sh{
        TMUX=${kak_client_env_TMUX:-$TMUX}
        tmux new-session -ds "kakoune-background" &> /dev/null
      pane=$(tmux break-pane -dP -t "kakoune-background:")
        [[ $? == 0 ]] && echo "set global toolsclient_tmux_pane '$pane'"
    }}
}

def ide-show-tools %{
    eval %sh{
        [[ $kak_client != "tools" ]] && echo "set global jumpclient '$kak_client'"
        tmux=${kak_client_env_TMUX:-$TMUX}
        if [ -z "$tmux" ]; then
            echo "echo -markup '{Error}This command is only available in a tmux session'"
            exit
        fi
        TMUX=$tmux tmux join-pane -p 30 -vs "${kak_opt_toolsclient_tmux_pane}" < /dev/null > /dev/null 2>&1 &
    }
    focus %opt{toolsclient} 
}

decl -docstring "Folder that paths in make buffer are relative to" str make_folder "."

define-command -override -hidden make-open-error -params 4 %{ eval %sh{
  path=$1
  [[ ! $path =~ ^/ ]] && path="$kak_opt_make_folder/$path"; 
  echo 'evaluate-commands -try-client %opt{jumpclient} %{'
  echo "edit -existing \"$path\" %arg{2} %arg{3}"
  echo 'echo -markup "{Information}%arg{4}"'
  echo 'try %{ focus }'
  echo '}'
}}
