#!/usr/bin/env -S uv run
# /// script
# dependencies = [
#     "dbus-fast",
#     "cairosvg",
# ]
# ///
"""System tray indicator for Jottacloud sync status."""

import asyncio
import json
import subprocess
from datetime import datetime
from pathlib import Path

from sni_tray import MenuItem, Separator, TrayIcon, icon_from_svg

UPDATE_INTERVAL_S = 30


def jotta_svg(color):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="-2 5 30 30">
        <path fill="{color}" d="M25.699 7v17.334a8.72 8.72 0 0 1-2.51 6.128A8.52 8.52 0 0 1 17.133 33h-3.427V15.667a8.72 8.72 0 0 1 2.51-6.129A8.52 8.52 0 0 1 22.271 7zM0 20.867h3.427c2.272 0 4.45.913 6.058 2.538a8.72 8.72 0 0 1 2.509 6.128V33H8.567a8.52 8.52 0 0 1-6.058-2.538A8.72 8.72 0 0 1 0 24.334z"></path>
        </svg>"""


ICON_IDLE = icon_from_svg(jotta_svg("#999999"))
ICON_SYNCING = icon_from_svg(jotta_svg("#7D5FE6"))

icon = None
status_data = None
auto_sync_enabled = False


def get_sync_status():
    try:
        result = subprocess.run(
            ["jotta-cli", "status", "--json"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0:
            return json.loads(result.stdout)
    except (subprocess.TimeoutExpired, FileNotFoundError, json.JSONDecodeError):
        pass
    return None


def get_recent_files(count=5):
    try:
        result = subprocess.run(
            ["jotta-cli", "sync", "log", "-n", str(count)],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode != 0:
            return []
        files = []
        for line in result.stdout.strip().split("\n"):
            if "::" in line:
                parts = line.split(" :: ", 1)
                if len(parts) == 2:
                    timestamp_str, file_info = parts
                    if " " in file_info:
                        action, filepath = file_info.split(" ", 1)
                        files.append({
                            "timestamp": timestamp_str.strip(),
                            "action": action.strip(),
                            "path": filepath.strip(),
                        })
        return files
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return []


def format_bytes(bytes_val):
    if bytes_val < 1024:
        return f"{bytes_val} B"
    elif bytes_val < 1024 * 1024:
        return f"{bytes_val / 1024:.1f} KB"
    elif bytes_val < 1024 * 1024 * 1024:
        return f"{bytes_val / (1024 * 1024):.1f} MB"
    else:
        return f"{bytes_val / (1024 * 1024 * 1024):.2f} GB"


def format_time_ago(timestamp):
    try:
        diff = datetime.now() - timestamp
        seconds = diff.total_seconds()
        if seconds < 60:
            return "just now"
        elif seconds < 3600:
            return f"{int(seconds / 60)}m ago"
        elif seconds < 86400:
            return f"{int(seconds / 3600)}h ago"
        else:
            return f"{int(seconds / 86400)}d ago"
    except Exception:
        return "Unknown"


def truncate_filename(path, max_length=50):
    if len(path) <= max_length:
        return path
    parts = path.split("/")
    filename = parts[-1]
    if len(filename) > max_length - 3:
        return "..." + filename[-(max_length - 3):]
    remaining = max_length - len(filename) - 4
    path_parts = []
    for part in reversed(parts[:-1]):
        if len("/".join(path_parts + [part])) <= remaining:
            path_parts.insert(0, part)
        else:
            break
    if path_parts:
        return "[...]/" + "/".join(path_parts) + "/" + filename
    return "[...]/" + filename


def on_toggle_auto_sync():
    if auto_sync_enabled:
        subprocess.run(["jotta-cli", "sync", "stop"], timeout=5)
    else:
        subprocess.run(["jotta-cli", "sync", "start"], timeout=5)
    update_status()


def on_trigger_sync():
    subprocess.run(["jotta-cli", "sync", "trigger"], timeout=5)
    update_status()


def on_open_folder():
    if status_data:
        root_path = status_data.get("Sync", {}).get("RootPath", "")
        if root_path and Path(root_path).exists():
            subprocess.Popen(["xdg-open", root_path])


def on_open_webapp():
    subprocess.Popen(["xdg-open", "https://www.jottacloud.com/web"])


def update_status():
    global status_data, auto_sync_enabled

    data = get_sync_status()
    if data is None:
        icon.set_icon(pixmap=ICON_IDLE)
        icon.set_tooltip("Jotta CLI - Error")
        icon.menu = [MenuItem("Status: Error", enabled=False)]
        return

    status_data = data
    sync_info = data.get("Sync", {})
    sync_enabled = sync_info.get("Enabled", False)
    auto_sync = sync_info.get("Automatic", False)
    auto_sync_enabled = auto_sync

    state = data.get("State", {})
    uploading = state.get("Uploading", {})
    downloading = state.get("Downloading", {})
    is_uploading = bool(uploading)
    is_downloading = bool(downloading)

    if not sync_enabled:
        status_text = "Sync Disabled"
        current_icon = ICON_IDLE
    elif is_uploading or is_downloading:
        status_text = "Syncing"
        current_icon = ICON_SYNCING
    elif auto_sync:
        status_text = "Up to date"
        current_icon = ICON_SYNCING
    else:
        status_text = "Paused"
        current_icon = ICON_IDLE

    icon.set_icon(pixmap=current_icon)
    icon.set_tooltip(f"Jotta CLI - {status_text}")

    # Build menu
    items = [MenuItem(f"Status: {status_text}", enabled=False)]

    if is_uploading:
        for filename, file_data in uploading.items():
            progress = file_data.get("Progress", 0)
            size = file_data.get("Size", 0)
            items.append(MenuItem(f"  ↑ {filename} ({progress}/{size})", enabled=False))

    if is_downloading:
        for filename, file_data in downloading.items():
            progress = file_data.get("Progress", 0)
            size = file_data.get("Size", 0)
            items.append(MenuItem(f"  ↓ {filename} ({progress}/{size})", enabled=False))

    last_update_ms = sync_info.get("LastUpdateMS", 0)
    if last_update_ms > 0:
        time_ago = format_time_ago(datetime.fromtimestamp(last_update_ms / 1000))
        items.append(MenuItem(f"Last sync: {time_ago}", enabled=False))
    else:
        items.append(MenuItem("Last sync: Unknown", enabled=False))

    items.append(Separator())
    items.append(MenuItem("Open Sync Folder", on_click=on_open_folder))
    items.append(MenuItem("Open Jottacloud Web", on_click=on_open_webapp))
    items.append(Separator())
    items.append(MenuItem(
        "Disable Automatic Sync" if auto_sync else "Enable Automatic Sync",
        on_click=on_toggle_auto_sync,
    ))
    items.append(MenuItem("Sync Now", on_click=on_trigger_sync))

    icon.menu = items


def refresh_menu():
    """Called when menu is about to show - add recent files."""
    update_status()

    recent = get_recent_files(5)
    if recent:
        current = list(icon.menu)
        current.append(Separator())
        for file_info in recent:
            action_time = format_time_ago(
                datetime.strptime(file_info["timestamp"].split(".")[0], "%Y-%m-%d %H:%M:%S")
            )
            action_icon = "↓" if file_info["action"] == "Download" else "↑"
            truncated = truncate_filename(file_info["path"])
            current.append(MenuItem(f"{action_time} {action_icon} {truncated}", enabled=False))
        icon.menu = current


async def periodic_update():
    while True:
        await asyncio.sleep(UPDATE_INTERVAL_S)
        update_status()


async def main():
    global icon
    icon = TrayIcon(
        "jotta-cli",
        title="Jotta CLI",
        category="ApplicationStatus",
        on_menu_about_to_show=refresh_menu,
    )
    update_status()
    asyncio.create_task(periodic_update())
    await icon.run()


if __name__ == "__main__":
    asyncio.run(main())
