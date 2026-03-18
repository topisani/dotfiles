#!/usr/bin/env bash
# user-service.sh - Run a command as a transient systemd user service scoped to the current graphical session.
#
# Usage: user-service.sh [--name <service-name>] <command> [args...]
#
# The service name is autodetected from the command basename (extension stripped,
# sanitized to lowercase alphanumeric with dashes) unless --name is provided.
# Re-running with the same name will replace any existing instance.
# All services are grouped under session-graphical.slice for collective management.

set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") [--name <service-name>] <command> [args...]"
    exit 1
}

SERVICE_NAME=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)
            SERVICE_NAME="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            break
            ;;
    esac
done

[[ $# -eq 0 ]] && usage

CMD="$1"
shift
ARGS=("$@")

# Autodetect service name from the command basename, strip extension
if [[ -z "$SERVICE_NAME" ]]; then
    SERVICE_NAME="$(basename "$CMD")"
    SERVICE_NAME="${SERVICE_NAME%.*}"
fi

# Sanitize: lowercase, replace non-alphanumeric with dashes
SERVICE_NAME="$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')"

# Resolve to absolute path if it's a file
if [[ -f "$CMD" ]]; then
    CMD="$(realpath "$CMD")"
fi

echo "Starting '${SERVICE_NAME}' -> ${CMD}${ARGS:+ ${ARGS[*]}}"

systemctl --user stop "${SERVICE_NAME}.service" 2>/dev/null || true
systemctl --user reset-failed "${SERVICE_NAME}.service" 2>/dev/null || true

systemd-run --user \
    --unit="${SERVICE_NAME}" \
    --description="User service: ${SERVICE_NAME}" \
    --slice=session-graphical.slice \
    --property=Restart=on-failure \
    --property=RestartSec=1 \
    --property=Type=exec \
    --property=PartOf=graphical-session.target \
    --property=After=graphical-session.target \
    -- "$CMD" "${ARGS[@]}"
