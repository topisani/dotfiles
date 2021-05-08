provide-module clip %{
  map -docstring 'System paste after' global user p '<a-!>clip -o<ret>'
  map -docstring 'System paste before' global user P '!clip -o<ret>'
  map -docstring 'System replace' global user R '|clip -o<ret>'
  map -docstring 'System yank' global user y '<a-|>clip<ret>'
}
