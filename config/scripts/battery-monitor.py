#!/usr/bin/env -S uv run
# /// script
# dependencies = [
#     "dbus-fast",
# ]
# ///
"""Monitor battery level via UPower D-Bus and send notifications when low."""

import asyncio
from dbus_fast.aio import MessageBus
from dbus_fast import BusType, Variant

LOW_THRESHOLD = 10

UPOWER_BUS = "org.freedesktop.UPower"
DISPLAY_DEVICE_PATH = "/org/freedesktop/UPower/devices/DisplayDevice"
DEVICE_IFACE = "org.freedesktop.UPower.Device"
PROPS_IFACE = "org.freedesktop.DBus.Properties"

NOTIFY_BUS = "org.freedesktop.Notifications"
NOTIFY_PATH = "/org/freedesktop/Notifications"
NOTIFY_IFACE = "org.freedesktop.Notifications"


class UpowerState:
    Unknown = 0
    Charging = 1
    Discharging = 2
    Empty = 3
    FullyCharged = 4
    PendingCharge = 5
    PendingDischarge = 6


TYPE_BATTERY = 2


async def main():
    system_bus = await MessageBus(bus_type=BusType.SYSTEM).connect()
    session_bus = await MessageBus(bus_type=BusType.SESSION).connect()

    # UPower display device
    introspection = await system_bus.introspect(UPOWER_BUS, DISPLAY_DEVICE_PATH)
    proxy = system_bus.get_proxy_object(UPOWER_BUS, DISPLAY_DEVICE_PATH, introspection)
    props = proxy.get_interface(PROPS_IFACE)

    # Notifications
    notify_introspection = await session_bus.introspect(NOTIFY_BUS, NOTIFY_PATH)
    notify_proxy = session_bus.get_proxy_object(NOTIFY_BUS, NOTIFY_PATH, notify_introspection)
    notifications = notify_proxy.get_interface(NOTIFY_IFACE)

    not_id = 0
    event = asyncio.Event()

    def on_properties_changed(iface, changed, invalidated):
        if iface == DEVICE_IFACE:
            event.set()

    props.on_properties_changed(on_properties_changed)

    async def notify(percentage, icon_name, replace_id):
        return await notifications.call_notify(
            "battery-monitor",  # app_name
            replace_id,  # replaces_id
            icon_name,  # app_icon
            "Battery Low!",  # summary
            f"{percentage}%",  # body
            [],  # actions
            {"urgency": Variant("y", 2), "transient": Variant("b", True)},  # hints
            0,  # expire_timeout (0 = never)
        )

    async def close_notification(nid):
        if nid:
            await notifications.call_close_notification(nid)

    while True:
        percentage = int((await props.call_get(DEVICE_IFACE, "Percentage")).value)
        state = (await props.call_get(DEVICE_IFACE, "State")).value
        icon_name = (await props.call_get(DEVICE_IFACE, "IconName")).value
        is_charging = state in (UpowerState.Charging, UpowerState.PendingCharge, UpowerState.FullyCharged)

        print(f"STATE: {percentage}%, state={state}, icon={icon_name}")

        if percentage < LOW_THRESHOLD and not is_charging:
            not_id = await notify(percentage, icon_name, not_id)
        else:
            await close_notification(not_id)
            not_id = 0

        event.clear()
        await event.wait()


if __name__ == "__main__":
    asyncio.run(main())
