#!/bin/sh

# Rate limit configuration
RATE_LIMIT_SECONDS=0.1
LOCK_FILE="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/ratelimit_${1}.lock"

# Get current time in nanoseconds for sub-second precision
current_time=$(date +%s%N)

# Check if lock file exists and read last execution time
if [ -f "$LOCK_FILE" ]; then
    last_time=$(cat "$LOCK_FILE")
    # Calculate time difference in nanoseconds, then convert to seconds (with decimals)
    time_diff_ns=$((current_time - last_time))
    time_diff=$(echo "scale=3; $time_diff_ns / 1000000000" | bc)

    if [ "$(echo "$time_diff < $RATE_LIMIT_SECONDS" | bc)" -eq 1 ]; then
        exit 0
    fi
fi

# Update lock file with current time
echo "$current_time" > "$LOCK_FILE"

shift
"$@"
