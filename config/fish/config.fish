set -g fish_greeting
if status is-interactive
    # Commands to run in interactive sessions can go here
    # 
    starship init fish | source
    zoxide init fish | source


    jj util completion fish | source
end

function k
    test -n $KAKOUNE_SESSION && krc attach $argv || command kak $argv
end

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
