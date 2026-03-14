#!/usr/bin/env -S uv run
# /// script
# dependencies = [
#     "dbus-fast",
# ]
# ///
"""System tray indicator for tuned power profile switching."""

import asyncio
import logging
import os
import signal
import subprocess

from sni_tray import MenuItem, Separator, TrayIcon

logging.basicConfig(level=logging.DEBUG, format="%(asctime)s - %(levelname)s - %(message)s")

ICON_PATH = "battery-profile-balanced"


def command_exists(cmd):
    return subprocess.call(f"type {cmd}", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE) == 0


def get_profiles():
    try:
        output = subprocess.check_output(["tuned-adm", "list"], stderr=subprocess.STDOUT, text=True)
        return [line.strip("- ").split(" - ")[0].strip() for line in output.split("\n") if line.startswith("- ")]
    except subprocess.CalledProcessError as e:
        logging.error(f"Error getting profiles: {e.output}")
        return []


def get_active_profile():
    try:
        output = subprocess.check_output(["tuned-adm", "active"], stderr=subprocess.STDOUT, text=True)
        if "No current active profile" in output:
            return None
        return output.split(":", 1)[1].strip().split()[0]
    except subprocess.CalledProcessError as e:
        logging.error(f"Error getting active profile: {e.output}")
        return None


def normalize_profile_name(profile):
    if profile == "intel-best_power_efficiency_mode- Intel epp 70 TuneD profile":
        return "intel-best_power_efficiency_mode"
    return profile


def switch_profile(profile):
    normalized = normalize_profile_name(profile)
    try:
        subprocess.check_output(["tuned-adm", "profile", normalized], stderr=subprocess.STDOUT, text=True)
        logging.info(f"Switched to profile: {normalized}")
    except subprocess.CalledProcessError as e:
        logging.error(f"Failed to switch profile: {e.output}")


icon = None


def refresh_menu():
    profiles = get_profiles()
    active = get_active_profile()

    items = []
    for profile in profiles:
        normalized = normalize_profile_name(profile)
        is_active = normalized == active
        items.append(
            MenuItem(
                profile,
                toggle_type="radio",
                toggle_state=1 if is_active else 0,
                on_click=lambda p=profile: switch_profile(p),
            )
        )

    items.append(Separator())
    items.append(MenuItem("Turn Off Applet", on_click=lambda: os._exit(0)))

    icon.menu = items


async def main():
    global icon

    if not command_exists("tuned-adm"):
        logging.error("'tuned-adm' command not found. Make sure 'tuned' is installed.")
        return

    icon = TrayIcon(
        "tuned-indicator",
        icon_name=ICON_PATH,
        title="TuneD Profile Switcher",
        category="SystemServices",
        on_menu_about_to_show=refresh_menu,
    )
    refresh_menu()
    await icon.run()


if __name__ == "__main__":
    asyncio.run(main())
