#!/bin/zsh

if [ -n "$ZDOTDIR" ] && [ ! -d "$ZDOTDIR" ]; then
    # If ZDOTDIR doesn't exist, try the host path
    if [ -d "/run/host${ZDOTDIR}" ]; then
        export ZDOTDIR="/run/host${ZDOTDIR}"
    fi
fi
