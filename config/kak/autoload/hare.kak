# Expand from the cursor position to capture the hare identifier at point
define-command -hidden select-hare-identifier %{ evaluate-commands %{
}}

# Display haredoc output for identifier at point
# TODO:
# - make this asynchronous
# - accomplish expansion + haredoc command w/o without interfering w/ user's
#   current selection
define-command haredoc -override %{
    evaluate-commands -draft %{
      try %{
        execute-keys '<a-i>c[^\w:_],[^\w:_]<ret>' 
      }
      evaluate-commands %sh{
          output=$(haredoc $kak_selection | cat)
          if [ -z "$output" ]; then
              printf "%s\n" "echo -debug no haredoc"
              exit 1
          else
              printf "%s\n" "info %{$output}"
          fi
      }
    }
}
