--
-- Built with,
--
--        ,gggg,
--       d8" "8I                         ,dPYb,
--       88  ,dP                         IP'`Yb
--    8888888P"                          I8  8I
--       88                              I8  8'
--       88        gg      gg    ,g,     I8 dPgg,
--  ,aa,_88        I8      8I   ,8'8,    I8dP" "8I
-- dP" "88P        I8,    ,8I  ,8'  Yb   I8P    I8
-- Yb,_,d88b,,_   ,d8b,  ,d8b,,8'_   8) ,d8     I8,
--  "Y8P"  "Y888888P'"Y88P"`Y8P' "YY8P8P88P     `Y8
--
-- Enable lush.ify on this file, run:
--
--  `:Lushify`
--
--  or
--
--  `:lua require('lush').ify()`

local lush = require("lush")
local hsl = lush.hsl

local colors = {
  none = "NONE",
  bg0 = hsl("#02030a"),
  bg = hsl("#000000"),
  bg1 = hsl("#1E1F21"),
  bg2 = hsl("#212126"),
  bg3 = hsl("#323037"),
  bg4 = hsl("#3c383c"),
  bg_float = hsl("#06070d"),

  fg0 = hsl("#ffffdf"),
  fg = hsl("#fdf4d1"),
  fg1 = hsl("#f4e8ca"),
  fg2 = hsl("#ebdbc2"),
  fg3 = hsl("#a89994"),

  gray = hsl("#565f6f"),
  red = hsl("#f24130"),
  red_dark = hsl("#d92817"),
  green = hsl("#71ba51"),
  green_dark = hsl("#4e773e"),
  yellow_light = hsl("#ffe000"),
  yellow = hsl("#f2bb13"),
  yellow_dark = hsl("#f39c12"),
  blue_light = hsl("#07b0ff"),
  blue = hsl("#178ca6"),
  blue_dark = hsl("#005973"),
  purple_light = hsl("#ff669a"),
  purple = hsl("#dd465a"),
  purple_dark = hsl("#8f3f71"),
  aqua = hsl("#67c5b4"),
  aqua_dark = hsl("#249991"),
  orange = hsl("#fe8019"),
  orange_dark = hsl("#de5019"),

  bluish_fg = hsl("#9EEEFF"),
}

colors.border = colors.blue_dark.mix(colors.bg, 30)
colors.bg_statusline = colors.bg_float

colors.gitSigns = {
  add = colors.green.mix(colors.bg, 20),
  change = colors.blue.mix(colors.bg, 20),
  delete = colors.red.mix(colors.bg, 20),
}

colors.diff = {
  add = colors.green.mix(colors.bg, 70),
  change = colors.blue.mix(colors.bg, 70),
  delete = colors.red.mix(colors.bg, 70),

  add_hl = colors.green.mix(colors.bg, 50),
  change_hl = colors.blue.mix(colors.bg, 50),
  delete_hl = colors.red.mix(colors.bg, 50),
}

colors.warning = colors.yellow
colors.error = colors.red
colors.info = colors.green
colors.comment = colors.gray

-- LSP/Linters mistakenly show `undefined global` errors in the spec, they may
-- support an annotation like the following. Consult your server documentation.
---@diagnostic disable: undefined-global
local theme = lush(function(injected_functions)
  local sym = injected_functions.sym
  local c = colors
  return {
    -- The following are the Neovim (as of 0.8.0-dev+100-g371dfb174) highlight
    -- groups, mostly used for styling UI elements.
    -- Comment them out and add your own properties to override the defaults.
    -- An empty definition `{}` will clear all styling, leaving elements looking
    -- like the 'Normal' group.
    -- To be able to link to a group, it must already be defined, so you may have
    -- to reorder items as you go.
    --
    -- See :h highlight-groups
    --
    -- ColorColumn  { }, -- Columns set with 'colorcolumn'
    Conceal({ fg = c.fg3 }), -- Placeholder characters substituted for concealed text (see 'conceallevel')
    Cursor({}), -- Character under the cursor
    -- lCursor      { }, -- Character under the cursor when |language-mapping| is used (see 'guicursor')
    -- CursorIM     { }, -- Like Cursor, but used when in IME mode |CursorIM|
    CursorColumn({ bg = c.bg1 }), -- Screen-column at the cursor, when 'cursorcolumn' is set.
    CursorLine({ bg = c.bg1 }), -- Screen-line at the cursor, when 'cursorline' is set. Low-priority if foreground (ctermfg OR guifg) is not set.
    Directory({ fg = c.blue, gui = "bold" }), -- Directory names (and other special names in listings)
    DiffAdd({ bg = c.diff.add }), -- Diff mode: Added line |diff.txt|
    DiffChange({ bg = c.diff.change }), -- Diff mode: Changed line |diff.txt|
    DiffDelete({ bg = c.diff.delete }), -- Diff mode: Deleted line |diff.txt|
    DiffText({ fg = c.diff.change_hl }), -- Diff mode: Changed text within a changed line |diff.txt|
    DiffAddText({ bg = c.diff.add_hl }),
    DiffDeleteText({ bg = c.diff.delete_hl }),
    EndOfBuffer({ fg = c.bg }), -- Filler lines (~) after the end of the buffer. By default, this is highlighted like |hl-NonText|.
    -- TermCursor   { }, -- Cursor in a focused terminal
    -- TermCursorNC { }, -- Cursor in an unfocused terminal
    ErrorMsg({ fg = c.red }), -- Error messages on the command line
    VertSplit({ fg = c.bg2 }), -- Column separating vertically split windows
    Folded({ fg = c.blue_dark, bg = colors.bg_float, gui = "italic" }), -- Line used for closed folds
    FoldColumn({ fg = c.blue_dark, gui = "italic" }), -- 'foldcolumn'
    SignColumn({}), -- Column where |signs| are displayed
    -- IncSearch    { }, -- 'incsearch' highlighting; also used for the text replaced with ":s///c"
    -- Substitute   { }, -- |:substitute| replacement text highlighting
    LineNr({ fg = c.bg4 }), -- Line number for ":number" and ":#" commands, and when 'number' or 'relativenumber' option is set.
    CursorLineNr({ fg = c.fg3, bg = c.bg1 }), -- Like LineNr when 'cursorline' or 'relativenumber' is set for the cursor line.
    MatchParen({ fg = c.purple, gui = "bold" }), -- Character under the cursor or just before it, if it is a paired bracket, and its match. |pi_paren.txt|
    ModeMsg({ fg = c.blue_dark, gui = "bold" }), -- 'showmode' message (e.g., "-- INSERT -- ")
    -- MsgArea      { }, -- Area for messages and cmdline
    -- MsgSeparator { }, -- Separator for scrolled messages, `msgsep` flag of 'display'
    -- MoreMsg      { }, -- |more-prompt|
    NonText({ fg = c.fg3 }), -- '@' at the end of the window, characters from 'showbreak' and other characters that do not really exist in the text (e.g., ">" displayed when a double-wide character doesn't fit at the end of the line). See also |hl-EndOfBuffer|.
    Normal({ bg = c.bg0, fg = c.fg }), -- Normal text
    NormalFloat({ bg = c.bg_float, fg = c.fg }), -- Normal text in floating windows.
    NormalNC({ bg = c.bg }), -- normal text in non-current windows
    Pmenu({ bg = c.bg2 }), -- Popup menu: Normal item.
    PmenuSel({ bg = c.blue }), -- Popup menu: Selected item.
    PmenuSbar({ bg = c.bg4 }), -- Popup menu: Scrollbar.
    PmenuThumb({ bg = c.blue }), -- Popup menu: Thumb of the scrollbar.
    Question({ fg = c.green_dark }), -- |hit-enter| prompt and yes/no questions
    -- QuickFixLine { }, -- Current |quickfix| item in the quickfix window. Combined with |hl-CursorLine| when the cursor is there.
    Search({ bg = c.bg3 }), -- Last search pattern highlighting (see 'hlsearch'). Also used for similar items that need to stand out.
    -- SpecialKey   { }, -- Unprintable characters: text displayed differently from what it really is. But not 'listchars' whitespace. |hl-Whitespace|
    -- SpellBad     { }, -- Word that is not recognized by the spellchecker. |spell| Combined with the highlighting used otherwise.
    -- SpellCap     { }, -- Word that should start with a capital. |spell| Combined with the highlighting used otherwise.
    -- SpellLocal   { }, -- Word that is recognized by the spellchecker as one that is used in another region. |spell| Combined with the highlighting used otherwise.
    -- SpellRare    { }, -- Word that is recognized by the spellchecker as one that is hardly ever used. |spell| Combined with the highlighting used otherwise.
    -- StatusLine   { }, -- Status line of current window
    -- StatusLineNC({}), -- Status lines of not-current windows. Note: If this is equal to "StatusLine" Vim will use "^^^" in the status line of the current window.
    TabLine({ fg = c.fg }), -- Tab pages line, not active tab page label
    TabLineFill({ fg = c.fg }), -- Tab pages line, where there are no labels
    TabLineSel({ fg = c.bg3, gui = "bold" }), -- Tab pages line, active tab page label
    Title({ fg = c.green, gui = "bold" }), -- Titles for output from ":set all", ":autocmd" etc.
    Visual({ bg = c.blue_dark.mix(c.bg, 40) }), -- Visual mode selection
    VisualNOS({ Visual }), -- Visual mode selection when vim is "Not Owning the Selection".
    WarningMsg({ fg = c.yellow }), -- Warning messages
    Whitespace({ fg = c.bg3 }), -- "nbsp", "space", "tab" and "trail" in 'listchars'
    Winseparator({ VertSplit }), -- Separator between window splits. Inherts from |hl-VertSplit| by default, which it will replace eventually.
    -- WildMenu     { }, -- Current match in 'wildmenu' completion

    -- Common vim syntax groups used for all kinds of code and markup.
    -- Commented-out groups should chain up to their preferred (*) group
    -- by default.
    --
    -- See :h group-name
    --
    -- Uncomment and edit if you want more specific syntax highlighting.

    Comment({ fg = c.gray, gui = "italic" }), -- Any comment

    Constant({ fg = c.aqua_dark }), -- (*) Any constant
    String({ fg = c.green }), --   A string constant: "this is a string"
    -- Character      { }, --   A character constant: 'c', '\n'
    Number({ fg = c.purple_dark }), --   A number constant: 234, 0xff
    Boolean({ fg = c.purple_dark }), --   A boolean constant: TRUE, false
    Float({ fg = c.purple_dark }), --   A floating point constant: 2.3e10

    Identifier({ fg = c.aqua_dark }), -- (*) Any variable name
    Function({ fg = c.yellow_light }), --   Function name (also: methods for classes)

    Statement({ fg = c.red }), -- (*) Any statement
    -- Conditional    { }, --   if, then, else, endif, switch, etc.
    -- Repeat         { }, --   for, do, while, etc.
    -- Label          { }, --   case, default, etc.
    Operator({}), --   "sizeof", "+", "*", etc.
    Keyword({ fg = c.red }), --   any other keyword
    -- Exception      { }, --   try, catch, throw

    PreProc({ fg = c.orange }), -- (*) Generic Preprocessor
    -- Include        { }, --   Preprocessor #include
    -- Define         { }, --   Preprocessor #define
    Macro({ fg = c.purple }), --   Same as Define
    -- PreCondit      { }, --   Preprocessor #if, #else, #endif, etc.

    Type({ fg = c.blue_light }), -- (*) int, long, char, etc.
    StorageClass({ Keyword }), --   static, register, volatile, etc.
    -- Structure      { }, --   struct, union, enum, etc.
    -- Typedef        { }, --   A typedef

    Special({ fg = c.blue_dark }), -- (*) Any special symbol
    SpecialChar({ fg = c.gray }), --   Special character in a constant
    -- Tag            { }, --   You can use CTRL-] on this
    Delimiter({ fg = c.blue }), --   Character that needs attention
    -- SpecialComment { }, --   Special things inside a comment (e.g. '\n')
    -- Debug          { }, --   Debugging statements

    Underlined({ gui = "underline" }), -- Text that stands out, HTML links
    Bold({ gui = "bold" }),
    Italic({ gui = "italic" }),
    Ignore({}), -- Left blank, hidden |hl-Ignore| (NOTE: May be invisible here in template)
    Error({ fg = c.red }), -- Any erroneous construct
    Todo({ fg = c.orange }), -- Anything that needs extra attention; TODO: mostly the keywords TODO FIXME and XXX

    -- These groups are for the native LSP client and diagnostic system. Some
    -- other LSP clients may use these groups, or use their own. Consult your
    -- LSP client's documentation.

    -- See :h lsp-highlight, some groups may not be listed, submit a PR fix to lush-template!
    --
    LspReferenceText({ gui = "bold" }), -- Used for highlighting "text" references
    LspReferenceRead({ gui = "bold" }), -- Used for highlighting "read" references
    LspReferenceWrite({ gui = "bold,underscore" }), -- Used for highlighting "write" references
    LspCodeLens({ fg = c.gray }), -- Used to color the virtual text of the codelens. See |nvim_buf_set_extmark()|.
    -- LspCodeLensSeparator        { } , -- Used to color the seperator between two or more code lens.
    LspSignatureActiveParameter({ gui = "bold" }), -- Used to highlight the active parameter in the signature help. See |vim.lsp.handlers.signature_help()|.

    -- See :h diagnostic-highlights, some groups may not be listed, submit a PR fix to lush-template!
    --
    DiagnosticError({ fg = c.red }), -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    DiagnosticWarn({ fg = c.yellow }), -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    DiagnosticInfo({ fg = c.green }), -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    DiagnosticHint({ fg = c.aqua_dark }), -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    DiagnosticVirtualTextError({ fg = DiagnosticError.fg, bg = DiagnosticError.fg.mix(c.bg, 80) }), -- Used for "Error" diagnostic virtual text.
    DiagnosticVirtualTextWarn({ fg = DiagnosticWarn.fg, bg = DiagnosticWarn.fg.mix(c.bg, 80) }), -- Used for "Warn" diagnostic virtual text.
    DiagnosticVirtualTextInfo({ fg = DiagnosticInfo.fg, bg = DiagnosticInfo.fg.mix(c.bg, 80) }), -- Used for "Error" diagnostic virtual text.
    DiagnosticVirtualTextHint({ fg = DiagnosticHint.fg, bg = DiagnosticHint.fg.mix(c.bg, 80) }), -- Used for "Error" diagnostic virtual text.
    DiagnosticUnderlineError({ gui = "undercurl", sp = DiagnosticError.fg }), -- Used to underline "Error" diagnostics.
    DiagnosticUnderlineWarn({ gui = "undercurl", sp = DiagnosticWarn.fg }), -- Used to underline "Warn" diagnostics.
    DiagnosticUnderlineInfo({ gui = "undercurl", sp = DiagnosticInfo.fg }), -- Used to underline "Info" diagnostics.
    DiagnosticUnderlineHint({ gui = "undercurl", sp = DiagnosticHing.fg }), -- Used to underline "Hint" diagnostics.
    -- DiagnosticFloatingError    { } , -- Used to color "Error" diagnostic messages in diagnostics float. See |vim.diagnostic.open_float()|
    -- DiagnosticFloatingWarn     { } , -- Used to color "Warn" diagnostic messages in diagnostics float.
    -- DiagnosticFloatingInfo     { } , -- Used to color "Info" diagnostic messages in diagnostics float.
    -- DiagnosticFloatingHint     { } , -- Used to color "Hint" diagnostic messages in diagnostics float.
    -- DiagnosticSignError        { } , -- Used for "Error" signs in sign column.
    -- DiagnosticSignWarn         { } , -- Used for "Warn" signs in sign column.
    -- DiagnosticSignInfo         { } , -- Used for "Info" signs in sign column.
    -- DiagnosticSignHint         { } , -- Used for "Hint" signs in sign column.

    -- Tree-Sitter syntax groups.
    --
    -- See :h treesitter-highlight-groups, some groups may not be listed,
    -- submit a PR fix to lush-template!
    --
    -- Tree-Sitter groups are defined with an "@" symbol, which must be
    -- specially handled to be valid lua code, we do this via the special
    -- sym function. The following are all valid ways to call the sym function,
    -- for more details see https://www.lua.org/pil/5.html
    --
    -- sym("@text.literal")
    -- sym('@text.literal')
    -- sym"@text.literal"
    -- sym'@text.literal'
    --
    -- For more information see https://github.com/rktjmp/lush.nvim/issues/109

    -- sym"@text.literal"      { }, -- Comment
    -- sym"@text.reference"    { }, -- Identifier
    -- sym"@text.title"        { }, -- Title
    -- sym"@text.uri"          { }, -- Underlined
    -- sym"@text.underline"    { }, -- Underlined
    -- sym"@text.todo"         { }, -- Todo
    -- sym"@comment"           { }, -- Comment
    sym("@punctuation")({}), -- Delimiter
    -- sym"@constant"          { }, -- Constant
    -- sym"@constant.builtin"  { }, -- Special
    -- sym"@constant.macro"    { }, -- Define
    -- sym"@define"            { }, -- Define
    -- sym"@macro"             { }, -- Macro
    -- sym"@string"            { }, -- String
    -- sym"@string.escape"     { }, -- SpecialChar
    -- sym"@string.special"    { }, -- SpecialChar
    -- sym"@character"         { }, -- Character
    -- sym"@character.special" { }, -- SpecialChar
    -- sym"@number"            { }, -- Number
    -- sym"@boolean"           { }, -- Boolean
    -- sym"@float"             { }, -- Float
    -- sym"@function"          { }, -- Function
    -- sym"@function.builtin"  { }, -- Special
    -- sym"@function.macro"    { }, -- Macro
    -- sym"@parameter"         { }, -- Identifier
    -- sym"@method"            { }, -- Function
    -- sym"@field"             { }, -- Identifier
    -- sym"@property"          { }, -- Identifier
    -- sym"@constructor"       { }, -- Special
    sym("@conditional.ternary")({ Normal }), -- Conditional
    -- sym"@repeat"            { }, -- Repeat
    -- sym"@label"             { }, -- Label
    -- sym"@operator"          { }, -- Operator
    -- sym"@keyword"           { }, -- Keyword
    -- sym"@exception"         { }, -- Exception
    -- sym"@variable"          { }, -- Identifier
    -- sym"@type"              { }, -- Type
    -- sym"@type.definition"   { }, -- Typedef
    sym("@storageclass")({ StorageClass }), -- StorageClass
    sym("@type.qualifier")({ Keyword }),
    -- sym"@structure"         { }, -- Structure
    sym("@namespace")({ fg = c.orange }), -- Identifier
    -- sym("@include")({ Include }), -- Include
    -- sym"@preproc"           { }, -- PreProc
    -- sym"@debug"             { }, -- Debug
    -- sym"@tag"               { }, -- Tag
    sym("@attribute")({ fg = c.gray }),
    sym("@classScope")({ gui = "italic" }),
    sym("@trait")({ gui = "italic" }),
    sym("@concept")({ gui = "italic" }),
    sym("@documentation")({ fg = c.green, gui = "noitalic" }),

    -- Telescope
    TelescopeBorder({ fg = colors.border, bg = c.bg_float }),
    TelescopeNormal({ fg = c.fg, bg = c.bg_float }),

    -- Leap
    LeapMatch({ bg = c.purple, fg = c.bg }),
    LeapLabelPrimary({ fg = c.purple, bold = true }),
    LeapLabelSecondary({ fg = c.green, bold = true }),
    LeapBackdrop({ fg = c.blue_dark }),

    -- Alpha
    AlphaShortcut({ fg = c.orange }),
    AlphaHeader({ fg = c.blue }),
    AlphaHeaderLabel({ fg = c.orange }),
    AlphaFooter({ fg = c.yellow, italic = true }),
    AlphaButtons({ fg = c.aqua }),

    -- WhichKey
    WhichKey({ fg = c.aqua }),
    WhichKeyGroup({ fg = c.blue }),
    WhichKeyDesc({ fg = c.purple_dark }),
    WhichKeySeperator({ fg = c.gray }),
    WhichKeySeparator({ fg = c.gray }),
    WhichKeyFloat({ bg = c.bg_float }),
    WhichKeyValue({ fg = c.fg }),

    -- Navic
    NavicIconsFile({ fg = c.fg, bg = c.none }),
    NavicIconsModule({ fg = c.yellow, bg = c.none }),
    NavicIconsNamespace({ fg = c.fg, bg = c.none }),
    NavicIconsPackage({ fg = c.fg, bg = c.none }),
    NavicIconsClass({ fg = c.orange, bg = c.none }),
    NavicIconsMethod({ fg = c.blue, bg = c.none }),
    NavicIconsProperty({ fg = c.green, bg = c.none }),
    NavicIconsField({ fg = c.green, bg = c.none }),
    NavicIconsConstructor({ fg = c.orange, bg = c.none }),
    NavicIconsEnum({ fg = c.orange, bg = c.none }),
    NavicIconsInterface({ fg = c.orange, bg = c.none }),
    NavicIconsFunction({ fg = c.blue, bg = c.none }),
    NavicIconsVariable({ fg = c.purple, bg = c.none }),
    NavicIconsConstant({ fg = c.purple, bg = c.none }),
    NavicIconsString({ fg = c.green, bg = c.none }),
    NavicIconsNumber({ fg = c.orange, bg = c.none }),
    NavicIconsBoolean({ fg = c.orange, bg = c.none }),
    NavicIconsArray({ fg = c.orange, bg = c.none }),
    NavicIconsObject({ fg = c.orange, bg = c.none }),
    NavicIconsKey({ fg = c.purple, bg = c.none }),
    NavicIconsKeyword({ fg = c.purple, bg = c.none }),
    NavicIconsNull({ fg = c.orange, bg = c.none }),
    NavicIconsEnumMember({ fg = c.green, bg = c.none }),
    NavicIconsStruct({ fg = c.orange, bg = c.none }),
    NavicIconsEvent({ fg = c.orange, bg = c.none }),
    NavicIconsOperator({ fg = c.fg, bg = c.none }),
    NavicIconsTypeParameter({ fg = c.green, bg = c.none }),
    NavicText({ fg = c.fg3, bg = c.none }),
    NavicSeparator({ fg = c.fg3, bg = c.none }),

    -- Cmp
    CmpDocumentation({ fg = c.fg, bg = c.bg_float }),
    CmpDocumentationBorder({ fg = c.border, bg = c.bg_float }),

    -- GitSigns
    GitSignsAdd({ fg = c.gitSigns.add }), -- diff mode: Added line |diff.txt|
    GitSignsChange({ fg = c.gitSigns.change }), -- diff mode: Changed line |diff.txt|
    GitSignsDelete({ fg = c.gitSigns.delete }), -- diff mode: Deleted line |diff.txt|

    -- Neogit
    NeogitBranch({ fg = c.purple_light }),
    NeogitRemote({ fg = c.purple }),
    NeogitHunkHeader({ bg = c.bg1, fg = c.fg }),
    NeogitHunkHeaderHighlight({ bg = c.bg1, fg = c.blue }),
    NeogitDiffContextHighlight({ bg = c.fg2.mix(c.bg, 50), fg = c.bg1 }),
    NeogitDiffDeleteHighlight({ bg = c.diff.delete }),
    NeogitDiffAddHighlight({ bg = c.diff.add }),

    -- Mini
    MiniTablineCurrent({ fg = c.fg, bg = c.bg1 }),
    MiniTablineFill({ bg = c.black }),
    MiniTablineHidden({ fg = c.dark5, bg = c.bg_statusline }),
    MiniTablineModifiedCurrent({ fg = c.warning, bg = c.bg3 }),
    MiniTablineModifiedHidden({ bg = c.bg_statusline, fg = c.warning.mix(c.bg, 70) }),
    MiniTablineModifiedVisible({ fg = c.warning, bg = c.bg_statusline }),
    MiniTablineTabpagesection({ bg = c.bg_statusline, fg = c.none }),
    MiniTablineVisible({ fg = c.fg, bg = c.bg_statusline }),
  }
end)

-- Return our parsed theme for extension or use elsewhere.
return theme

-- vi:nowrap
