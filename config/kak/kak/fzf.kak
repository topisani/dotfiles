def fzf-file -params 0..1 %{
    fzf "edit $1" "find -L %arg{1} -name .git -prune -o -name .svn -prune -o -regex '.*\(bower_components\|output\|.mozilla\|firefox\|node_modules\|grunt\|cache\|Cache\|config/\(Slack\|chromium\|goole-chrome\)\).*' -prune -o \( -type f -o -type l \) -a -not -path %arg{1} -a -not -name '.' -print | sed 's@^\./@@'"
                # "ag -l -f -p ~/.binignore -p ~/.ignore --hidden --one-device . %arg{1}"
                # "rg --ignore-file ~/.binignore -L --hidden --files %arg{1}"
}

def fzf-git -params 0..1 %{
    fzf "edit $1" "git ls-tree --name-only -r HEAD %arg{1}"
}

def fzf-tag -params 0..1 %{
    fzf "tag $1" "readtags -l | cut -f1 | sort -u"
}

def fzf-cd -params 0..1 %{
    fzf "cd $1" "find %arg{1} -type d -path *.git -prune -o -type d -print"
}

def fzf -params 2.. -docstring \
"fzf <callback> <items-command> [flags..]: Run fzf
options:
    <callback>: Kak command to run on selection. '$1' will be expanded to item.
    <items-command>: Shell command to get items.
flags:
    -multi: allow multiple selected items. <callback> will be run for each." \
%{ exec %sh{
    tmp=$(mktemp /tmp/kak-fzf.XXXXXX)
    exec=$(mktemp /tmp/kak-exec.XXXXXX)
    callback=$1; shift
    items_command=$1; shift
    flags='--color=16'
    [[ " $@ " =~ " -multi " ]] && flags="$flags -m"
    echo "echo eval -client $kak_client \"$callback\" | kak -p $kak_session" > $exec
    chmod 755 $exec
    (
        # todo: expect ctrl-[vw] to make execute in new windows instead
        eval "$items_command | fzf-tmux -d 15 $flags > $tmp"
        (while read file; do
            $exec $file
        done) < $tmp
        rm $tmp
        rm $exec
    ) > /dev/null 2>&1 < /dev/null &
} }

def fzf-buffer %{ exec %sh{
    tmp=$(mktemp /tmp/kak-fzf.XXXXXX)
    setbuf=$(mktemp /tmp/kak-setbuf.XXXXXX)
    delbuf=$(mktemp /tmp/kak-delbuf.XXXXXX)
    echo 'echo eval -client $kak_client "buffer        $1" | kak -p $kak_session' > $setbuf
    echo 'echo eval -client $kak_client "delete-buffer $1" | kak -p $kak_session' > $delbuf
    echo 'echo eval -client $kak_client bufzf              | kak -p $kak_session' >> $delbuf
    chmod 755 $setbuf
    chmod 755 $delbuf
    (
        # todo: expect ctrl-[vw] to make execute in new windows instead
        eval "echo $kak_buflist | tr ':' '\n' | sort |
            fzf-tmux -d 15 --reverse --color=16 -0 -1 -e '--preview=$setbuf {}' --preview-window=up:0 --expect ctrl-d > $tmp"
        if [ -s $tmp ]; then
            ( read action
              read buf
              if [ "$action" == "ctrl-d" ]; then
                  $setbuf $kak_bufname
                  $delbuf $buf
              else
                  $setbuf $buf
              fi) < $tmp
        else
            $setbuf $kak_bufname
        fi
        rm $tmp
        rm $setbuf
        rm $delbuf
    ) > /dev/null 2>&1 < /dev/null &
} }
