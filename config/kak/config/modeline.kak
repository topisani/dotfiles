
declare-option str modeline_client_flags ""
def update-client-flags -hidden -override %{
  eval %sh{
    set -- $kak_client_list
    for client do
      val=""
      [ "$client" = "$kak_opt_jumpclient" ] && val="${val}j"
      [ "$client" = "$kak_opt_docsclient" ] && val="${val}d"
      [ "$client" = "$kak_opt_toolsclient" ] && val="${val}t"
      [ -n "$val" ] && val="[$val]"
      echo "eval -client $client %{ set window modeline_client_flags '$val' }"
    done
  }
}
rmhooks global modeline-client-flags
hook -group modeline-client-flags global WinDisplay .* update-client-flags
hook -group modeline-client-flags global FocusIn .* update-client-flags
hook -group modeline-client-flags global FocusOut .* update-client-flags
hook -group modeline-client-flags global GlobalSetOption '(jump|docs|tools)client=.*' update-client-flags

# Modeline
set-face global StatusLineBlack black
set-face global StatusLineGit "red"

declare-option str bufname_abbrev

define-command -hidden -override update-bufname-abbrev %{
  try %{
    set-option window bufname_abbrev %sh{
      if [ ${#kak_bufname} -gt $((${kak_window_width:-10000} / 3)) ]; then
        echo $kak_bufname | sed "s:\([^/]\)[^/]*/:\1/:g"
      else
        echo $kak_bufname
      fi
    }
  }
}

hook global -group bufname-abbrev WinDisplay .* update-bufname-abbrev
hook global -group bufname-abbrev WinResize .* update-bufname-abbrev
hook global -group bufname-abbrev EnterDirectory .* update-bufname-abbrev
hook global -group bufname-abbrev EnterDirectory .* update-bufname-abbrev

# declare-option str myml_git

# rmhooks global myml
# # Main hook (git branch update, gutters)
# hook global -group myml NormalIdle .* %{
#   set-option window myml_git %sh{ $(git rev-parse --is-inside-work-tree 2> /dev/null) && echo " $(git rev-parse --abbrev-ref HEAD) "}
# }

declare-option str myml_mode_str "NORMAL"

hook -group myml global ModeChange (push|pop).*:([^:]+) %{
  set window myml_mode_str %sh{ echo $kak_hook_param_capture_2 | perl -npe '
  s/normal/NORMAL/ ;
  s/insert/INSERT/ ;
  s/next-key\[(?:user\.)?(.*)\]/$1/ ; 
  s/user-mapping/user/ ;
'}
}

decl str myml_lsp_error ''
decl str myml_lsp_warning ''
decl str myml_lsp_info ''
decl str myml_lsp_hint ''
hook -group myml global WinSetOption lsp_diagnostic_(\w+)_count.* %{
  eval %sh{
    [ $kak_opt_lsp_diagnostic_error_count != 0 ] && echo 'set window myml_lsp_error " %opt{lsp_diagnostic_error_count} "' 
    [ $kak_opt_lsp_diagnostic_warning_count != 0 ] && echo 'set window myml_lsp_warning " %opt{lsp_diagnostic_warning_count} "' 
    [ $kak_opt_lsp_diagnostic_info_count != 0 ] && echo 'set window myml_lsp_info " %opt{lsp_diagnostic_info_count} "' 
    [ $kak_opt_lsp_diagnostic_hint_count != 0 ] && echo 'set window myml_lsp_hint " %opt{lsp_diagnostic_hint_count} "' 
  }
}

def -hidden set-my-modelinefmt %{
  set-option global modelinefmt %sh{
  tr -d '\n' <<'EOF'
{annotation}%opt{modeline_lsp_progress}
%opt{lsp_modeline_breadcrumbs}%opt{lsp_modeline_code_actions}
%opt{lsp_modeline_message_requests}
{StatusLspError}%opt{myml_lsp_error}
{StatusLspWarning}%opt{myml_lsp_warning}
{StatusLspInfo}%opt{myml_lsp_info}
{StatusLspHint}%opt{myml_lsp_hint}
{bright-magenta}%val{selection_count} %sh{[ $kak_selection_count != 1 ] && echo "sels ($kak_main_reg_hash)" || echo "sel"} 
%sh{[ -n "$kak_register" ] && echo "reg=$kak_register "}
%sh{[ -n "$kak_count" ] && [ $kak_count != 0 ] && echo "count=$kak_count "}
{cyan+i}%opt{bufname_abbrev}{annotation}:{bright-blue+d}%val{cursor_line}{annotation}:{bright-blue+d}%val{cursor_char_column}{annotation}+{bright-blue+d}%val{selection_length}
{{context_info}} 
{+da@comment}%opt{filetype} 
{magenta}%val{client}{magenta+d} {magenta}%val{session}{magenta+d}%opt{modeline_client_flags} 
{cyan}U+%sh{printf '%04X' "$kak_cursor_char_value"}{default} 
{+r@StatusLineMode} %opt{myml_mode_str} 
EOF
  }
# {yellow}%opt{myml_git}
}

set-my-modelinefmt
