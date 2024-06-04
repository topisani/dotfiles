declare-option -hidden str auto_pairs_scope global

define-command -hidden -override auto-pairs-setup-pair-impl -params 3 %{
  hook -group auto-pairs %opt{auto_pairs_scope} InsertChar "%arg{2}" %exp{
    execute-keys '%arg{1}<a-;>h'
  }
  hook -group auto-pairs %opt{auto_pairs_scope} InsertChar "%arg{3}" %exp{
    try %%{
      execute-keys -draft ';<a-k>%arg{3}<ret>dl'
    }
  }
  hook -group auto-pairs %opt{auto_pairs_scope} InsertDelete "%arg{2}" %exp{
    try %%{
      execute-keys -draft ';<a-k>%arg{3}<ret>d'
    } 
  }
}

define-command auto-pairs-setup-pair -params 2 %{
  eval %sh{
    keyname=$2
    case "$2" in
      "'")
        keyname="''''"
        ;;
      "<")
        keyname="<lt>"
        ;;
      ">")
        keyname="<gt>"
        ;;
    esac
    echo auto-pairs-setup-pair-impl "'$keyname'" $(printf "'\\\x%x'" "'$1") $(printf "'\\\x%x'" "'$2")
  }
}

define-command auto-pairs-enable %{
  remove-hooks %opt{auto_pairs_scope} auto-pairs
  auto-pairs-setup-pair { }
  auto-pairs-setup-pair [ ]
  auto-pairs-setup-pair ( )
  # auto-pairs-setup-pair < >
  # auto-pairs-setup-pair "'" "'"
  # auto-pairs-setup-pair '"' '"'
}
