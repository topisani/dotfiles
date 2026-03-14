#!/usr/bin/env -S uv run
# /// script
# dependencies = [
#     "dbus-fast",
#     "cairosvg",
# ]
# ///
"""System tray idle inhibitor toggle with display of active systemd idle inhibitors."""

import asyncio
import os
import sys

from dbus_fast import BusType, Message, MessageType
from dbus_fast.aio import MessageBus
from sni_tray import MenuItem, Separator, TrayIcon, icon_from_svg

LOGIN_BUS = "org.freedesktop.login1"
LOGIN_PATH = "/org/freedesktop/login1"
MANAGER_IFACE = "org.freedesktop.login1.Manager"

INHIBIT_WHAT = "idle"
INHIBIT_WHO = "Idle Inhibitor"
INHIBIT_WHY = "User requested via systray"

ICON_ACTIVE = "caffeine-cup-full"
ICON_INACTIVE = "caffeine-cup-empty"
ICON_FALLBACK_ACTIVE = icon_from_svg('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22" width="22" height="22" fill="#fff" stroke="#fff" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"><path d="M3 8h11v5a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4z"/><path fill="none" d="M14 9.5h2.5a2.5 2.5 0 0 1 0 5H14"/><path fill="none" d="M8 6c0-1.5 1.5-1.8 1.5-3"/><path fill="none" d="M12 6c0-1.5 1.5-1.8 1.5-3"/></svg>')

ICON_FALLBACK_INACTIVE = icon_from_svg('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22" width="22" height="22" fill="none" stroke="#fff" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"><path d="M3 8h11v5a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4z"/><path d="M14 9.5h2.5a2.5 2.5 0 0 1 0 5H14"/></svg>')
inhibit_fd = None
icon = None


async def _take_inhibitor():
    bus = await MessageBus(bus_type=BusType.SYSTEM, negotiate_unix_fd=True).connect()
    try:
        reply = await bus.call(
            Message(
                destination=LOGIN_BUS,
                path=LOGIN_PATH,
                interface=MANAGER_IFACE,
                member="Inhibit",
                signature="ssss",
                body=[INHIBIT_WHAT, INHIBIT_WHO, INHIBIT_WHY, "block"],
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


async def toggle():
    global inhibit_fd
    if inhibit_fd is not None:
        os.close(inhibit_fd)
        inhibit_fd = None
    else:
        try:
            inhibit_fd = await _take_inhibitor()
        except Exception as e:
            print(f"Failed to take inhibitor: {e}", file=sys.stderr)
    _update_icon()
    await _refresh_menu()


def _update_icon():
    active = inhibit_fd is not None
    # Try preferred icon, use fallback name if theme doesn't have it
    icon.set_icon(pixmap=ICON_FALLBACK_ACTIVE if active else ICON_FALLBACK_INACTIVE)
    icon.set_tooltip("Idle inhibitor: active" if active else "Idle inhibitor: inactive")


async def _refresh_menu():
    try:
        inhibitors = await _list_inhibitors()
    except Exception as e:
        print(f"Failed to list inhibitors: {e}", file=sys.stderr)
        inhibitors = []

    active = inhibit_fd is not None
    idle = [i for i in inhibitors if "idle" in i[0]]

    items = [
        MenuItem(
            "Disable Idle Inhibitor" if active else "Enable Idle Inhibitor",
            on_click=toggle,
        ),
    ]

    if idle:
        items.append(Separator())
        items.append(MenuItem("Active idle inhibitors:", enabled=False))
        for _what, who, why, _mode, _uid, pid in idle:
            items.append(MenuItem(f"  {who} (PID {pid}): {why}", enabled=False))

    icon.menu = items


async def main():
    global icon
    icon = TrayIcon(
        "idle-inhibitor",
        title="Idle Inhibitor",
        category="SystemServices",
        on_activate=toggle,
        on_menu_about_to_show=_refresh_menu,
    )
    _update_icon()
    await _refresh_menu()
    await icon.run()


if __name__ == "__main__":
    asyncio.run(main())
