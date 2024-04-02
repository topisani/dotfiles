eval %sh{ kak-tree-sitter -dks --session $kak_session --with-highlighting --with-text-objects }

# Default Behavior
define-command -override kak-tree-sitter-set-lang %{
  set-option buffer kts_lang %opt{filetype}
}

define-command kts-map-ft-lang -params 2 %{
  hook global BufSetOption "kts_lang=%arg{1}" %exp{
    set buffer kts_lang %arg{2}
  }
}

kts-map-ft-lang git-diff diff
kts-map-ft-lang justfile just
kts-map-ft-lang typescript tsx

kak-tree-sitter-enable-highlighting
