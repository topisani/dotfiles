local wezterm = require 'wezterm';

wezterm.on("toggle-tabbar", function(window, pane)
  local overrides = window:get_config_overrides() or {}
  if overrides.enable_tab_bar == nil then
    overrides.enable_tab_bar = false
  else
    overrides.enable_tab_bar = nil
  end
  window:set_config_overrides(overrides)
end)

return {
  color_scheme_dirs = {wezterm.config_dir .. "/colors"},
  color_scheme = "flatblue-dark",
  bold_brightens_ansi_colors = false,
  font_antialias = "None",
  font = wezterm.font({"JetBrains Mono"}),
  font_rules= {
    {
      italic = true,
      font = wezterm.font("JetBrains Mono", {italic=true}),
    },

    {
      italic = true,
      intensity = "Bold",
      font = wezterm.font("JetBrains Mono", {bold=true,italic=true}),
    },

    {
      intensity = "Bold",
      font = wezterm.font("JetBrains Mono", {bold=true}),
    },
  },

  
  freetype_load_flags = "NO_HINTING|MONOCHROME",
  -- font = wezterm.font("JetBrains Mono");
  
  -- set to false to disable the tab bar completely
  enable_tab_bar = true,
  
  window_padding = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0,
  },
  
  inactive_pane_hsb = {
    saturation = 1.0,
    brightness = 1.0,
  },
  -- set to true to hide the tab bar when there is only
  -- a single tab in the window
  hide_tab_bar_if_only_one_tab = false,

  leader = { key=" ", mods="CTRL", timeout_milliseconds=1000 },
  disable_default_key_bindings = true,
  keys = {
    {key="´", mods="", action='ShowTabNavigator'},
    {key="p", mods="LEADER", action=wezterm.action({EmitEvent="toggle-tabbar"})},
    -- {key="c", mods="SUPER", action=wezterm.action({CopyTo="Clipboard"})},
    -- {key="v", mods="SUPER", action=wezterm.action({PasteFrom="Clipboard"})},
    {key="c", mods="CTRL|SHIFT", action=wezterm.action({CopyTo="Clipboard"})},
    {key="v", mods="CTRL|SHIFT", action=wezterm.action({PasteFrom="Clipboard"})},
    {key="Insert", mods="CTRL", action=wezterm.action({CopyTo="PrimarySelection"})},
    {key="Insert", mods="SHIFT", action=wezterm.action({PasteFrom="PrimarySelection"})},
    --  {key="m", mods="SUPER", action='Hide'},
    --   {key="n", mods="SUPER", action='SpawnWindow'},
    {key="n", mods="LEADER", action='SpawnWindow'},
    {key="-", mods="CTRL", action='DecreaseFontSize'},
    {key="+", mods="CTRL", action='IncreaseFontSize'},
    {key="0", mods="CTRL", action='ResetFontSize'},
    {key="c", mods="LEADER", action=wezterm.action({SpawnTab="CurrentPaneDomain"})},
    {key="q", mods="LEADER", action=wezterm.action({CloseCurrentPane={confirm=true}})},
    {key="PageUp", mods="CTRL|SHIFT", action=wezterm.action({MoveTabRelative=-1})},
    {key="PageDown", mods="CTRL|SHIFT", action=wezterm.action({MoveTabRelative=1})},
    {key="PageUp", mods="SHIFT", action=wezterm.action({ScrollByPage=-1})},
    {key="PageDown", mods="SHIFT", action=wezterm.action({ScrollByPage=1})},
    {key="r", mods="LEADER", action='ReloadConfiguration'},
    {key="f", mods="LEADER", action=wezterm.action({Search={CaseSensitiveString=""}})},
    {key="x", mods="LEADER", action='ActivateCopyMode'},
    -- {key=" ", mods="LEADER", action='QuickSelect'},
    {key='s', mods="LEADER", action=wezterm.action({SplitVertical={domain="CurrentPaneDomain"}})},
    {key="v", mods="LEADER", action=wezterm.action({SplitHorizontal={domain="CurrentPaneDomain"}})},
    {key="LeftArrow", mods="CTRL|SHIFT|ALT", action=wezterm.action({AdjustPaneSize={"Left", 1}})},
    {key="RightArrow", mods="CTRL|SHIFT|ALT", action=wezterm.action({AdjustPaneSize={"Right", 1}})},
    {key="UpArrow", mods="CTRL|SHIFT|ALT", action=wezterm.action({AdjustPaneSize={"Up", 1}})},
    {key="DownArrow", mods="CTRL|SHIFT|ALT", action=wezterm.action({AdjustPaneSize={"Down", 1}})},
    
    {key="h", mods="LEADER", action=wezterm.action({ActivatePaneDirection="Left"})},
    {key="l", mods="LEADER", action=wezterm.action({ActivatePaneDirection="Right"})},
    {key="k", mods="LEADER", action=wezterm.action({ActivatePaneDirection="Up"})},
    {key="j", mods="LEADER", action=wezterm.action({ActivatePaneDirection="Down"})},
    {key="z", mods="LEADER", action='TogglePaneZoomState'}
}
}
