load-conf tmux

set global windowing_modules 'tmux' 'screen' 'zellij' 'wezterm' 'kitty' 'sway' 'wayland'

hook global ModuleLoaded wezterm %{
    define-command wezterm-terminal-popup -params 1.. %{
        wezterm-terminal-impl split-pane --cwd "%val{client_env_PWD}" --top --percent 30 --pane-id "%val{client_env_WEZTERM_PANE}" -- %arg{@}
    }
    complete-command wezterm-terminal-popup shell

    define-command wezterm-terminal-auto -params 1.. %{
        wezterm-terminal-impl split-pane --cwd "%val{client_env_PWD}" --top --pane-id "%val{client_env_WEZTERM_PANE}" -- %arg{@}
    }
    complete-command wezterm-terminal-auto shell
}
