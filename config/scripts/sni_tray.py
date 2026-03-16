"""Minimal StatusNotifierItem (SNI) systray implementation using dbus-fast.

Provides a simple API for creating system tray icons with menus over D-Bus,
without requiring Qt, GTK, or any GUI toolkit.

Requires: dbus-fast

Usage:
    from sni_tray import TrayIcon, MenuItem, Separator

    async def main():
        icon = TrayIcon("my-app", icon_name="application-exit", title="My App")
        icon.menu = [
            MenuItem("Click me", on_click=lambda: print("clicked")),
            Separator(),
            MenuItem("Quit", on_click=icon.stop),
        ]
        await icon.run()

    asyncio.run(main())
"""

import asyncio
import os
import signal
import struct

from dbus_fast import BusType, Message, MessageType, Variant
from dbus_fast.aio import MessageBus
from dbus_fast.constants import PropertyAccess
from dbus_fast.service import (
    ServiceInterface,
    dbus_property,
    method,
)
from dbus_fast.service import signal as dbus_signal

ITEM_PATH = "/StatusNotifierItem"
MENU_PATH = "/StatusNotifierItem/Menu"
WATCHER_BUS = "org.kde.StatusNotifierWatcher"
WATCHER_PATH = "/StatusNotifierWatcher"
WATCHER_IFACE = "org.kde.StatusNotifierWatcher"

_next_instance = 0


def _invoke(callback):
    if callback is None:
        return
    result = callback()
    if asyncio.iscoroutine(result):
        asyncio.ensure_future(result)


# ---------- Icon helpers ----------


def icon_from_svg(svg: str, sizes=(16, 32, 48)) -> list:
    """Render an SVG string to SNI IconPixmap format at multiple sizes.

    Returns a list of [width, height, argb_bytes] suitable for set_icon(pixmap=...).
    Requires cairosvg (pip install cairosvg).
    """
    import cairosvg

    result = []
    for size in sizes:
        png_data = cairosvg.svg2png(bytestring=svg.encode(), output_width=size, output_height=size)
        # cairosvg returns PNG; decode to raw RGBA then repack to ARGB network byte order
        rgba = _png_to_rgba(png_data)
        argb = bytearray(len(rgba))
        for i in range(0, len(rgba), 4):
            r, g, b, a = rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]
            struct.pack_into(">BBBB", argb, i, a, r, g, b)
        result.append([size, size, bytes(argb)])
    return result


def _png_to_rgba(data: bytes) -> bytes:
    """Decode an 8-bit RGBA PNG to raw pixel bytes. No external dependencies."""
    import zlib

    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Not a PNG file")

    pos = 8
    width = height = 0
    idat_chunks = []

    while pos < len(data):
        length = int.from_bytes(data[pos : pos + 4], "big")
        chunk_type = data[pos + 4 : pos + 8]
        chunk_data = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if chunk_type == b"IHDR":
            width = int.from_bytes(chunk_data[0:4], "big")
            height = int.from_bytes(chunk_data[4:8], "big")
            if chunk_data[8] != 8 or chunk_data[9] != 6:
                raise ValueError("Only 8-bit RGBA PNGs are supported")
        elif chunk_type == b"IDAT":
            idat_chunks.append(chunk_data)
        elif chunk_type == b"IEND":
            break

    raw = zlib.decompress(b"".join(idat_chunks))
    stride = width * 4
    pixels = bytearray(height * stride)
    src = 0

    for y in range(height):
        filt = raw[src]; src += 1
        row = y * stride
        prev = (y - 1) * stride
        for x in range(stride):
            v = raw[src]; src += 1
            a = pixels[row + x - 4] if x >= 4 else 0
            b = pixels[prev + x] if y > 0 else 0
            c = pixels[prev + x - 4] if y > 0 and x >= 4 else 0
            if filt == 1:   v = (v + a) & 0xFF
            elif filt == 2: v = (v + b) & 0xFF
            elif filt == 3: v = (v + (a + b) // 2) & 0xFF
            elif filt == 4:
                p = a + b - c
                v = (v + (a if abs(p-a) <= abs(p-b) and abs(p-a) <= abs(p-c) else b if abs(p-b) <= abs(p-c) else c)) & 0xFF
            pixels[row + x] = v

    return bytes(pixels)


# ---------- Menu model ----------


class MenuItem:
    def __init__(
        self,
        label,
        *,
        on_click=None,
        enabled=True,
        icon_name="",
        toggle_type="",
        toggle_state=-1,
        children=None,
    ):
        self.label = label
        self.on_click = on_click
        self.enabled = enabled
        self.icon_name = icon_name
        self.toggle_type = toggle_type  # "", "checkmark", "radio"
        self.toggle_state = toggle_state  # 0=off, 1=on, -1=indeterminate
        self.children = children or []
        self._id = 0


class Separator:
    def __init__(self):
        self._id = 0


# ---------- com.canonical.dbusmenu ----------


class _DBusMenuInterface(ServiceInterface):
    def __init__(self):
        super().__init__("com.canonical.dbusmenu")
        self._items: dict[int, MenuItem | Separator | None] = {}
        self._root_children: list[MenuItem | Separator] = []
        self._revision = 0
        self._on_about_to_show = None

    def set_menu(self, items):
        self._root_children = items
        self._items = {}
        next_id = 1

        def assign(item_list):
            nonlocal next_id
            for item in item_list:
                item._id = next_id
                self._items[next_id] = item
                next_id += 1
                if isinstance(item, MenuItem) and item.children:
                    assign(item.children)

        assign(items)
        self._revision += 1
        self.LayoutUpdated(self._revision, 0)

    def _item_props(self, item):
        if item is None:  # root
            return {"children-display": Variant("s", "submenu")}
        if isinstance(item, Separator):
            return {"type": Variant("s", "separator")}
        props = {"label": Variant("s", item.label)}
        if not item.enabled:
            props["enabled"] = Variant("b", False)
        if item.icon_name:
            props["icon-name"] = Variant("s", item.icon_name)
        if item.toggle_type:
            props["toggle-type"] = Variant("s", item.toggle_type)
            props["toggle-state"] = Variant("i", item.toggle_state)
        if item.children:
            props["children-display"] = Variant("s", "submenu")
        return props

    def _build_layout(self, item_id, depth, prop_names):
        item = self._items.get(item_id)
        props = self._item_props(item)
        if prop_names:
            props = {k: v for k, v in props.items() if k in prop_names}

        if depth == 0:
            child_variants = []
        else:
            children = (
                self._root_children
                if item_id == 0
                else getattr(item, "children", [])
            )
            next_depth = -1 if depth < 0 else depth - 1
            child_variants = [
                Variant(
                    "(ia{sv}av)", self._build_layout(c._id, next_depth, prop_names)
                )
                for c in children
            ]

        return [item_id, props, child_variants]

    # -- Methods --

    @method(name="GetLayout")
    def get_layout(
        self, parent_id: "i", recursion_depth: "i", property_names: "as"
    ) -> "u(ia{sv}av)":
        return [self._revision, self._build_layout(parent_id, recursion_depth, property_names)]

    @method(name="GetGroupProperties")
    def get_group_properties(self, ids: "ai", property_names: "as") -> "a(ia{sv})":
        result = []
        for item_id in ids:
            item = self._items.get(item_id)
            if item is not None or item_id == 0:
                props = self._item_props(item if item_id != 0 else None)
                if property_names:
                    props = {k: v for k, v in props.items() if k in property_names}
                result.append([item_id, props])
        return result

    @method(name="GetProperty")
    def get_property(self, id: "i", name: "s") -> "v":
        item = self._items.get(id)
        props = self._item_props(item if id != 0 else None)
        return props.get(name, Variant("s", ""))

    @method(name="Event")
    def event(self, id: "i", event_id: "s", data: "v", timestamp: "u"):
        if event_id == "clicked":
            item = self._items.get(id)
            if isinstance(item, MenuItem):
                _invoke(item.on_click)

    @method(name="EventGroup")
    def event_group(self, events: "a(isvu)") -> "ai":
        for id, event_id, data, timestamp in events:
            self.event(id, event_id, data, timestamp)
        return []

    @method(name="AboutToShow")
    def about_to_show(self, id: "i") -> "b":
        if id == 0 and self._on_about_to_show:
            old_rev = self._revision
            _invoke(self._on_about_to_show)
            return self._revision != old_rev
        return False

    @method(name="AboutToShowGroup")
    def about_to_show_group(self, ids: "ai") -> "aiai":
        updated = []
        for id in ids:
            if self.about_to_show(id):
                updated.append(id)
        return [updated, []]

    # -- Properties --

    @dbus_property(access=PropertyAccess.READ, name="Version")
    def version(self) -> "u":
        return 3

    @dbus_property(access=PropertyAccess.READ, name="TextDirection")
    def text_direction(self) -> "s":
        return "ltr"

    @dbus_property(access=PropertyAccess.READ, name="Status")
    def status(self) -> "s":
        return "normal"

    @dbus_property(access=PropertyAccess.READ, name="IconThemePath")
    def icon_theme_path(self) -> "as":
        return []

    # -- Signals --

    @dbus_signal(name="LayoutUpdated")
    def LayoutUpdated(self, revision, parent) -> "ui":
        return [revision, parent]

    @dbus_signal(name="ItemsPropertiesUpdated")
    def ItemsPropertiesUpdated(self, updated_props, removed_props) -> "a(ia{sv})a(ias)":
        return [updated_props, removed_props]


# ---------- org.kde.StatusNotifierItem ----------


class _SNIInterface(ServiceInterface):
    def __init__(self, id, title, category, icon_name, menu_path):
        super().__init__("org.kde.StatusNotifierItem")
        self._id = id
        self._title = title
        self._category = category
        self._status = "Active"
        self._icon_name = icon_name
        self._icon_pixmap = []
        self._overlay_icon_name = ""
        self._overlay_icon_pixmap = []
        self._attention_icon_name = ""
        self._attention_icon_pixmap = []
        self._tooltip = ["", [], "", ""]
        self._menu_path = menu_path
        self._item_is_menu = False
        self._on_activate = None
        self._on_secondary_activate = None
        self._on_scroll = None

    # -- Properties --

    @dbus_property(access=PropertyAccess.READ, name="Category")
    def category(self) -> "s":
        return self._category

    @dbus_property(access=PropertyAccess.READ, name="Id")
    def id(self) -> "s":
        return self._id

    @dbus_property(access=PropertyAccess.READ, name="Title")
    def title(self) -> "s":
        return self._title

    @dbus_property(access=PropertyAccess.READ, name="Status")
    def status(self) -> "s":
        return self._status

    @dbus_property(access=PropertyAccess.READ, name="WindowId")
    def window_id(self) -> "u":
        return 0

    @dbus_property(access=PropertyAccess.READ, name="IconName")
    def icon_name(self) -> "s":
        return self._icon_name

    @dbus_property(access=PropertyAccess.READ, name="IconPixmap")
    def icon_pixmap(self) -> "a(iiay)":
        return self._icon_pixmap

    @dbus_property(access=PropertyAccess.READ, name="OverlayIconName")
    def overlay_icon_name(self) -> "s":
        return self._overlay_icon_name

    @dbus_property(access=PropertyAccess.READ, name="OverlayIconPixmap")
    def overlay_icon_pixmap(self) -> "a(iiay)":
        return self._overlay_icon_pixmap

    @dbus_property(access=PropertyAccess.READ, name="AttentionIconName")
    def attention_icon_name(self) -> "s":
        return self._attention_icon_name

    @dbus_property(access=PropertyAccess.READ, name="AttentionIconPixmap")
    def attention_icon_pixmap(self) -> "a(iiay)":
        return self._attention_icon_pixmap

    @dbus_property(access=PropertyAccess.READ, name="AttentionMovieName")
    def attention_movie_name(self) -> "s":
        return ""

    @dbus_property(access=PropertyAccess.READ, name="ToolTip")
    def tooltip(self) -> "(sa(iiay)ss)":
        return self._tooltip

    @dbus_property(access=PropertyAccess.READ, name="ItemIsMenu")
    def item_is_menu(self) -> "b":
        return self._item_is_menu

    @dbus_property(access=PropertyAccess.READ, name="Menu")
    def menu(self) -> "o":
        return self._menu_path

    # -- Methods --

    @method(name="Activate")
    def activate(self, x: "i", y: "i"):
        _invoke(self._on_activate)

    @method(name="SecondaryActivate")
    def secondary_activate(self, x: "i", y: "i"):
        _invoke(self._on_secondary_activate)

    @method(name="ContextMenu")
    def context_menu(self, x: "i", y: "i"):
        pass

    @method(name="Scroll")
    def scroll(self, delta: "i", orientation: "s"):
        if self._on_scroll:
            self._on_scroll(delta, orientation)

    # -- Signals --

    @dbus_signal(name="NewTitle")
    def NewTitle(self):
        return None

    @dbus_signal(name="NewIcon")
    def NewIcon(self):
        return None

    @dbus_signal(name="NewAttentionIcon")
    def NewAttentionIcon(self):
        return None

    @dbus_signal(name="NewOverlayIcon")
    def NewOverlayIcon(self):
        return None

    @dbus_signal(name="NewToolTip")
    def NewToolTip(self):
        return None

    @dbus_signal(name="NewStatus")
    def NewStatus(self, status) -> "s":
        return status


# ---------- Public API ----------


class TrayIcon:
    """A system tray icon using the StatusNotifierItem protocol.

    Args:
        id: Application identifier (e.g. "my-app").
        icon_name: Freedesktop icon theme name.
        title: Human-readable title.
        category: One of "ApplicationStatus", "Communications", "SystemServices", "Hardware".
        on_activate: Callback for left-click activation.
        on_secondary_activate: Callback for middle-click.
        on_scroll: Callback for scroll events, receives (delta, orientation).
        item_is_menu: If True, left-click shows the menu instead of calling on_activate.
        on_menu_about_to_show: Callback invoked before the menu is shown, to allow dynamic updates.
    """

    def __init__(
        self,
        id,
        *,
        icon_name="",
        title="",
        category="ApplicationStatus",
        on_activate=None,
        on_secondary_activate=None,
        on_scroll=None,
        item_is_menu=False,
        on_menu_about_to_show=None,
    ):
        global _next_instance
        _next_instance += 1
        self._bus_name = (
            f"org.freedesktop.StatusNotifierItem-{os.getpid()}-{_next_instance}"
        )

        self._dbusmenu = _DBusMenuInterface()
        self._dbusmenu._on_about_to_show = on_menu_about_to_show
        self._sni = _SNIInterface(id, title, category, icon_name, MENU_PATH)
        self._sni._on_activate = on_activate
        self._sni._on_secondary_activate = on_secondary_activate
        self._sni._on_scroll = on_scroll
        self._sni._item_is_menu = item_is_menu

        self._bus = None
        self._stop_event = asyncio.Event()

    @property
    def menu(self):
        return self._dbusmenu._root_children

    @menu.setter
    def menu(self, items):
        self._dbusmenu.set_menu(items)

    def set_icon(self, name=None, pixmap=None):
        """Update the tray icon. Accepts a theme name and/or ARGB32 pixmap data."""
        if name is not None:
            self._sni._icon_name = name
        if pixmap is not None:
            self._sni._icon_pixmap = pixmap
        self._sni.NewIcon()

    def set_title(self, title):
        self._sni._title = title
        self._sni.NewTitle()

    def set_tooltip(self, title, description="", icon_name=""):
        self._sni._tooltip = [icon_name, [], title, description]
        self._sni.NewToolTip()

    def set_status(self, status):
        """Set status: "Passive", "Active", or "NeedsAttention"."""
        self._sni._status = status
        self._sni.NewStatus(status)

    async def setup(self):
        """Connect to the session bus, export interfaces, and register with the watcher."""
        self._bus = await MessageBus(bus_type=BusType.SESSION).connect()
        self._bus.export(ITEM_PATH, self._sni)
        self._bus.export(MENU_PATH, self._dbusmenu)
        await self._bus.request_name(self._bus_name)

        reply = await self._bus.call(
            Message(
                destination=WATCHER_BUS,
                path=WATCHER_PATH,
                interface=WATCHER_IFACE,
                member="RegisterStatusNotifierItem",
                signature="s",
                body=[self._bus_name],
            )
        )
        if reply.message_type == MessageType.ERROR:
            raise RuntimeError(
                f"Failed to register with StatusNotifierWatcher: {reply.body}"
            )

    async def run(self):
        """Setup and block until stop() is called or a signal is received."""
        await self.setup()
        loop = asyncio.get_event_loop()
        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(sig, self.stop)
        await self._stop_event.wait()

    def stop(self):
        """Stop the tray icon and disconnect from the bus."""
        self._stop_event.set()
        if self._bus:
            self._bus.disconnect()
