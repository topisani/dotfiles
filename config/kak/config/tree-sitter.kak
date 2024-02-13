eval %sh{ kak-tree-sitter -dks --session $kak_session }

# Default Behavior
define-command -override kak-tree-sitter-set-lang %{
  set-option buffer kts_lang %opt{filetype}
}

hook global BufSetOption 'kts_lang=git-diff' %{
  set buffer kts_lang diff
}

hook global -once WinDisplay ".*" %{
  kak-tree-sitter-highlight-submit-faces
}
