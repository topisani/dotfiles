decl str local_config_dir

def source-local-config -override -params ..1 %{
  eval %sh{
      upsearch () {
          if test "$PWD" = "/"; then
              return
          elif test -e "$1"; then
              echo "set buffer local_config_dir $PWD"
              echo "source $PWD/$1"
              return
          else
              cd ..
              upsearch "$1"
          fi
      }
      startdir=${1:-$(dirname "$kak_buffile")}
      [ -d "$startdir" ] && cd $startdir
      upsearch ".local.kak"
  }
}

hook global BufCreate .* source-local-config 
hook global BufCreate .* modeline-parse
