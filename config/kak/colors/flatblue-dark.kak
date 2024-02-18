# flatblue-dark theme

evaluate-commands %sh{
    bg_unfocused="rgb:000000"
    bg0="rgb:08090c"
    #bg="rgb:18191c"
    # bg="rgb:08090c"
    bg="rgb:010207"
    bg1="rgb:0a0b15"
    bg2="rgb:112126"
    bg3="rgb:323037"
    bg4="rgb:3c383c"
    float_bg="rgb:06070d"

    fg0="rgb:ffffdf"
    fg="rgb:fdf4d1"
    fg1="rgb:f4e8ca"
    fg2="rgb:ebdbc2"
    fg3="rgb:a89994"
    
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

define-command refresh-colors -override %{
    remove-hooks window refresh-colors
    hook window -group refresh-colors BufWritePost %reg[percent] %{
        source %reg[percent]
        rmhl window/refresh-colors
        addhl window/refresh-colors group
        execute-keys '%sface +global +\K\w+<ret>'
        eval %sh{
            for x in $kak_selections; do
                echo "addhl window/refresh-colors/$x regex 'face global \K$x' 0:$x"
            done
        }
    }
}
