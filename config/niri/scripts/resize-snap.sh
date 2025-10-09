#!/bin/bash

# niri-resize-snap.sh
# Resize current column width or height by percentage with snapping to clean boundaries
# Usage: niri-resize-snap.sh [width|height] [change_percent] [snap_to_percent]

set -euo pipefail

# Configuration
AXIS=${1:-width}           # Default: width
CHANGE_PERCENT=$2          # Required parameter
SNAP_TO=${3:-${CHANGE_PERCENT#-}} # Default: snap to change percent (remove minus sign)
MIN_SIZE="$SNAP_TO"        # Minimum size is the snap boundary
MAX_SIZE=100               # Maximum size is always 100%

# Function to get current window size percentage
get_current_size_percent() {
    local axis="$1"
    # Get focused window geometry
    local focused_window=$(niri msg -j focused-window)
    if [ -z "$focused_window" ] || [ "$focused_window" = "null" ]; then
        echo "50" # Default fallback
        return
    fi

    if [ "$axis" = "width" ]; then
        local window_size=$(echo "$focused_window" | jq -r '.layout.window_size[0]')
        local screen_size=$(niri msg -j focused-output | jq -r '.logical.width')
    else
        local window_size=$(echo "$focused_window" | jq -r '.layout.window_size[1]')
        local screen_size=$(niri msg -j focused-output | jq -r '.logical.height')
    fi

    # Calculate percentage with decimal precision using bc
    local current_percent=$(echo "scale=2; $window_size * 100 / $screen_size" | bc)
    echo "$current_percent"
}

# Function to calculate snapped percentage
calculate_snapped_percent() {
    local current_percent="$1"
    local change_percent="$2"
    local snap_to="$3"
    local min_width="$4"
    local max_width="$5"

    # Calculate target percentage using bc for decimal arithmetic
    local target_percent=$(echo "scale=2; $current_percent + $change_percent" | bc)


    # Snap to nearest boundary using bc (implement modulo for decimals)
    # remainder = target_percent - (int(target_percent / snap_to) * snap_to)
    local quotient=$(echo "scale=0; $target_percent / $snap_to" | bc)
    local remainder=$(echo "scale=2; $target_percent - ($quotient * $snap_to)" | bc)
    local half_snap=$(echo "scale=2; $snap_to / 2" | bc)

    # Compare remainder to half of snap_to
    if (( $(echo "$remainder < $half_snap" | bc -l) )); then
        snapped_percent=$(echo "scale=2; $target_percent - $remainder" | bc)
    else
        snapped_percent=$(echo "scale=2; $target_percent - $remainder + $snap_to" | bc)
    fi

    # Clamp to bounds
    if (( $(echo "$snapped_percent < $min_width" | bc -l) )); then
        snapped_percent="$min_width"
    elif (( $(echo "$snapped_percent > $max_width" | bc -l) )); then
        snapped_percent="$max_width"
    fi

    echo "$snapped_percent"
}

# Function to format percentage for niri command (round to nearest integer)
format_percent_for_niri() {
    local percent="$1"
    # Round to nearest integer for niri command
    echo ${percent%%.}
}

# Function to check if two decimal numbers are effectively equal
numbers_equal() {
    local num1="$1"
    local num2="$2"
    local threshold="0.01"  # Consider equal if difference is less than 0.01%

    local diff=$(echo "scale=4; ($num1 - $num2)" | bc | sed 's/^-//')
    (( $(echo "$diff < $threshold" | bc -l) ))
}

# Main function
main() {
    # Validate niri is available and running
    if ! niri msg -j focused-output >/dev/null 2>&1; then
        echo "Error: Cannot communicate with niri" >&2
        exit 1
    fi

    # Get current size percentage
    local current_percent
    current_percent=$(get_current_size_percent "$AXIS")

    # Calculate new snapped percentage
    local new_percent
    new_percent=$(calculate_snapped_percent "$current_percent" "$CHANGE_PERCENT" "$SNAP_TO" "$MIN_SIZE" "$MAX_SIZE")

    # Only resize if percentage changed significantly
    if ! numbers_equal "$current_percent" "$new_percent"; then
        local formatted_percent
        formatted_percent=$(format_percent_for_niri "$new_percent")

        if [ "$AXIS" = "width" ]; then
            niri msg action set-column-width "${formatted_percent}%"
        else
            niri msg action set-window-height "${formatted_percent}%"
        fi
        echo "Resized $AXIS: ${current_percent}% → ${new_percent}% (applied: ${formatted_percent}%)" >&2
    else
        echo "Already at target $AXIS size: ${current_percent}%" >&2
    fi
}

# Show help if requested
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    cat << EOF
Usage: $0 [width|height] CHANGE_PERCENT [SNAP_TO]

Resize current niri window width or height with snapping to clean percentage boundaries.
Supports decimal values for precise control.

Arguments:
    width|height    Axis to resize [default: width]
    CHANGE_PERCENT  Percentage change (can be negative, supports decimals) [required]
    SNAP_TO         Snap to nearest multiple (supports decimals) [default: CHANGE_PERCENT]

Bounds:
    MIN_SIZE        Always equals SNAP_TO
    MAX_SIZE        Always 100%

Examples:
    $0 width 10.5       # Increase width by 10.5%, snap to 10.5%
    $0 width -7.25      # Decrease width by 7.25%, snap to 7.25%
    $0 height 5.0 2.5   # Increase height by 5%, snap to 2.5%
    $0 height -12.75    # Decrease height by 12.75%, snap to 12.75%
    $0 width 15 5       # Increase width by 15%, snap to 5% boundaries
EOF
    exit 0
fi

# Validate axis argument
if [ "$AXIS" != "width" ] && [ "$AXIS" != "height" ]; then
    echo "Error: First argument must be 'width' or 'height'" >&2
    exit 1
fi

# Check if CHANGE_PERCENT is provided
if [ -z "${2:-}" ]; then
    echo "Error: CHANGE_PERCENT is required" >&2
    exit 1
fi

# Validate numeric arguments
for arg in "$CHANGE_PERCENT" "$SNAP_TO"; do
    if ! [[ "$arg" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        echo "Error: CHANGE_PERCENT and SNAP_TO must be numbers" >&2
        exit 1
    fi
done

main
