# base config for oh my zsh

source ~/.profile

if [[ ! -d ~/.zplug ]];then
    git clone https://github.com/b4b4r07/zplug ~/.zplug
fi
source ~/.zplug/init.zsh

zplug "plugins/git",   from:oh-my-zsh
zplug 'wfxr/forgit', defer:1
zplug "zsh-users/zsh-autosuggestions"
zplug "zsh-users/zsh-syntax-highlighting", defer:2
zplug "zsh-users/zsh-history-substring-search", defer:3

if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi

# Then, source plugins and add commands to $PATH
zplug load

bindkey "^[[A" history-search-backward
bindkey "^[[B" history-search-forward

export TMPDIR="/tmp"

# user-defined overrides
[ -d ~/.config/zsh/config.d/ ] && for file in ~/.config/zsh/config.d/*; do
    source "$file"
done

# Fix for foot terminfo not installed on most servers
alias ssh="TERM=xterm-256color ssh"

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
source <(kitty + complete setup zsh)
eval "$(thefuck -a tf)"
