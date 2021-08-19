# Enter replace mode
define-command enter-replace-mode -docstring 'Enter replace mode' %{
  # Replace while typing
  hook -group replace-mode window InsertChar '[^\n]' replace-mode-character-inserted
  hook -group replace-mode window InsertDelete '[^\n]' replace-mode-character-deleted

  # Leave replace mode
  hook -once window ModeChange 'pop:insert:.*' %{
    remove-hooks window replace-mode
  }

  # Enter insert mode
  execute-keys -with-hooks i
}

define-command -hidden replace-mode-character-inserted %{
  execute-keys '<del>'
}

define-command -hidden replace-mode-character-deleted %{
  execute-keys '<space><a-;>H'
}
