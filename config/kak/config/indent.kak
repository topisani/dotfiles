define-command -override set-indent -params 2..3 -docstring 'set-indent <scope> <width>: set indent in <scope> to <width>' %{
  eval %sh{
    if [ "$2" = "tabs" ]; then
      echo "set-option $1 tabstop ${3}"
      echo "set-option $1 indentwidth 0"
      echo "echo -debug 'set-indent: tabs=$3'"
    else
      echo "set-option $1 tabstop $2"
      echo "set-option $1 indentwidth $2"
      echo "echo -debug 'set-indent: $2 spaces'"
    fi
  }
}

define-command -override enable-trim-trailing-whitespace -docstring 'enable-trim-trailing-whitespace: Enable automatic trailing whitespace trim on save' %{
  remove-hooks window trim-trailing-whitespace
  hook window -group trim-trailing-whitespace BufWritePre '.*' %{
    try %{
      execute-keys -draft "%s\h+$|\n+\z<ret>d"
    }
  }
}

define-command -override disable-trim-trailing-whitespace -docstring 'disable-trim-trailing-whitespace: Disable automatic trailing whitespace trim on save' %{
  remove-hooks window trim-trailing-whitespace
}

define-command editorconfig-load -override -params ..1 -docstring "editorconfig-load [file]: set formatting behavior according to editorconfig" %{
  evaluate-commands %sh{
    command -v editorconfig >/dev/null 2>&1 || { echo "fail editorconfig could not be found"; exit 1; }

    file="${1:-$kak_buffile}"
    case $file in
      /*) # $kak_buffile is a full path that starts with a '/'
        editorconfig "$file" | awk -v file="$file" -F= -- '
          $1 == "indent_style"             { indent_style = $2 }
          $1 == "indent_size"              { indent_size = $2 == "tab" ? 8 : $2 }
          $1 == "tab_width"                { tab_width = $2 }
          $1 == "end_of_line"              { end_of_line = $2 }
          $1 == "charset"                  { charset = $2 }
          $1 == "trim_trailing_whitespace" { trim_trailing_whitespace = $2 }
          $1 == "max_line_length"          { max_line_length = $2 }

          END {
            if (indent_style == "tab") {
              print "set-option window indentwidth 0"
            }
            if (indent_style == "space") {
              print "set-option window indentwidth " indent_size
            }
            if (indent_size || tab_width) {
              print "set-option window tabstop " (tab_width ? tab_width : indent_size)
            }
            if (end_of_line == "lf" || end_of_line == "crlf") {
              print "set-option window eolformat " end_of_line
            }
            if (charset == "utf-8-bom") {
              print "set-option window BOM utf8"
            }
            if (trim_trailing_whitespace == "true") {
              print "enable-trim-trailing-whitespace"
            }
            if (max_line_length && max_line_length != "off") {
              # print "set window autowrap_column " max_line_length
              # print "autowrap-enable"
              # print "add-highlighter window/ column %sh{ echo $((" max_line_length "+1)) } default,bright-black"
            }
          }
        ' ;;
    esac
  }
}
complete-command editorconfig-load file

define-command -override detect-indent -docstring 'detect indent' %{
  evaluate-commands -draft %{
    try %{
      execute-keys 'gg/^\t<ret>'
      unset-option window tabstop
      set-indent window tabs %opt{tabstop}
    } catch %{
      # Search the first indent level
      # Assume even number of spaces, maximum 8
      execute-keys 'gg/^((  ){1,4})[^ ]<ret>H'
      set-indent window %val{selection_length}
    } catch %{
    }
    editorconfig-load
  }
}

define-command -override enable-detect-indent -docstring 'enable detect indent' %{
  remove-hooks global detect-indent
  hook -group detect-indent global WinCreate '.*' detect-indent
  hook -group detect-indent global BufWritePost '.*' detect-indent
  hook -group detect-indent global BufReload '.*' detect-indent
}

define-command -override disable-detect-indent -docstring 'disable detect indent' %{
  remove-hooks global detect-indent
  evaluate-commands -buffer '*' %{
    unset-option window tabstop
    unset-option window indentwidth
  }
}

# Indent
define-command -override enable-auto-indent -docstring 'enable auto-indent' %{
  remove-hooks global auto-indent
  hook -group auto-indent global InsertChar '\n' %{
    evaluate-commands -draft -itersel %{
      # Copy previous line indent
      try %[ execute-keys -draft 'K<a-&>' ]
      # Clean previous line indent
      try %[ execute-keys -draft 'k<a-x>s^\h+$<ret>d' ]
    }
  }

  # Disable other indent hooks:
  # https://github.com/mawww/kakoune/tree/master/rc/filetype
  set-option global disabled_hooks '(?!auto)(?!detect)\K(.+)-(trim-indent|insert|indent)'
}

define-command -override disable-auto-indent -docstring 'disable auto-indent' %{
  remove-hooks global auto-indent
  set-option global disabled_hooks ''
}

define-command -override -hidden insert-mode-tab -params 1 %{
  try %{
    # 1: Indent if at start of line
    exec -draft ";Gh<a-k>^\h*.\z<ret><a-%arg{1}>"
  } catch %{
    lsp-snippets-select-next-placeholders
  } catch %{
    exec -with-hooks "<tab>"
  }
}

map global insert <tab> '<a-;>: insert-mode-tab gt<ret>' -docstring 'Increase indent' 
map global insert <s-tab> '<a-;>: insert-mode-tab lt<ret>' -docstring 'Decrease indent' 

hook global InsertCompletionShow .* %{
  try %{
    # this command temporarily removes cursors preceded by whitespace;
    # if there are no cursors left, it raises an error, does not
    # continue to execute the mapping commands, and the error is eaten
    # by the `try` command so no warning appears.
    execute-keys -draft 'h<a-K>\h<ret>'
    
    map window insert <tab>   <c-n>
    map window insert <s-tab> <c-p>
    hook -once -group tabcomplete-impl window RawKey '<tab>|<s-tab>' %{
      map window insert <ret> <c-o>
    }
    hook -once -always window InsertCompletionHide .* %{
      remove-hooks window tabcomplete-impl
      unmap window insert <tab> <c-n>
      unmap window insert <s-tab> <c-p>
      unmap window insert <ret> <c-o>
    }
  }
}

remove-hooks global delete-indent-space
hook global -group delete-indent-space InsertDelete ' ' %{
  exec -draft 'i '
  try %{
    eval -draft "exec ';Gh<a-k>^([ ]{%opt[indentwidth]})+.\z<ret><lt>'"
  } catch %{
      exec -draft 'i<backspace>'
  }
}
