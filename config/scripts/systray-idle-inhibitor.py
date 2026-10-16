#!/usr/bin/env -S uv run
# /// script
# dependencies = [
#     "dbus-fast",
#     "cairosvg",
# ]
# ///
"""System tray idle/suspend inhibitor toggle with display of active systemd inhibitors."""

import asyncio
import os
import sys
from functools import partial

from dbus_fast import BusType, Message, MessageType
from dbus_fast.aio import MessageBus
from sni_tray import MenuItem, Separator, TrayIcon, icon_from_svg

LOGIN_BUS = "org.freedesktop.login1"
LOGIN_PATH = "/org/freedesktop/login1"
MANAGER_IFACE = "org.freedesktop.login1.Manager"

# Independently toggleable inhibitors. "idle" blocks the idle timer (screen
# blank/lock/DPMS); "sleep" blocks suspend/hibernate but leaves idle alone.
INHIBITORS = {
    "idle": {
        "what": "idle",
        "who": "Idle Inhibitor",
        "why": "User requested via systray",
        "label": "Idle Inhibitor",
        "fd": None,
    },
    "sleep": {
        "what": "sleep",
        "who": "Suspend Inhibitor",
        "why": "User requested via systray",
        "label": "Suspend Inhibitor",
        "fd": None,
    },
}

ICON_FALLBACK_ACTIVE = icon_from_svg('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22" width="22" height="22" fill="#fff" stroke="#fff" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"><path d="M3 8h11v5a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4z"/><path fill="none" d="M14 9.5h2.5a2.5 2.5 0 0 1 0 5H14"/><path fill="none" d="M8 6c0-1.5 1.5-1.8 1.5-3"/><path fill="none" d="M12 6c0-1.5 1.5-1.8 1.5-3"/></svg>')

ICON_FALLBACK_INACTIVE = icon_from_svg('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22" width="22" height="22" fill="none" stroke="#fff" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"><path d="M3 8h11v5a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4z"/><path d="M14 9.5h2.5a2.5 2.5 0 0 1 0 5H14"/></svg>')

icon = None


async def _take_inhibitor(what, who, why):
    bus = await MessageBus(bus_type=BusType.SYSTEM, negotiate_unix_fd=True).connect()
    try:
        reply = await bus.call(
            Message(
                destination=LOGIN_BUS,
                path=LOGIN_PATH,
                interface=MANAGER_IFACE,
                member="Inhibit",
                signature="ssss",
                body=[what, who, why, "block"],
            )
        )
        if reply.message_type == MessageType.ERROR:
            raise RuntimeError(f"D-Bus error: {reply.body}")
        # dup so the fd survives bus disconnect, then close the original
        # so only one reference remains — logind removes the inhibitor
        # when all references to the fd are closed
        fd = reply.unix_fds[0]
        duped = os.dup(fd)
        os.close(fd)
        return duped
    finally:
        bus.disconnect()


async def _list_inhibitors():
    bus = await MessageBus(bus_type=BusType.SYSTEM).connect()
    try:
        reply = await bus.call(
            Message(
                destination=LOGIN_BUS,
                path=LOGIN_PATH,
                interface=MANAGER_IFACE,
                member="ListInhibitors",
                signature="",
                body=[],
            )
        )
        if reply.message_type == MessageType.ERROR:
            return []
        return reply.body[0] if reply.body else []
    finally:
        bus.disconnect()


async def toggle(key):
    inhibitor = INHIBITORS[key]
    if inhibitor["fd"] is not None:
        os.close(inhibitor["fd"])
        inhibitor["fd"] = None
    else:
        try:
            inhibitor["fd"] = await _take_inhibitor(
                inhibitor["what"], inhibitor["who"], inhibitor["why"]
            )
        except Exception as e:
            print(f"Failed to take {key} inhibitor: {e}", file=sys.stderr)
    _update_icon()
    await _refresh_menu()


def _update_icon():
    active_labels = [i["label"] for i in INHIBITORS.values() if i["fd"] is not None]
    icon.set_icon(
        pixmap=ICON_FALLBACK_ACTIVE if active_labels else ICON_FALLBACK_INACTIVE
    )
    icon.set_tooltip(
        f"Active: {', '.join(active_labels)}" if active_labels else "No inhibitors active"
    )


async def _refresh_menu():
    try:
        inhibitors = await _list_inhibitors()
    except Exception as e:
        print(f"Failed to list inhibitors: {e}", file=sys.stderr)
        inhibitors = []

    items = []
    for key, inhibitor in INHIBITORS.items():
        active = inhibitor["fd"] is not None
        label = inhibitor["label"]
        items.append(
            MenuItem(
                f"Disable {label}" if active else f"Enable {label}",
                on_click=partial(toggle, key),
            )
        )

    for key, inhibitor in INHIBITORS.items():
        what = inhibitor["what"]
        matching = [i for i in inhibitors if what in i[0].split(":")]
        if matching:
            items.append(Separator())
            items.append(MenuItem(f"Active {what} inhibitors:", enabled=False))
            for _what, who, why, _mode, _uid, pid in matching:
                items.append(MenuItem(f"  {who} (PID {pid}): {why}", enabled=False))

    icon.menu = items


async def main():
    global icon
    icon = TrayIcon(
        "idle-inhibitor",
        title="Idle Inhibitor",
        category="SystemServices",
        on_activate=partial(toggle, "idle"),
        on_menu_about_to_show=_refresh_menu,
    )
    _update_icon()
    await _refresh_menu()
    await icon.run()


if __name__ == "__main__":
    asyncio.run(main())
