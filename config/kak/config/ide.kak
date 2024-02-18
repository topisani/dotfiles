# decl -hidden str toolsclient_tmux_pane

# def ide-perform-setup -hidden %{

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

hook -once global RawKey .* ide-setup

declare-option -hidden str toolsclient_tmux_pane

define-command ide-setup %{
  rmhooks global ide
  set global jumpclient client0

  hook -group ide global ClientClose %opt[toolsclient] %{
    hook -once global NormalIdle .* ide-make-tools
  }
  
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

  hook global WinDisplay "(^$)|(^%opt{loclist_buffer_regex}$|^\*git\*|\*cargo\*)|.*" %{
      eval %sh{
          if [ "$kak_client" = "$kak_opt_toolsclient" ]; then
              if [ -n "$kak_hook_param_capture_2" ]; then
                  echo ide-show-tools
                  echo "focus $kak_opt_toolsclient"
              else
                  # kakoune crashes if this isnt defered somehow
                  # echo "hook -once global NormalIdle .* %{ try %{ eval -client %opt{jumpclient} %{ buffer '$kak_hook_param' } } } "
                  # echo ide-hide-tools
              fi
          fi 
      }
  }

  hook global WinClose .* %{
      eval %sh{
          if [ "$kak_client" = "$kak_opt_toolsclient" ]; then
              echo "ide-hide-tools"
          fi
      }
  }

  hook global FocusIn ^client.* %{
    set global jumpclient %val[client]
  }
  
  ide-make-tools
}

def ide-show-tools %{
    ide-make-tools
    eval %sh{
        tmux=${kak_client_env_TMUX:-$TMUX}
        if [ -z "$tmux" ]; then
            echo "echo -markup '{Error}This command is only available in a tmux session'"
            exit
        fi
        TMUX=$tmux tmux join-pane -p 30 -vs "${kak_opt_toolsclient_tmux_pane}" < /dev/null > /dev/null 2>&1 &
    }
    focus %opt{toolsclient} 
}

def ide-hide-tools %{
    try %{
    eval -client %opt[toolsclient] quit
  } catch %{
    ide-make-tools
  }
}

def -hidden ide-make-tools %{
  try %{
    eval -client tools nop
  } catch %{
    set global toolsclient tools
    # set global docsclient tools
    eval %sh{
      TMUX=${kak_client_env_TMUX:-$TMUX}
      DEST=$(tmux neww -dP -t :10 kak -c $kak_session -e 'rename-client tools' 2> /dev/null || tmux splitw -dP -t :10 kak -c $kak_session -e 'rename-client tools')
      [ $? -eq 0 ] && echo "set global toolsclient_tmux_pane '$DEST'"
    }
  }
}

def ide-tools -docstring "ide-tools: Focus or hide the tools client" %{
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
            echo "try %{ eval -client %opt{toolsclient} quit }"
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
