command -v jira && eval $(jira completion zsh)
jira() {
  export JIRA_API_TOKEN=$(bitw get notes atlassian_api)
  export PAGER="less -r"
  command jira "$@"
}
