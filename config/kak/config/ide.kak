# decl -hidden str toolsclient_tmux_pane

# def -override ide-perform-setup -hidden %{

# }


# decl -docstring "Folder that paths in make buffer are relative to" str make_folder "."

# define-command -override -hidden make-open-error -params 4 %{ eval %sh{
#   path=$1
#   echo "$path" | grep '^/' && path="$kak_opt_make_folder/$path"; 
#   echo 'evaluate-commands -try-client %opt{jumpclient} %{'
#   echo "edit -existing \"$path\" %arg{2} %arg{3}"
#   echo 'echo -markup "{Information}%arg{4}"'
#   echo 'try %{ focus }'
#   echo '}'
# }}

hook -once global WinDisplay .* ide-setup

declare-option -hidden str toolsclient_tmux_pane

define-command ide-setup -override %{
  rmhooks global ide
  set global jumpclient client0
  
  hook -group ide global ClientClose .* %{
      try %{    
          eval -client tools %sh{
              if ! echo " $kak_client_list " | grep -q ' client[0-9]+'; then
                echo ide-show-tools
                echo quit
              fi
          }
      }
  }

  hook -group ide global WinDisplay "(^$)|(\*(:?git|cargo|goto|grep|symbols|make|lint)\*)|.*" %{
      eval %sh{
          if [ "$kak_client" = "$kak_opt_toolsclient" ]; then
              if [ -n "$kak_hook_param_capture_2" ]; then
                  echo ide-show-tools
                  echo "focus $kak_opt_toolsclient"
              # else
                  # kakoune crashes if this isnt defered somehow
                  # echo "hook -once global NormalIdle .* %{ try %{ eval -client %opt{jumpclient} %{ buffer '$kak_hook_param' } } } "
                  # echo ide-hide-tools
              fi
          fi 
      }
  }

  hook -group ide global WinClose .* %{
      eval %sh{
          if [ "$kak_client" = "$kak_opt_toolsclient" ]; then
              echo "ide-hide-tools"
          fi
      }
  }

  hook -group ide global FocusIn client.* %{
    try %{
      eval %sh{
        case "$kak_buffile" in
          \**\*) echo fail ;;
          *) ;;
        esac
        [ "$kak_hook_param" == "$kak_opt_docsclient" ] && echo fail
      }
      set global jumpclient %val{hook_param}
    }
  }

  hook -group ide global ClientClose tools %{
    hook -once global NormalIdle .* ide-make-tools
  }
  
  ide-make-tools
}


def -override ide-show-tools %{
    ide-make-tools
    eval %sh{
        tmux=${kak_client_env_TMUX:-$TMUX}
        if [ -z "$tmux" ]; then
            # echo "echo -markup '{Error}This command is only available in a tmux session'"
            echo "set local windowing_placement bottom-panel"
            echo "set global toolsclient tools"
            echo "new 'rename-client tools'"
        else
          TMUX=$tmux tmux join-pane -l 30% -vs "${kak_opt_toolsclient_tmux_pane}" < /dev/null > /dev/null 2>&1 &
        fi
    }
    # focus %opt{toolsclient} 
}

def -override ide-hide-tools %{
    try %{
    eval -client %opt[toolsclient] quit
  } catch %{
    ide-make-tools
  }
}

def -override -hidden ide-make-tools %{
  try %{
    eval -client tools nop
  } catch %{
    # set global docsclient tools
    eval %sh{
      TMUX=${kak_client_env_TMUX:-$TMUX}
      if [ -z "$tmux" ]; then
          # echo "echo -markup '{Error}This command is only available in a tmux session'"
          exit
      fi
      DEST=$(tmux neww -dP -t :10 kak -c $kak_session -e 'rename-client tools' 2> /dev/null || tmux splitw -dP -t :10 kak -c $kak_session -e 'rename-client tools')
      echo "set global toolsclient tools"
      [ $? -eq 0 ] && echo "set global toolsclient_tmux_pane '$DEST'"
    }
  }
}

def -override ide-docs -params .. %{
  new %{
    rename-client docs
    set global docsclient docs
    eval %arg{@}
  }
}

def -override ide-tools -docstring "ide-tools: Focus or hide the tools client" %{
  eval %sh{
    if [ "$kak_client" = "$kak_opt_toolsclient" ]; then
      echo "ide-hide-tools"
    else
      echo "ide-show-tools"
    fi
  }
}

define-command -override ide-quit -docstring "
ide-quit: quit the kakoune client. If it is the last non-tools client, the tools client is closed first" %{
    eval %sh{
        remaining=$(printf "%s\n" $kak_client_list | sed "/$kak_client/d;/$kak_opt_toolsclient/d")
        if [ -z $remaining ]; then
            # No other real clients remaining. Close toolsclient first
            echo "remove-hooks global ide"
            echo "hook -once global NormalIdle .* ide-setup"
            echo "try %{ eval -no-hooks -client %opt{toolsclient} quit }"
        fi
        echo quit
    }
}

define-command -override ide-quit-notlast -docstring "
ide-quit: quit the kakoune client. If it is the last non-tools client, the tools client is closed first" %{
    eval %sh{
        remaining=$(printf "%s\n" $kak_client_list | sed "/$kak_client/d;/$kak_opt_toolsclient/d")
        if [ -n $remaining ]; then
            echo ide-quit
        fi
    }
}

alias global q ide-quit
