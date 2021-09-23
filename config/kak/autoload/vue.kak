hook global WinSetOption filetype=vue %{
  require-module html
  addhl window/ ref html
  addhl -override  shared/html/template_pug region '<template lang="pug">\K' '(?=</template>)' ref pug

  

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

  set window comment_line "//"
  set window comment_block_begin "/*"
  set window comment_block_end "*/"
  
  map global insert <c-e> "<esc>x: emmet<ret>"
}

hook global WinCreate .*[.](vue) %{
    set-option window filetype vue
}
