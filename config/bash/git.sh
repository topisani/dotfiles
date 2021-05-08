# Git
alias g='git'
alias gst='git status'
#alias gd='git diff'
alias gdc='git diff --cached'
alias gl='git pull'
alias gup='git pull --rebase'
alias gp='git push'
alias gd='git diff'
# Provides ga, glo, gd, grh, gcf, gcb, gco, gss, gclean, grb, gfu
FORGIT_COPY_CMD='clip'
source ~/src/forgit/forgit.plugin.sh

alias gc='git commit -v'
alias gc!='git commit -v --amend'
alias gca='git commit -v -a'
alias gca!='git commit -v -a --amend'
alias gcmsg='git commit -m'
#alias gco='git checkout'
alias gcm='git checkout master'
alias gr='git remote'
alias grv='git remote -v'
alias grmv='git remote rename'
alias grrm='git remote remove'
alias grset='git remote set-url'
alias grup='git remote update'
alias grbi='git rebase -i'
alias grbc='git rebase --continue'
alias grba='git rebase --abort'
alias gb='git branch'
alias gba='git branch -a'
alias gcount='git shortlog -sn'
alias gcl='git config --list'
alias gcp='git cherry-pick'
alias glg='git log --stat --max-count=10'
alias glgg='git log --graph --max-count=10'
alias glgga='git log --graph --decorate --all'
#alias glo='git log --oneline'
#alias gss='git status -s'
#alias ga='git add'
alias gm='git merge'
#alias grh='git reset HEAD'
alias grhh='git reset HEAD --hard'
#alias gclean='git reset --hard; and git clean -dfx'
alias gwc='git whatchanged -p --abbrev-commit --pretty=medium'

#remove the gf alias
#alias gf='git ls-files | grep'

alias gpoat='git push origin --all && git push origin --tags'
alias gmt='git mergetool --no-prompt'

alias gg='gitui'

alias gsts='git stash show --text'
alias gsta='git stash'
alias gstp='git stash pop'
alias gstd='git stash drop'

# Will cd into the top of the current repository
# or submodule.
alias grt='cd $(git rev-parse --show-toplevel || echo ".")'
#
# Will return the current branch name
# Usage example: git pull origin $(current_branch)
#
current_branch() {
  ref=$(git symbolic-ref HEAD 2> /dev/null) || \
  ref=$(git rev-parse --short HEAD 2> /dev/null) || return
  echo $ref | sed 's|refs/heads/||'
}

current_repository() {
  ref=$(git symbolic-ref HEAD 2> /dev/null) || \
  ref=$(git rev-parse --short HEAD 2> /dev/null) || return
  echo $(git remote -v | cut -d':' -f 2)
}

# these aliases take advantage of the previous function
alias ggpull='git pull origin (current_branch)'
alias ggpur='git pull --rebase origin (current_branch)'
alias ggpush='git push origin (current_branch)'
alias ggpnp='git pull origin (current_branch); and git push origin (current_branch)'

# Pretty log messages
_git_log_prettily() {
  if ! [ -z $1 ]; then
    git log --pretty=$1
  fi
}

alias glp="_git_log_prettily"

# Work In Progress (wip)
# These features allow to pause a branch development and switch to another one (wip)
# When you want to go back to work, just unwip it
#
# This return a warning if the current branch is a wip() {
work_in_progress() {
  if git log -n 1 | grep -q -c [WIP]; then
    echo "WIP!!"
  fi
}

# these alias commit and uncomit wip branches
gwip() {
  git add -A
  git ls-files --deleted -z | xargs -r0 git rm
  git commit -m "[WIP] $@"
}
alias gunwip='git log -n 1 | grep -q -c [WIP] && git reset HEAD~1'

