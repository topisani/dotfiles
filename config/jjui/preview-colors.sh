#!/usr/bin/env bash
# Print sample jjui selected-row text on every background color option

SAMPLE=" zy        Tobias Pisani <mail@topisani.dev>  2026-06-25  b72 "

echo "256-color backgrounds (use the number as bg value in config):"
for i in $(seq 0 255); do
  printf '\033[48;5;%dm%3d\033[m  \033[1;97;48;5;%dm%s\033[m\n' "$i" "$i" "$i" "$SAMPLE"
done

echo ""
echo "Named ANSI backgrounds (0-15):"
names=(black red green yellow blue magenta cyan white
       "bright black" "bright red" "bright green" "bright yellow"
       "bright blue" "bright magenta" "bright cyan" "bright white")
for i in "${!names[@]}"; do
  printf '\033[48;5;%dm%2d\033[m  \033[1;97;48;5;%dm%s\033[m   bg = "%s"\n' \
    "$i" "$i" "$i" "$SAMPLE" "${names[$i]}"
done
