define-command -hidden setup-surround-pair -params 2 -override %{
  eval %sh{
    echo "hook window -group surround InsertChar %§\Q$1\E§ %¤exec -draft a %§$2§ <esc>%¤"
    echo "hook window -group surround InsertDelete %§\Q$1\E§ %¤try %£ set-register a %§$2§; exec -draft %§<a-;>l<a-k>\Q<c-r>a\E<ret>d§ £¤"
    [ "$2" != "$1" ] && echo "hook window -group surround InsertChar %§\Q$2\E§ %¤try %£ set-register a %§$2§; exec -draft %§<a-;>l<a-k>\Q<c-r>a\E<ret>d§ £¤"
  }
}

define-command surround-mode -override %§
  
  setup-surround-pair "(" ")"
  setup-surround-pair "[" "]"
  setup-surround-pair "<" ">"
  setup-surround-pair "{" "}"
  setup-surround-pair "'" "''"
  setup-surround-pair '"' '"'
  setup-surround-pair '`' '`'

  try disable-auto-pairs
  exec -with-hooks i
  
  hook window -group surround ModeChange pop:insert:.* %{
    remove-hooks window surround
    try enable-auto-pairs
  }
§
