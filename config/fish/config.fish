set -g fish_greeting
if status is-interactive
    # Commands to run in interactive sessions can go here
    # 
    starship init fish | source
    zoxide init fish | source


    COMPLETE=fish jj | source
end

function k
    set -q $KAKOUNE_SESSION && krc attach $argv || command kak $argv
end

function grel
    set ver (string trim -l -c v $argv[1])
    if [ -z "$ver" ]
      echo "Usage: $argv[0] <version> [git tag options...]"
      return 1
    end
    git tag -a v$ver -m "Release $ver" $argv[2..] && echo "Created tag v$ver"
end

function gitignore
    argparse -x f,l h/help f/file= l/local -- $argv
    or return

    if set -q _flag_help
        echo "Usage..."
        return 1
    end

    # set -l ignorefile ()
    # if set -q 
end

# whichpkg() (
#     set -e
#     file=$(which $1)
#     la "$file"
#     pacman -Qo "$file"
# )

alias mods 'OPENAI_API_KEY=(pass openai-api-key) command mods'

function y
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end

alias j just

alias l 'exa --group-directories-first -F'
alias ll 'l -lh --git'
alias la 'll -a'
alias llg 'll --grid'
alias st subterranean
