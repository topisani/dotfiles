define-command -hidden setup-surround-pair -params 3 -override %{
  eval %sh{
    echo -e "hook window -group surround InsertChar $1 'exec -draft a $2 <esc>' "
    echo -e "hook window -group surround InsertDelete $1 'try %§ set-register a $3; exec -draft \"<a-;>l<a-k>[<c-r>a]<ret>d\" §'"
  }
}

define-command surround-mode -override %§
  # Please dont mess with the escaping bruv
  setup-surround-pair "\(" ")" ")"
  setup-surround-pair "\[" "]" "\]"
  setup-surround-pair "<" ">" ">"
  setup-surround-pair "\{" "}" "\}"
  setup-surround-pair %["'"] %["''"] %["''"]
  setup-surround-pair '""""' '""""' '""""'

  exec -with-hooks i
  
  hook window -group surround ModeChange pop:insert:.* %{
    remove-hooks window surround
  }
§
