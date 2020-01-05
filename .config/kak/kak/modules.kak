 try %{
    decl str-list imported_modules "modules"
}

# Import a module by name. Checks if the module has already been imported
def import -params 1 -shell-script-candidates %{find -L $HOME/.config/kak/kak/ -type f -name "*.kak" | sed "s|$HOME/.config/kak/kak/\(.*\)\.kak$|\1|"} \
%{ try %{ evaluate-commands %sh{
    if ! [[ " $kak_opt_imported_modules " =~ " '$1' " ]]; then
        #echo "Importing $1" >> /dev/stderr # DEBUG MESSAGE
        echo "source $HOME/.config/kak/kak/$1.kak"
        echo "set -add global imported_modules $1" 
    fi
}}}
