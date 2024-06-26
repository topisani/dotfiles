# flatblue-dark theme

evaluate-commands %sh{
    bg_unfocused="rgb:000000"
    bg0="rgb:08090c"
    #bg="rgb:18191c"
    # bg="rgb:08090c"
    bg="rgb:010309"
    bg1="rgb:0a0b15"
    bg2="rgb:112126"
    bg2="rgb:181b2e"
    bg3="rgb:323037"
    bg4="rgb:2d334e"
    float_bg="rgb:06070d"

    fg0="rgb:ffffdf"
    # fg="rgb:fdf4d1" # Softer variant
    fg="rgb:fcfcfd"
    fg1="rgb:f4e8ca"
    fg2="rgb:cbdbe2"
    fg3="rgb:8899a4"
    
    gray="rgb:565f6f"
    red="rgb:f24130"
    red_dark="rgb:d92817"
    green="rgb:71ba51"
    green_dark="rgb:00af5f"
    yellow_light="rgb:ffe000"
    yellow="rgb:f2bb13"
    yellow_dark="rgb:f39c12"
    blue_light="rgb:07b0ff"
    blue="rgb:178ca6"
    blue_dark="rgb:005973"
    purple_light="rgb:ff669a"
    purple="rgb:dd465a"
    purple_dark="rgb:8f3f71"
    aqua="rgb:67c5b4"
    aqua_dark="rgb:249991"
    orange="rgb:fe8019"
    orange_dark="rgb:de5019"

    bluish_fg="rgb:9EEEFF"

    . "$HOME/.config/kak/scripts/make-flatblue"
}

declare-option range-specs show_colors
define-command show-colors -override %{
    remove-hooks window show-colors
    add-highlighter -override window/show-colors ranges show_colors
    hook window -group show-colors NormalIdle .* %{
        eval -draft %{
            set window show_colors %val{timestamp}
            execute-keys '%s(rgb:|#)\K[0-9a-fA-F]{6,8}<ret>'
            eval -itersel %{
                set -add window show_colors "%val{selection_desc}|,rgb:%reg{.}"
            }
        }
    }
}
