hook global WinSetOption filetype=vue %{
  require-module html
  addhl window/ ref html

  # set window lsp_config %{
  #   [language.vue.settings.volar.typescript]
  #   serverPath = 'node_modules/typescript/lib/tsserverlibrary.js'
  #   [language.vue.settings.volar.languageFeatures]
  #   semanticTokens = true
  #   references = true
  #   definition = true
  #   typeDefinition = true
  #   callHierarchy = true
  #   hover = true
  #   rename = true
  #   renameFileRefactoring = true
  #   signatureHelp = true
  #   codeAction = true
  #   completion = { defaultTagNameCase = 'both', defaultAttrNameCase = 'kebabCase' }
  #   schemaRequestService = true
  #   documentHighlight = true
  #   documentLink = true
  #   codeLens = true
  #   diagnostics = true

  #   [language.vue.settings.volar.documentFeatures]
  #   documentColor = false
  #   selectionRange = true
  #   foldingRange = true
  #   linkedEditingRange = true
  #   documentSymbol = true
  #   documentFormatting = { defaultPrintWidth = 100 }
  # }
  
  lsp-setup
  lsp-enable-semantic-tokens
}

hook global BufCreate .*[.](vue) %{
    set-option buffer filetype vue
}
