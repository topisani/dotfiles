
define-command janet-doc -override %{
    evaluate-commands %{
      execute-keys '<a-i>c[^\w:_-],[^\w:_-]<ret>'
      evaluate-commands %sh{
          # output is printed indented and with newlines before and after. Remove this using awk
          output=$(janet -e "(doc $kak_selection)" | awk '
            NF && !indent { nls=""; match($0, /^([ \t]*)/, m); indent=m[1] }
            NF {sub("^" indent, ""); print nls $0; nls=""; next }
            { nls=nls "\n"}')
          if [ -z "$output" ]; then
              printf "%s\n" "echo -debug no janet"
              exit 1
          else
              printf "%s\n" "info %{$output}"
          fi
      }
    }
}

# hook global BufSetOption filetype=janet %{
#     map buffer normal <c-h> :janet-doc<ret>
# }
