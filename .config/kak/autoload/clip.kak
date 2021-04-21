provide-module clip %{
  # Copy
  hook global RegisterModified '"' %{
    execute-keys <a-|>clip<ret>
  }

  # Paste
  map -docstring 'Paste after' global user p '<a-!>clip -o<ret>'
  map -docstring 'Paste before' global user P '!clip -o<ret>'
  map -docstring 'Replace' global user R '|clip -o<ret>'
}
