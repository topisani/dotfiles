-- Pull in the wezterm API
local wezterm = require 'wezterm'
local act = wezterm.action

-- This will hold the configuration.
local config = wezterm.config_builder()

config.font = wezterm.font 'Jetbrains Mono Nerd Font'
config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }
config.freetype_load_target = 'Light'
config.freetype_render_target = 'HorizontalLcd'
config.cell_width = 0.9
-- config.font = wezterm.font 'Iosevka Nerd Font'
config.font_size = 9
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.enable_csi_u_key_encoding = true
config.enable_kitty_keyboard = false
config.underline_thickness = "250%"
config.underline_position = -3
-- config.term = "wezterm"

config.front_end = 'OpenGL'
-- config.webgpu_power_preference = 'HighPerformance'
-- This is where you actually apply your config choices

config.disable_default_key_bindings = true

config.hyperlink_rules = wezterm.default_hyperlink_rules()

local autosplit_action = wezterm.action_callback(function(win, pane)
    local cols = pane:get_dimensions().cols
    local rows = pane:get_dimensions().viewport_rows

    local dir = "Right"

    if (rows * 5) > (cols * 2) then
        dir = "Bottom"
    end

    local new_pane = pane:split { direction = dir }
end)

-- config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 5000 }
config.keys = {
    { key = 'F11', action = act.ToggleFullScreen },
    { key = '=', mods = 'CTRL', action = act.IncreaseFontSize },
    { key = '=', mods = 'SHIFT|CTRL', action = act.IncreaseFontSize },
    { key = '_', mods = 'CTRL', action = act.DecreaseFontSize },
    { key = '_', mods = 'SHIFT|CTRL', action = act.DecreaseFontSize },
    { key = '0', mods = 'CTRL', action = act.ResetFontSize },
    { key = 'C', mods = 'SHIFT|CTRL', action = act.CopyTo 'Clipboard' },
    { key = 'V', mods = 'SHIFT|CTRL', action = act.PasteFrom 'Clipboard' },
    { key = 'Insert', mods = 'SHIFT', action = act.PasteFrom 'PrimarySelection' },
    { key = 'Insert', mods = 'CTRL', action = act.CopyTo 'PrimarySelection' },
    { key = 'Copy', mods = 'NONE', action = act.CopyTo 'Clipboard' },
    { key = 'Paste', mods = 'NONE', action = act.PasteFrom 'Clipboard' },
    { key = 'Space', mods = 'CTRL', action = act.ActivateKeyTable { name = 'leader', one_shot = true, timeout_milliseconds = 1000 }},
    { key = 'Space', mods = 'CTRL|SHIFT', action = act.ActivateKeyTable { name = 'leader', one_shot = true, timeout_milliseconds = 1000 }},
}

config.key_tables = {
  leader = {
    { key = 'Tab', mods = 'NONE', action = act.ActivateTabRelative(1) },
    { key = 'Tab', mods = 'SHIFT', action = act.ActivateTabRelative(-1) },
    { key = '1', mods = 'NONE', action = act.ActivateTab(0) },
    { key = '2', mods = 'NONE', action = act.ActivateTab(1) },
    { key = '3', mods = 'NONE', action = act.ActivateTab(2) },
    { key = '4', mods = 'NONE', action = act.ActivateTab(3) },
    { key = '5', mods = 'NONE', action = act.ActivateTab(4) },
    { key = '6', mods = 'NONE', action = act.ActivateTab(5) },
    { key = '7', mods = 'NONE', action = act.ActivateTab(6) },
    { key = '8', mods = 'NONE', action = act.ActivateTab(7) },
    { key = '9', mods = 'NONE', action = act.ActivateTab(8) },
    { key = '0', mods = 'NONE', action = act.ActivateTab(9) },
    { key = 'd', mods = 'NONE', action = act.ShowDebugOverlay },
    { key = 's', mods = 'NONE', action = act.SplitVertical{ domain =  'CurrentPaneDomain' } },
    { key = 'v', mods = 'NONE', action = act.SplitHorizontal{ domain =  'CurrentPaneDomain' } },
    { key = 'z', mods = 'NONE', action = act.TogglePaneZoomState },
    { key = 'x', mods = 'NONE', action = act.ActivateCopyMode },
    { key = '/', mods = 'NONE', action = act.Search 'CurrentSelectionOrEmptyString' },
    { key = 'u', mods = 'NONE', action = act.CharSelect{ copy_on_select = true, copy_to =  'ClipboardAndPrimarySelection' } },
    -- { key = 'K', mods = 'NONE', action = act.ClearScrollback 'ScrollbackOnly' },
    { key = 'm', mods = 'NONE', action = act.Hide },
    { key = 'n', mods = 'NONE', action = act.SpawnWindow },
    { key = 'Space', mods = 'NONE', action = act.ActivateCommandPalette },
    { key = 'r', mods = 'NONE', action = act.ReloadConfiguration },
    { key = 't', mods = 'NONE', action = act.SpawnTab 'CurrentPaneDomain' },
    { key = 'q', mods = 'NONE', action = act.CloseCurrentTab{ confirm = true } },
    { key = 'f', mods = 'NONE', action = act.QuickSelect },
    -- { key = 'PageUp', mods = 'NONE', action = act.ScrollByPage(-1) },
    { key = 'PageUp', mods = 'NONE', action = act.ActivateTabRelative(-1) },
    { key = 'PageUp', mods = 'SHIFT', action = act.MoveTabRelative(-1) },
    -- { key = 'PageDown', mods = 'NONE', action = act.ScrollByPage(1) },
    { key = 'PageDown', mods = 'NONE', action = act.ActivateTabRelative(1) },
    { key = 'PageDown', mods = 'SHIFT', action = act.MoveTabRelative(1) },
    { key = 'LeftArrow', mods = 'NONE', action = act.ActivatePaneDirection 'Left' },
    { key = 'RightArrow', mods = 'NONE', action = act.ActivatePaneDirection 'Right' },
    { key = 'UpArrow', mods = 'NONE', action = act.ActivatePaneDirection 'Up' },
    { key = 'DownArrow', mods = 'NONE', action = act.ActivatePaneDirection 'Down' },
    { key = 'LeftArrow', mods = 'CTRL', action = act.AdjustPaneSize{ 'Left', 20 } },
    { key = 'RightArrow', mods = 'CTRL', action = act.AdjustPaneSize{ 'Right', 20 } },
    { key = 'UpArrow', mods = 'CTRL', action = act.AdjustPaneSize{ 'Up', 20 } },
    { key = 'DownArrow', mods = 'CTRL', action = act.AdjustPaneSize{ 'Down', 20 } },
    { key = 'LeftArrow', mods = 'SHIFT|CTRL', action = act.AdjustPaneSize{ 'Left', 5 } },
    { key = 'RightArrow', mods = 'SHIFT|CTRL', action = act.AdjustPaneSize{ 'Right', 5 } },
    { key = 'UpArrow', mods = 'SHIFT|CTRL', action = act.AdjustPaneSize{ 'Up', 5 } },
    { key = 'DownArrow', mods = 'SHIFT|CTRL', action = act.AdjustPaneSize{ 'Down', 5 } },
    { key = 'h', mods = 'NONE', action = act.ActivatePaneDirection 'Left' },
    { key = 'l', mods = 'NONE', action = act.ActivatePaneDirection 'Right' },
    { key = 'k', mods = 'NONE', action = act.ActivatePaneDirection 'Up' },
    { key = 'j', mods = 'NONE', action = act.ActivatePaneDirection 'Down' },
    { key = 'h', mods = 'CTRL', action = act.AdjustPaneSize{ 'Left', 20 } },
    { key = 'l', mods = 'CTRL', action = act.AdjustPaneSize{ 'Right', 20 } },
    { key = 'k', mods = 'CTRL', action = act.AdjustPaneSize{ 'Up', 20 } },
    { key = 'j', mods = 'CTRL', action = act.AdjustPaneSize{ 'Down', 20 } },
    { key = 'H', mods = 'SHIFT|CTRL', action = act.AdjustPaneSize{ 'Left', 5 } },
    { key = 'L', mods = 'SHIFT|CTRL', action = act.AdjustPaneSize{ 'Right', 5 } },
    { key = 'K', mods = 'SHIFT|CTRL', action = act.AdjustPaneSize{ 'Up', 5 } },
    { key = 'J', mods = 'SHIFT|CTRL', action = act.AdjustPaneSize{ 'Down', 5 } },
    { key = 'Enter', mods = 'NONE', action = autosplit_action },
  },
  copy_mode = {
    { key = 'Tab', mods = 'NONE', action = act.CopyMode 'MoveForwardWord' },
    { key = 'Tab', mods = 'SHIFT', action = act.CopyMode 'MoveBackwardWord' },
    { key = 'Enter', mods = 'NONE', action = act.CopyMode 'MoveToStartOfNextLine' },
    { key = 'Escape', mods = 'NONE', action = act.Multiple{ 'ScrollToBottom', { CopyMode =  'Close' } } },
    { key = 'Space', mods = 'NONE', action = act.CopyMode{ SetSelectionMode =  'Cell' } },
    { key = '$', mods = 'NONE', action = act.CopyMode 'MoveToEndOfLineContent' },
    { key = '$', mods = 'SHIFT', action = act.CopyMode 'MoveToEndOfLineContent' },
    { key = ',', mods = 'NONE', action = act.CopyMode 'JumpReverse' },
    { key = '0', mods = 'NONE', action = act.CopyMode 'MoveToStartOfLine' },
    { key = ';', mods = 'NONE', action = act.CopyMode 'JumpAgain' },
    { key = 'F', mods = 'NONE', action = act.CopyMode{ JumpBackward = { prev_char = false } } },
    { key = 'F', mods = 'SHIFT', action = act.CopyMode{ JumpBackward = { prev_char = false } } },
    { key = 'G', mods = 'NONE', action = act.CopyMode 'MoveToScrollbackBottom' },
    { key = 'G', mods = 'SHIFT', action = act.CopyMode 'MoveToScrollbackBottom' },
    { key = 'H', mods = 'NONE', action = act.CopyMode 'MoveToViewportTop' },
    { key = 'H', mods = 'SHIFT', action = act.CopyMode 'MoveToViewportTop' },
    { key = 'L', mods = 'NONE', action = act.CopyMode 'MoveToViewportBottom' },
    { key = 'L', mods = 'SHIFT', action = act.CopyMode 'MoveToViewportBottom' },
    { key = 'M', mods = 'NONE', action = act.CopyMode 'MoveToViewportMiddle' },
    { key = 'M', mods = 'SHIFT', action = act.CopyMode 'MoveToViewportMiddle' },
    { key = 'O', mods = 'NONE', action = act.CopyMode 'MoveToSelectionOtherEndHoriz' },
    { key = 'O', mods = 'SHIFT', action = act.CopyMode 'MoveToSelectionOtherEndHoriz' },
    { key = 'T', mods = 'NONE', action = act.CopyMode{ JumpBackward = { prev_char = true } } },
    { key = 'T', mods = 'SHIFT', action = act.CopyMode{ JumpBackward = { prev_char = true } } },
    { key = 'V', mods = 'NONE', action = act.CopyMode{ SetSelectionMode =  'Line' } },
    { key = 'V', mods = 'SHIFT', action = act.CopyMode{ SetSelectionMode =  'Line' } },
    { key = '^', mods = 'NONE', action = act.CopyMode 'MoveToStartOfLineContent' },
    { key = '^', mods = 'SHIFT', action = act.CopyMode 'MoveToStartOfLineContent' },
    { key = 'b', mods = 'NONE', action = act.CopyMode 'MoveBackwardWord' },
    { key = 'b', mods = 'ALT', action = act.CopyMode 'MoveBackwardWord' },
    { key = 'b', mods = 'CTRL', action = act.CopyMode 'PageUp' },
    { key = 'c', mods = 'CTRL', action = act.Multiple{ 'ScrollToBottom', { CopyMode =  'Close' } } },
    { key = 'd', mods = 'CTRL', action = act.CopyMode{ MoveByPage = (0.5) } },
    { key = 'e', mods = 'NONE', action = act.CopyMode 'MoveForwardWordEnd' },
    { key = 'f', mods = 'NONE', action = act.CopyMode{ JumpForward = { prev_char = false } } },
    { key = 'f', mods = 'ALT', action = act.CopyMode 'MoveForwardWord' },
    { key = 'f', mods = 'CTRL', action = act.CopyMode 'PageDown' },
    { key = 'g', mods = 'NONE', action = act.CopyMode 'MoveToScrollbackTop' },
    { key = 'g', mods = 'CTRL', action = act.Multiple{ 'ScrollToBottom', { CopyMode =  'Close' } } },
    { key = 'h', mods = 'NONE', action = act.CopyMode 'MoveLeft' },
    { key = 'j', mods = 'NONE', action = act.CopyMode 'MoveDown' },
    { key = 'k', mods = 'NONE', action = act.CopyMode 'MoveUp' },
    { key = 'l', mods = 'NONE', action = act.CopyMode 'MoveRight' },
    { key = 'm', mods = 'ALT', action = act.CopyMode 'MoveToStartOfLineContent' },
    { key = 'o', mods = 'NONE', action = act.CopyMode 'MoveToSelectionOtherEnd' },
    { key = 'q', mods = 'NONE', action = act.Multiple{ 'ScrollToBottom', { CopyMode =  'Close' } } },
    { key = 't', mods = 'NONE', action = act.CopyMode{ JumpForward = { prev_char = true } } },
    { key = 'u', mods = 'CTRL', action = act.CopyMode{ MoveByPage = (-0.5) } },
    { key = 'v', mods = 'NONE', action = act.CopyMode{ SetSelectionMode =  'Cell' } },
    { key = 'v', mods = 'CTRL', action = act.CopyMode{ SetSelectionMode =  'Block' } },
    { key = 'w', mods = 'NONE', action = act.CopyMode 'MoveForwardWord' },
    { key = 'y', mods = 'NONE', action = act.Multiple{ { CopyTo =  'ClipboardAndPrimarySelection' }, { Multiple = { 'ScrollToBottom', { CopyMode =  'Close' } } } } },
    { key = 'PageUp', mods = 'NONE', action = act.CopyMode 'PageUp' },
    { key = 'PageDown', mods = 'NONE', action = act.CopyMode 'PageDown' },
    { key = 'End', mods = 'NONE', action = act.CopyMode 'MoveToEndOfLineContent' },
    { key = 'Home', mods = 'NONE', action = act.CopyMode 'MoveToStartOfLine' },
    { key = 'LeftArrow', mods = 'NONE', action = act.CopyMode 'MoveLeft' },
    { key = 'LeftArrow', mods = 'ALT', action = act.CopyMode 'MoveBackwardWord' },
    { key = 'RightArrow', mods = 'NONE', action = act.CopyMode 'MoveRight' },
    { key = 'RightArrow', mods = 'ALT', action = act.CopyMode 'MoveForwardWord' },
    { key = 'UpArrow', mods = 'NONE', action = act.CopyMode 'MoveUp' },
    { key = 'DownArrow', mods = 'NONE', action = act.CopyMode 'MoveDown' },
  },

  search_mode = {
    { key = 'Enter', mods = 'NONE', action = act.CopyMode 'PriorMatch' },
    { key = 'Escape', mods = 'NONE', action = act.CopyMode 'Close' },
    { key = 'n', mods = 'CTRL', action = act.CopyMode 'NextMatch' },
    { key = 'p', mods = 'CTRL', action = act.CopyMode 'PriorMatch' },
    { key = 'r', mods = 'CTRL', action = act.CopyMode 'CycleMatchType' },
    { key = 'u', mods = 'CTRL', action = act.CopyMode 'ClearPattern' },
    { key = 'PageUp', mods = 'NONE', action = act.CopyMode 'PriorMatchPage' },
    { key = 'PageDown', mods = 'NONE', action = act.CopyMode 'NextMatchPage' },
    { key = 'UpArrow', mods = 'NONE', action = act.CopyMode 'PriorMatch' },
    { key = 'DownArrow', mods = 'NONE', action = act.CopyMode 'NextMatch' },
  },

}

config.color_scheme = 'flatblue-dark'
config.color_schemes = {
    ['flatblue-dark'] = {
        cursor_bg = '#52ad70',
        cursor_fg = 'black',
        cursor_border = '#52ad70',
        selection_fg = 'black',
        selection_bg = '#fffacd',
        scrollbar_thumb = '#222222',
        split = '#444444',

        background = '#010309',
        foreground = '#fcfefb',

        ansi = {
            '#010309',
            '#f24130',
            '#71ba51',
            '#f39c12',
            '#005973',
            '#7e3661',
            '#249991',
            '#d9d7cc',
        },

        brights = {
            '#828087',
            '#d92817',
            '#00af5f',
            '#f2bb13',
            '#178ca6',
            '#ff465a',
            '#67c5b4',
            '#fcfefb',
        },

        indexed = {
            [232] = '#06070d',
            [233] = '#252727',
            [234] = '#353736',
            [235] = '#464845',
            [236] = '#535551',
            [237] = '#5c5d59',
            [238] = '#646661',
            [239] = '#6d6f69',
            [240] = '#767872',
            [241] = '#7f817a',
            [242] = '#898a83',
            [243] = '#92938b',
            [244] = '#9b9c94',
            [245] = '#a5a69d',
            [246] = '#acada3',
            [247] = '#b3b4aa',
            [248] = '#babbb1',
            [249] = '#c2c2b7',
            [250] = '#ccccc1',
            [251] = '#d6d6ca',
            [252] = '#e0e0d3',
            [253] = '#eaeadd',
            [254] = '#f4f4e6',
            [255] = '#fffff0',
        },

        compose_cursor = 'orange',
        copy_mode_active_highlight_bg = { Color = '#000000' },
        -- use `AnsiColor` to specify one of the ansi color palette values
        -- (index 0-15) using one of the names "Black", "Maroon", "Green",
        --  "Olive", "Navy", "Purple", "Teal", "Silver", "Grey", "Red", "Lime",
        -- "Yellow", "Blue", "Fuchsia", "Aqua" or "White".
        copy_mode_active_highlight_fg = { AnsiColor = 'Black' },
        copy_mode_inactive_highlight_bg = { Color = '#52ad70' },
        copy_mode_inactive_highlight_fg = { AnsiColor = 'White' },

        quick_select_label_bg = { Color = 'peru' },
        quick_select_label_fg = { Color = '#ffffff' },
        quick_select_match_bg = { AnsiColor = 'Navy' },
        quick_select_match_fg = { Color = '#ffffff' }, 
    },
    ['flatblue-light'] = {
        cursor_bg = '#52ad70',
        cursor_fg = 'black',
        cursor_border = '#52ad70',
        selection_fg = 'black',
        selection_bg = '#fffacd',
        scrollbar_thumb = '#222222',
        split = '#444444',

        background = '#ffffff',
        foreground = '#18191c',

        ansi = {
            '#ffffff',
            '#f24130',
            '#71ba51',
            '#ffe000',
            '#07b0ff',
            '#ff465a',
            '#67c5b4',
            '#1E1F21',
        },

        brights = {
            '#b8b9b4',
            '#d92817',
            '#3e871e',
            '#f2bb13',
            '#178ca6',
            '#dd465a',
            '#249991',
            '#323037',
        },

        indexed = {
            [232] = '#F4F4F4',
            [233] = '#E9E9E9',
            [234] = '#DFDFDF',
            [235] = '#D5D5D5',
            [236] = '#CACACA',
            [237] = '#C0C0C0',
            [238] = '#B6B6B6',
            [239] = '#ACACAC',
            [240] = '#A1A1A1',
            [241] = '#979797',
            [242] = '#8D8D8D',
            [243] = '#838383',
            [244] = '#787878',
            [245] = '#6E6E6E',
            [246] = '#646464',
            [247] = '#5A5A5A',
            [248] = '#4F4F4F',
            [249] = '#454545',
            [250] = '#3B3B3B',
            [251] = '#313131',
            [252] = '#262626',
            [253] = '#1C1C1C',
            [254] = '#121212',
            [255] = '#080808',
        },

        compose_cursor = 'orange',
        copy_mode_active_highlight_bg = { Color = '#000000' },
        -- use `AnsiColor` to specify one of the ansi color palette values
        -- (index 0-15) using one of the names "Black", "Maroon", "Green",
        --  "Olive", "Navy", "Purple", "Teal", "Silver", "Grey", "Red", "Lime",
        -- "Yellow", "Blue", "Fuchsia", "Aqua" or "White".
        copy_mode_active_highlight_fg = { AnsiColor = 'Black' },
        copy_mode_inactive_highlight_bg = { Color = '#52ad70' },
        copy_mode_inactive_highlight_fg = { AnsiColor = 'White' },

        quick_select_label_bg = { Color = 'peru' },
        quick_select_label_fg = { Color = '#ffffff' },
        quick_select_match_bg = { AnsiColor = 'Navy' },
        quick_select_match_fg = { Color = '#ffffff' }, 
    }
}

if config.color_scheme == 'flatblue-dark' then
    config.inactive_pane_hsb = {
      saturation = 0.9,
      brightness = 0.8,
    }
else
    config.inactive_pane_hsb = {
      saturation = 1.0,
      brightness = 0.95,
    }
end

-- and finally, return the configuration to wezterm
return config
