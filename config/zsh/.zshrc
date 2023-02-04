# base config for oh my zsh

if [[ ! -d ~/.zplug ]];then
    git clone https://github.com/b4b4r07/zplug ~/.zplug
fi
source ~/.zplug/init.zsh

iscmd() {
    command -v $1 > /dev/null
}

export FORGIT_COPY_CMD=clip

zplug "plugins/git",   from:oh-my-zsh
zplug 'wfxr/forgit', defer:1
zplug "zsh-users/zsh-autosuggestions"
zplug "zsh-users/zsh-syntax-highlighting", defer:2

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

export SSH_AUTH_SOCK=/tmp/ssh-agent.$HOST.sock
ssh-add -l 2>/dev/null >/dev/null
if [ $? -ge 2 ]; then
  ssh-agent -a "$SSH_AUTH_SOCK" >/dev/null
fi

alias ssh="TERM=xterm-256color ssh"

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
iscmd kubectl && source <(kubectl completion zsh)
