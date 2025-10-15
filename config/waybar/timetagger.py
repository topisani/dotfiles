#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "timetagger_cli",
# ]
# ///

import sys
import time
import json
from datetime import datetime
import timetagger_cli.core


def get_current_session_tags():
    """Get tags from the currently running TimeTagger session."""
    try:
        # Connect to TimeTagger (uses default local server)
        records = timetagger_cli.core.get_running_records()
        running = records[0]

        # Extract tags from the description
        # Tags in TimeTagger are prefixed with # in the description
        tags = [
            tag.strip() for tag in running.get("ds", "").split() if tag.startswith("#")
        ]

        return {
            "description": running["ds"],
            "tags": tags,
            "start_time": datetime.fromtimestamp(running["t1"]),
        }

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return None


def get_waybar_obj():
    session = get_current_session_tags()

    if session:
        duration = datetime.now() - session["start_time"]
        pango_desc = " ".join(
            (f'<span weight="bold">{word}</span>' if word.startswith("#") else word)
            for word in session["description"].split()
        )
        return {
            "text": f" {duration.seconds // 3600:02}:{(duration.seconds // 60) % 60:02}",
            "tooltip": f'<span style="italic">{pango_desc}</span>\nStarted <span weight="bold">{session["start_time"].strftime("%H:%M")}</span>',
            "class": "running",
        }
    else:
        return {
            "text": '<span foreground="gray"></span>',
            "tooltip": "No running timetagger session",
            "class": "stopped",
        }


def main():
    print(json.dumps(get_waybar_obj()))
    sys.stdout.flush()


if __name__ == "__main__":
    main()
