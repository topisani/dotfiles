#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

build() {
    git submodule update --init qml-niri
    cd qml-niri
    mkdir -p build
    cd build && cmake ..
    make
}

debug() {
    build
    QS_ICON_THEME=breeze-dark \
    QT_LOGGING_RULES="qml.debug=true" \
    QML_IMPORT_PATH="$PWD/qml-niri/build:${QML_IMPORT_PATH:-}" \
    quickshell --path shell "$@"
}

run() {
    QS_ICON_THEME=breeze-dark \
    QML_IMPORT_PATH="$PWD/qml-niri/build:${QML_IMPORT_PATH:-}" \
    quickshell --path "$PWD/shell" "$@"
}

ipc() {
    quickshell --path "$PWD/shell" ipc --any-display "$@"
}

cmd="${1:-run}"
shift || true
"$cmd" "$@"
