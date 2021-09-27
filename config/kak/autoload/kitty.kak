# https://sw.kovidgoyal.net/kitty/index.html
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾

provide-module topisani-kitty %{

    declare-option -docstring %{window type that kitty creates on new and repl calls (window|os-window)} str kitty_window_type window

    define-command -override kitty-terminal -params 1.. -shell-completion -docstring '
    kitty-terminal <program> [<arguments>]: create a new terminal as a kitty window
    The program passed as argument will be executed in the new terminal' \
    %{
        nop %sh{
            match=""
            if [ -n "$kak_client_env_KITTY_WINDOW_ID" ]; then
                match="--match=id:$kak_client_env_KITTY_WINDOW_ID"
            fi

            listen=""
            if [ -n "$kak_client_env_KITTY_LISTEN_ON" ]; then
                listen="--to=$kak_client_env_KITTY_LISTEN_ON"
            fi

            kitty @ $listen launch --no-response --type="$kak_opt_kitty_window_type" --cwd="$PWD" $match "$@"
        }
    }

    define-command -override kitty-terminal-tab -params 1.. -shell-completion -docstring '
    kitty-terminal-tab <program> [<arguments>]: create a new terminal as kitty tab
    The program passed as argument will be executed in the new terminal' \
    %{
        nop %sh{
            match=""
            if [ -n "$kak_client_env_KITTY_WINDOW_ID" ]; then
                match="--match=id:$kak_client_env_KITTY_WINDOW_ID"
            fi

            listen=""
            if [ -n "$kak_client_env_KITTY_LISTEN_ON" ]; then
                listen="--to=$kak_client_env_KITTY_LISTEN_ON"
            fi

            kitty @ $listen launch --no-response --type=tab --cwd="$PWD" $match "$@"
        }
    }

    define-command -override kitty-focus -params ..1 -client-completion -docstring '
    kitty-focus [<client>]: focus the given client
    If no client is passed then the current one is used' \
    %{
        evaluate-commands %sh{
            if [ $# -eq 1 ]; then
                printf "evaluate-commands -client '%s' focus" "$1"
            else
                match=""
                if [ -n "$kak_client_env_KITTY_WINDOW_ID" ]; then
                    match="--match=id:$kak_client_env_KITTY_WINDOW_ID"
                fi

                listen=""
                if [ -n "$kak_client_env_KITTY_LISTEN_ON" ]; then
                    listen="--to=$kak_client_env_KITTY_LISTEN_ON"
                fi

                kitty @ $listen focus-window --no-response $match
            fi
        }
    }

    define-command -override kitty-terminal-horizontal -params 1.. -shell-completion -docstring '
    kitty-terminal <program> [<arguments>]: create a new terminal as a kitty window
    The program passed as argument will be executed in the new terminal' \
    %{
        nop %sh{
            match=""
            if [ -n "$kak_client_env_KITTY_WINDOW_ID" ]; then
                match="--match=id:$kak_client_env_KITTY_WINDOW_ID"
            fi

            listen=""
            if [ -n "$kak_client_env_KITTY_LISTEN_ON" ]; then
                listen="--to=$kak_client_env_KITTY_LISTEN_ON"
            fi

            kitty @ $listen launch --no-response --type="$kak_opt_kitty_window_type" --cwd="$PWD" $match --location hsplit "$@"
        }
    }

    define-command -override kitty-terminal-vertical -params 1.. -shell-completion -docstring '
    kitty-terminal <program> [<arguments>]: create a new terminal as a kitty window
    The program passed as argument will be executed in the new terminal' \
    %{
        nop %sh{
            match=""
            if [ -n "$kak_client_env_KITTY_WINDOW_ID" ]; then
                match="--match=id:$kak_client_env_KITTY_WINDOW_ID"
            fi

            listen=""
            if [ -n "$kak_client_env_KITTY_LISTEN_ON" ]; then
                listen="--to=$kak_client_env_KITTY_LISTEN_ON"
            fi

            kitty @ $listen launch --no-response --type="$kak_opt_kitty_window_type" --cwd="$PWD" $match --location vsplit "$@"
        }
    }

    define-command -override kitty-terminal-popup -params 1.. -shell-completion -docstring '
    kitty-terminal <program> [<arguments>]: create a new terminal as a kitty window
    The program passed as argument will be executed in the new terminal' \
    %{
        nop %sh{
            match=""
            if [ -n "$kak_client_env_KITTY_WINDOW_ID" ]; then
                match="--match=id:$kak_client_env_KITTY_WINDOW_ID"
            fi

            listen=""
            if [ -n "$kak_client_env_KITTY_LISTEN_ON" ]; then
                listen="--to=$kak_client_env_KITTY_LISTEN_ON"
            fi

            kitty @ $listen launch --no-response --type="os-window" --cwd="$PWD" $match "$@"
        }
    }
}

def kitty-integration-enable %{
    # ensure that we're running on kitty
    evaluate-commands %sh{
        [ -z "${kak_opt_windowing_modules}" ] || [ "$TERM" = "xterm-kitty" ] || echo 'fail Kitty not detected'
    }

    require-module topisani-kitty
   
    alias global popup kitty-terminal-popup
    alias global panel kitty-terminal-vertical
    alias global bottom-panel kitty-terminal-horizontal
    alias global terminal kitty-terminal
    alias global terminal-tab kitty-terminal-tab
    alias global focus kitty-focus
}
