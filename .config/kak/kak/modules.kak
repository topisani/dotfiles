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

decl str-list installed_plugs

def plug -params 1..2 %{
    set -add global installed_plugs %sh{ echo $1,${2:-.} }
}

def install-plugs %{ nop %sh{
    basedir=$HOME/.config/kak/plugs
    includedir=$HOME/.config/kak/kak
    while read plug; do
        uri=$(cut -d ',' -f1 <<< $plug)
        dir=$basedir/$uri
        if [[ ! -e $dir ]]; then
            folder=$(cut -d ',' -f2 <<< $plug)
            folder=${folder:-.}
            user=$(cut -d'/' -f1 <<< $uri)
            mkdir -p $basedir/$user
            cd $basedir
            git clone https://github.com/$uri $uri
            mkdir -p $includedir/$user
            ln -s $basedir/$uri/$folder $includedir/$uri
            [[ ! -e $includedir/.gitignore ]] && touch $includedir/.gitignore
            grep -qFx /$uri $includedir/.gitignore || echo /$uri >> $includedir/.gitignore
        fi
    done <<< $(xargs -n1 <<<"$kak_opt_installed_plugs" )
}}

def update-plugs %{
    install-plugs
    nop %sh{
        basedir=$HOME/.config/kak/plugs
        includedir=$HOME/.config/kak/kak
        IFS=$'\n' plugins=( $(xargs -n1 <<< "$kak_opt_installed_plugs" ))
        while read plug; do
            uri=$(cut -d ',' -f1 <<< $plug)
            cd $basedir/$uri
            git pull origin
        done <<< $(xargs -n1 <<<"$kak_opt_installed_plugs" )
    }
}

def clean-plugs %{ nop %sh{
    basedir=$HOME/.config/kak/plugs
    includedir=$HOME/.config/kak/kak
    IFS=$'\n' plugins=( $(xargs -n1 <<< "$kak_opt_installed_plugs" ))
    rm -rf $basedir/**
    while read plug; do
        uri=$(cut -d ',' -f1 <<< $plug)
        user=$(cut -d'/' -f1 <<< $uri)
        [[ -L $includedir/$uri ]] && rm $includedir/$uri
        rmdir $includedir/$user --ignore-fail-on-non-empty
        [[ -f $includedir/.gitignore ]] && sed -i "/^\\/${uri//\//\\/}$/d" $includedir/.gitignore
    done <<< $(xargs -n1 <<<"$kak_opt_installed_plugs" )
}}
