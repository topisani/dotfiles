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
config.enable_kitty_keyboard = true
config.term = "wezterm"

config.front_end = 'OpenGL'
-- config.webgpu_power_preference = 'HighPerformance'
-- This is where you actually apply your config choices

config.disable_default_key_bindings = true
config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 5000 }
config.keys = {
  -- { key = 'Tab', mods = 'CTRL', action = act.ActivateTabRelative(1) },
  -- { key = 'Tab', mods = 'SHIFT|CTRL', action = act.ActivateTabRelative(-1) },
  -- { key = 'Enter', mods = 'ALT', action = act.ToggleFullScreen },
  -- { key = '!', mods = 'CTRL', action = act.ActivateTab(0) },
  -- { key = '!', mods = 'SHIFT|CTRL', action = act.ActivateTab(0) },
  -- { key = '\"', mods = 'ALT|CTRL', action = act.SplitVertical{ domain =  'CurrentPaneDomain' } },
  -- { key = '\"', mods = 'SHIFT|ALT|CTRL', action = act.SplitVertical{ domain =  'CurrentPaneDomain' } },
  -- { key = '#', mods = 'CTRL', action = act.ActivateTab(2) },
  -- { key = '#', mods = 'SHIFT|CTRL', action = act.ActivateTab(2) },
  -- { key = '$', mods = 'CTRL', action = act.ActivateTab(3) },
  -- { key = '$', mods = 'SHIFT|CTRL', action = act.ActivateTab(3) },
  -- { key = '%', mods = 'CTRL', action = act.ActivateTab(4) },
  -- { key = '%', mods = 'SHIFT|CTRL', action = act.ActivateTab(4) },
  -- { key = '%', mods = 'ALT|CTRL', action = act.SplitHorizontal{ domain =  'CurrentPaneDomain' } },
  -- { key = '%', mods = 'SHIFT|ALT|CTRL', action = act.SplitHorizontal{ domain =  'CurrentPaneDomain' } },
  -- { key = '&', mods = 'CTRL', action = act.ActivateTab(6) },
  -- { key = '&', mods = 'SHIFT|CTRL', action = act.ActivateTab(6) },
  -- { key = '\'', mods = 'SHIFT|ALT|CTRL', action = act.SplitVertical{ domain =  'CurrentPaneDomain' } },
  -- { key = '(', mods = 'CTRL', action = act.ActivateTab(-1) },
  -- { key = '(', mods = 'SHIFT|CTRL', action = act.ActivateTab(-1) },
  -- { key = ')', mods = 'CTRL', action = act.ResetFontSize },
  -- { key = ')', mods = 'SHIFT|CTRL', action = act.ResetFontSize },
  -- { key = '*', mods = 'CTRL', action = act.ActivateTab(7) },
  -- { key = '*', mods = 'SHIFT|CTRL', action = act.ActivateTab(7) },
  -- { key = '+', mods = 'CTRL', action = act.IncreaseFontSize },
  -- { key = '+', mods = 'SHIFT|CTRL', action = act.IncreaseFontSize },
  -- { key = '-', mods = 'CTRL', action = act.DecreaseFontSize },
  -- { key = '-', mods = 'SHIFT|CTRL', action = act.DecreaseFontSize },
  -- { key = '-', mods = 'SUPER', action = act.DecreaseFontSize },
  -- { key = '0', mods = 'CTRL', action = act.ResetFontSize },
  -- { key = '0', mods = 'SHIFT|CTRL', action = act.ResetFontSize },
  -- { key = '0', mods = 'SUPER', action = act.ResetFontSize },
  -- { key = '1', mods = 'SHIFT|CTRL', action = act.ActivateTab(0) },
  -- { key = '1', mods = 'SUPER', action = act.ActivateTab(0) },
  -- { key = '2', mods = 'SHIFT|CTRL', action = act.ActivateTab(1) },
  -- { key = '2', mods = 'SUPER', action = act.ActivateTab(1) },
  -- { key = '3', mods = 'SHIFT|CTRL', action = act.ActivateTab(2) },
  -- { key = '3', mods = 'SUPER', action = act.ActivateTab(2) },
  -- { key = '4', mods = 'SHIFT|CTRL', action = act.ActivateTab(3) },
  -- { key = '4', mods = 'SUPER', action = act.ActivateTab(3) },
  -- { key = '5', mods = 'SHIFT|CTRL', action = act.ActivateTab(4) },
  -- { key = '5', mods = 'SHIFT|ALT|CTRL', action = act.SplitHorizontal{ domain =  'CurrentPaneDomain' } },
  -- { key = '5', mods = 'SUPER', action = act.ActivateTab(4) },
  -- { key = '6', mods = 'SHIFT|CTRL', action = act.ActivateTab(5) },
  -- { key = '6', mods = 'SUPER', action = act.ActivateTab(5) },
  -- { key = '7', mods = 'SHIFT|CTRL', action = act.ActivateTab(6) },
  -- { key = '7', mods = 'SUPER', action = act.ActivateTab(6) },
  -- { key = '8', mods = 'SHIFT|CTRL', action = act.ActivateTab(7) },
  -- { key = '8', mods = 'SUPER', action = act.ActivateTab(7) },
  -- { key = '9', mods = 'SHIFT|CTRL', action = act.ActivateTab(-1) },
  -- { key = '9', mods = 'SUPER', action = act.ActivateTab(-1) },
  -- { key = '=', mods = 'CTRL', action = act.IncreaseFontSize },
  -- { key = '=', mods = 'SHIFT|CTRL', action = act.IncreaseFontSize },
  -- { key = '=', mods = 'SUPER', action = act.IncreaseFontSize },
  -- { key = '@', mods = 'CTRL', action = act.ActivateTab(1) },
  -- { key = '@', mods = 'SHIFT|CTRL', action = act.ActivateTab(1) },
  -- { key = 'C', mods = 'CTRL', action = act.CopyTo 'Clipboard' },
  -- { key = 'C', mods = 'SHIFT|CTRL', action = act.CopyTo 'Clipboard' },
  -- { key = 'F', mods = 'CTRL', action = act.Search 'CurrentSelectionOrEmptyString' },
  -- { key = 'F', mods = 'SHIFT|CTRL', action = act.Search 'CurrentSelectionOrEmptyString' },
  -- { key = 'K', mods = 'CTRL', action = act.ClearScrollback 'ScrollbackOnly' },
  -- { key = 'K', mods = 'SHIFT|CTRL', action = act.ClearScrollback 'ScrollbackOnly' },
  -- { key = 'L', mods = 'CTRL', action = act.ShowDebugOverlay },
  -- { key = 'L', mods = 'SHIFT|CTRL', action = act.ShowDebugOverlay },
  -- { key = 'M', mods = 'CTRL', action = act.Hide },
  -- { key = 'M', mods = 'SHIFT|CTRL', action = act.Hide },
  -- { key = 'N', mods = 'CTRL', action = act.SpawnWindow },
  -- { key = 'N', mods = 'SHIFT|CTRL', action = act.SpawnWindow },
  -- { key = 'P', mods = 'CTRL', action = act.ActivateCommandPalette },
  -- { key = 'P', mods = 'SHIFT|CTRL', action = act.ActivateCommandPalette },
  -- { key = 'R', mods = 'CTRL', action = act.ReloadConfiguration },
  -- { key = 'R', mods = 'SHIFT|CTRL', action = act.ReloadConfiguration },
  -- { key = 'T', mods = 'CTRL', action = act.SpawnTab 'CurrentPaneDomain' },
  -- { key = 'T', mods = 'SHIFT|CTRL', action = act.SpawnTab 'CurrentPaneDomain' },
  -- { key = 'U', mods = 'CTRL', action = act.CharSelect{ copy_on_select = true, copy_to =  'ClipboardAndPrimarySelection' } },
  -- { key = 'U', mods = 'SHIFT|CTRL', action = act.CharSelect{ copy_on_select = true, copy_to =  'ClipboardAndPrimarySelection' } },
  -- { key = 'V', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },
  -- { key = 'V', mods = 'SHIFT|CTRL', action = act.PasteFrom 'Clipboard' },
  -- { key = 'W', mods = 'CTRL', action = act.CloseCurrentTab{ confirm = true } },
  -- { key = 'W', mods = 'SHIFT|CTRL', action = act.CloseCurrentTab{ confirm = true } },
  -- { key = 'X', mods = 'CTRL', action = act.ActivateCopyMode },
  -- { key = 'X', mods = 'SHIFT|CTRL', action = act.ActivateCopyMode },
  -- { key = 'Z', mods = 'CTRL', action = act.TogglePaneZoomState },
  -- { key = 'Z', mods = 'SHIFT|CTRL', action = act.TogglePaneZoomState },
  -- { key = '[', mods = 'SHIFT|SUPER', action = act.ActivateTabRelative(-1) },
  -- { key = ']', mods = 'SHIFT|SUPER', action = act.ActivateTabRelative(1) },
  -- { key = '^', mods = 'CTRL', action = act.ActivateTab(5) },
  -- { key = '^', mods = 'SHIFT|CTRL', action = act.ActivateTab(5) },
  -- { key = '_', mods = 'CTRL', action = act.DecreaseFontSize },
  -- { key = '_', mods = 'SHIFT|CTRL', action = act.DecreaseFontSize },
  -- { key = 'c', mods = 'SHIFT|CTRL', action = act.CopyTo 'Clipboard' },
  -- { key = 'c', mods = 'SUPER', action = act.CopyTo 'Clipboard' },
  -- { key = 'f', mods = 'SHIFT|CTRL', action = act.Search 'CurrentSelectionOrEmptyString' },
  -- { key = 'f', mods = 'SUPER', action = act.Search 'CurrentSelectionOrEmptyString' },
  -- { key = 'k', mods = 'SHIFT|CTRL', action = act.ClearScrollback 'ScrollbackOnly' },
  -- { key = 'k', mods = 'SUPER', action = act.ClearScrollback 'ScrollbackOnly' },
  -- { key = 'l', mods = 'SHIFT|CTRL', action = act.ShowDebugOverlay },
  -- { key = 'm', mods = 'SHIFT|CTRL', action = act.Hide },
  -- { key = 'm', mods = 'SUPER', action = act.Hide },
  -- { key = 'n', mods = 'SHIFT|CTRL', action = act.SpawnWindow },
  -- { key = 'n', mods = 'SUPER', action = act.SpawnWindow },
  -- { key = 'p', mods = 'SHIFT|CTRL', action = act.ActivateCommandPalette },
  -- { key = 'r', mods = 'SHIFT|CTRL', action = act.ReloadConfiguration },
  -- { key = 'r', mods = 'SUPER', action = act.ReloadConfiguration },
  -- { key = 't', mods = 'SHIFT|CTRL', action = act.SpawnTab 'CurrentPaneDomain' },
  -- { key = 't', mods = 'SUPER', action = act.SpawnTab 'CurrentPaneDomain' },
  -- { key = 'u', mods = 'SHIFT|CTRL', action = act.CharSelect{ copy_on_select = true, copy_to =  'ClipboardAndPrimarySelection' } },
  -- { key = 'v', mods = 'SHIFT|CTRL', action = act.PasteFrom 'Clipboard' },
  -- { key = 'v', mods = 'SUPER', action = act.PasteFrom 'Clipboard' },
  -- { key = 'w', mods = 'SHIFT|CTRL', action = act.CloseCurrentTab{ confirm = true } },
  -- { key = 'w', mods = 'SUPER', action = act.CloseCurrentTab{ confirm = true } },
  -- { key = 'x', mods = 'SHIFT|CTRL', action = act.ActivateCopyMode },
  -- { key = 'z', mods = 'SHIFT|CTRL', action = act.TogglePaneZoomState },
  -- { key = '{', mods = 'SUPER', action = act.ActivateTabRelative(-1) },
  -- { key = '{', mods = 'SHIFT|SUPER', action = act.ActivateTabRelative(-1) },
  -- { key = '}', mods = 'SUPER', action = act.ActivateTabRelative(1) },
  -- { key = '}', mods = 'SHIFT|SUPER', action = act.ActivateTabRelative(1) },
  -- { key = 'phys:Space', mods = 'SHIFT|CTRL', action = act.QuickSelect },
  -- { key = 'PageUp', mods = 'SHIFT', action = act.ScrollByPage(-1) },
  -- { key = 'PageUp', mods = 'CTRL', action = act.ActivateTabRelative(-1) },
  -- { key = 'PageUp', mods = 'SHIFT|CTRL', action = act.MoveTabRelative(-1) },
  -- { key = 'PageDown', mods = 'SHIFT', action = act.ScrollByPage(1) },
  -- { key = 'PageDown', mods = 'CTRL', action = act.ActivateTabRelative(1) },
  -- { key = 'PageDown', mods = 'SHIFT|CTRL', action = act.MoveTabRelative(1) },
  -- { key = 'LeftArrow', mods = 'SHIFT|CTRL', action = act.ActivatePaneDirection 'Left' },
  -- { key = 'LeftArrow', mods = 'SHIFT|ALT|CTRL', action = act.AdjustPaneSize{ 'Left', 1 } },
  -- { key = 'RightArrow', mods = 'SHIFT|CTRL', action = act.ActivatePaneDirection 'Right' },
  -- { key = 'RightArrow', mods = 'SHIFT|ALT|CTRL', action = act.AdjustPaneSize{ 'Right', 1 } },
  -- { key = 'UpArrow', mods = 'SHIFT|CTRL', action = act.ActivatePaneDirection 'Up' },
  -- { key = 'UpArrow', mods = 'SHIFT|ALT|CTRL', action = act.AdjustPaneSize{ 'Up', 1 } },
  -- { key = 'DownArrow', mods = 'SHIFT|CTRL', action = act.ActivatePaneDirection 'Down' },
  -- { key = 'DownArrow', mods = 'SHIFT|ALT|CTRL', action = act.AdjustPaneSize{ 'Down', 1 } },
  -- { key = 'Insert', mods = 'SHIFT', action = act.PasteFrom 'PrimarySelection' },
  -- { key = 'Insert', mods = 'CTRL', action = act.CopyTo 'PrimarySelection' },
  -- { key = 'Copy', mods = 'NONE', action = act.CopyTo 'Clipboard' },
  -- { key = 'Paste', mods = 'NONE', action = act.PasteFrom 'Clipboard' },
    { key = 'F11', action = act.ToggleFullScreen },
    { key = 'Tab', mods = 'LEADER', action = act.ActivateTabRelative(1) },
    { key = 'Tab', mods = 'SHIFT|LEADER', action = act.ActivateTabRelative(-1) },
    { key = '1', mods = 'LEADER', action = act.ActivateTab(0) },
    { key = '2', mods = 'LEADER', action = act.ActivateTab(1) },
    { key = '3', mods = 'LEADER', action = act.ActivateTab(2) },
    { key = '4', mods = 'LEADER', action = act.ActivateTab(3) },
    { key = '5', mods = 'LEADER', action = act.ActivateTab(4) },
    { key = '6', mods = 'LEADER', action = act.ActivateTab(5) },
    { key = '7', mods = 'LEADER', action = act.ActivateTab(6) },
    { key = '8', mods = 'LEADER', action = act.ActivateTab(7) },
    { key = '9', mods = 'LEADER', action = act.ActivateTab(8) },
    { key = '0', mods = 'LEADER', action = act.ActivateTab(9) },
    { key = '=', mods = 'CTRL', action = act.IncreaseFontSize },
    { key = '=', mods = 'SHIFT|CTRL', action = act.IncreaseFontSize },
    { key = '_', mods = 'CTRL', action = act.DecreaseFontSize },
    { key = '_', mods = 'SHIFT|CTRL', action = act.DecreaseFontSize },
    { key = '0', mods = 'CTRL', action = act.ResetFontSize },

    { key = 'd', mods = 'LEADER', action = act.ShowDebugOverlay },
    { key = 's', mods = 'LEADER', action = act.SplitVertical{ domain =  'CurrentPaneDomain' } },
    { key = 'v', mods = 'LEADER', action = act.SplitHorizontal{ domain =  'CurrentPaneDomain' } },
    { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },

    { key = 'x', mods = 'LEADER', action = act.ActivateCopyMode },
    { key = 'C', mods = 'SHIFT|CTRL', action = act.CopyTo 'Clipboard' },
    { key = 'V', mods = 'SHIFT|CTRL', action = act.PasteFrom 'Clipboard' },
    { key = '/', mods = 'LEADER', action = act.Search 'CurrentSelectionOrEmptyString' },
    { key = 'u', mods = 'LEADER', action = act.CharSelect{ copy_on_select = true, copy_to =  'ClipboardAndPrimarySelection' } },
    -- { key = 'K', mods = 'LEADER', action = act.ClearScrollback 'ScrollbackOnly' },
    { key = 'm', mods = 'LEADER', action = act.Hide },
    { key = 'n', mods = 'LEADER', action = act.SpawnWindow },
    { key = 'Space', mods = 'LEADER', action = act.ActivateCommandPalette },
    { key = 'r', mods = 'LEADER', action = act.ReloadConfiguration },
    { key = 't', mods = 'LEADER', action = act.SpawnTab 'CurrentPaneDomain' },
    { key = 'q', mods = 'LEADER', action = act.CloseCurrentTab{ confirm = true } },

    { key = 'f', mods = 'LEADER', action = act.QuickSelect },
    { key = 'PageUp', mods = 'SHIFT', action = act.ScrollByPage(-1) },
    { key = 'PageUp', mods = 'CTRL', action = act.ActivateTabRelative(-1) },
    { key = 'PageUp', mods = 'SHIFT|CTRL', action = act.MoveTabRelative(-1) },
    { key = 'PageDown', mods = 'SHIFT', action = act.ScrollByPage(1) },
    { key = 'PageDown', mods = 'CTRL', action = act.ActivateTabRelative(1) },
    { key = 'PageDown', mods = 'SHIFT|CTRL', action = act.MoveTabRelative(1) },

    { key = 'LeftArrow', mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
    { key = 'RightArrow', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },
    { key = 'UpArrow', mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
    { key = 'DownArrow', mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },
    { key = 'LeftArrow', mods = 'LEADER|CTRL', action = act.AdjustPaneSize{ 'Left', 5 } },
    { key = 'RightArrow', mods = 'LEADER|CTRL', action = act.AdjustPaneSize{ 'Right', 5 } },
    { key = 'UpArrow', mods = 'LEADER|CTRL', action = act.AdjustPaneSize{ 'Up', 5 } },
    { key = 'DownArrow', mods = 'LEADER|CTRL', action = act.AdjustPaneSize{ 'Down', 5 } },
    { key = 'Insert', mods = 'SHIFT', action = act.PasteFrom 'PrimarySelection' },
    { key = 'Insert', mods = 'CTRL', action = act.CopyTo 'PrimarySelection' },
    { key = 'Copy', mods = 'NONE', action = act.CopyTo 'Clipboard' },
    { key = 'Paste', mods = 'NONE', action = act.PasteFrom 'Clipboard' },
}

config.key_tables = {
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
        -- The default text color
        foreground = 'silver',
        -- The default background color
        background = 'black',

        -- Overrides the cell background color when the current cell is occupied by the
        -- cursor and the cursor style is set to Block
        cursor_bg = '#52ad70',
        -- Overrides the text color when the current cell is occupied by the cursor
        cursor_fg = 'black',
        -- Specifies the border color of the cursor when the cursor style is set to Block,
        -- or the color of the vertical or horizontal bar when the cursor style is set to
        -- Bar or Underline.
        cursor_border = '#52ad70',

        -- the foreground color of selected text
        selection_fg = 'black',
        -- the background color of selected text
        selection_bg = '#fffacd',

        -- The color of the scrollbar "thumb"; the portion that represents the current viewport
        scrollbar_thumb = '#222222',

        -- The color of the split lines between panes
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
    }
}


config.inactive_pane_hsb = {
  saturation = 0.9,
  brightness = 0.8,
}

-- and finally, return the configuration to wezterm
return config
