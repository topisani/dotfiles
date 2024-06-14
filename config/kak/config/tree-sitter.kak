eval %sh{ kak-tree-sitter -dks --init $kak_session --with-highlighting --with-text-objects }

define-command kts-map-ft-lang -params 2 %{
  hook global BufSetOption "tree_sitter_lang=%arg{1}" %exp{
    set buffer tree_sitter_lang %arg{2}
  }
}

kts-map-ft-lang git-diff diff
kts-map-ft-lang justfile just
kts-map-ft-lang typescript tsx
kts-map-ft-lang c cpp
