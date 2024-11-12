#!/bin/sh
input=$(cat; echo .)
input=${input%.}
prefix="$(printf %s "$input" | perl -ne 'if (m{^\h*((?://[!/]?|[#*]|>(?: >)*) )}) {print $1; exit}' )"
printf %s "$input" | fmt --prefix="$prefix" "$@"
