provide-module ide %§
  decl -hidden str toolsclient_tmux_pane

  def ide-perform-setup -hidden %{

    ide-make-tools

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
                echo "focus $kak_opt_toolsclient"
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

    hook global FocusIn ^client.* %{
      set global jumpclient %val[client]
    }
  }

  def -hidden ide-make-tools %{
    set global jumpclient %val{client}
    try %{
      eval -client "%opt[toolsclient]" %{
        #quit
      }
    }
    set global toolsclient tools
    eval %sh{
      TMUX=${kak_client_env_TMUX:-$TMUX}
      tmux new-session -ds "kakoune-background" &> /dev/null
      DEST=$(tmux new-window -P -t kakoune-background kak -c $kak_session -e 'rename-client tools')
      [[ $? == 0 ]] && echo "set global toolsclient_tmux_pane '$DEST'"
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
          }
      }
  }

  def ide-show-tools %{
      try %{
        eval -client tools ""
      } catch %{
        ide-make-tools
      }
      eval %sh{
          tmux=${kak_client_env_TMUX:-$TMUX}
          if [ -z "$tmux" ]; then
              echo "echo -markup '{Error}This command is only available in a tmux session'"
              exit
          fi
          TMUX=$tmux tmux join-pane -fp 30 -vs "${kak_opt_toolsclient_tmux_pane}" < /dev/null > /dev/null 2>&1 &
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

  def ide-setup %{
    hook -once global RawKey .* ide-perform-setup
  }
§
