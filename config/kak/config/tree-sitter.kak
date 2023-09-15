eval %sh{ kak-tree-sitter -dks --session $kak_session }

# Default Behavior
define-command -override kak-tree-sitter-set-lang %{
  set-option buffer kts_lang %opt{filetype}
}

