#!/usr/bin/env python3
"""
Wayland Color Temperature Control System Tray Application
Controls screen color temperature using wlr-gamma-control protocol
"""

import sys
import subprocess
import math
import signal
from PySide6.QtWidgets import QApplication, QSystemTrayIcon, QMenu
from PySide6.QtGui import QIcon, QAction
from PySide6.QtCore import QTimer
from PySide6.QtSvg import QSvgRenderer
from PySide6.QtGui import QPixmap, QPainter


def icon_svg(color):
    return f"""
    <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="{color}">
        <path d="M560-80q-82 0-155-31.5t-127.5-86Q223-252 191.5-325T160-480q0-83 31.5-155.5t86-127Q332-817 405-848.5T560-880q54 0 105 14t95 40q-91 53-145.5 143.5T560-480q0 112 54.5 202.5T760-134q-44 26-95 40T560-80Zm0-80h21q10 0 19-2-57-66-88.5-147.5T480-480q0-89 31.5-170.5T600-798q-9-2-19-2h-21q-133 0-226.5 93.5T240-480q0 133 93.5 226.5T560-160Zm-80-320Z"/>
    </svg>"""

def svg_to_qicon(svg_string):
    """Convert SVG string to QIcon"""
    renderer = QSvgRenderer(svg_string.encode())
    pixmap = QPixmap(64, 64)
    pixmap.fill(0x00000000)  # Transparent background
    painter = QPainter(pixmap)
    renderer.render(painter)
    painter.end()
    return QIcon(pixmap)

class ColorTempController:
    """Handles color temperature adjustments via wlr-gamma-control"""

    def __init__(self, temp=5500):
        self.target_temp = temp
        self.enabled = False

    def set_temperature(self, temp):
        """Apply color temperature using wlsunset"""
        try:
            # Kill any existing wlsunset instances
            subprocess.run(["pkill", "-9", "wlsunset"], capture_output=True)

            # Start wlsunset with fixed temperature
            # High temp needs to be temp+1 to avoid errors
            subprocess.Popen(
                ["wlsunset", "-T", str(temp + 1), "-t", str(temp)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            return True
        except FileNotFoundError:
            return False

    def reset_temperature(self):
        """Reset to default temperature (6500K)"""
        try:
            subprocess.run(["pkill", "-9", "wlsunset"], capture_output=True)
            return True
        except FileNotFoundError:
            return False

    def enable(self):
        """Enable color temperature adjustment"""
        self.enabled = True
        return self.set_temperature(self.target_temp)

    def disable(self):
        """Disable and reset to default"""
        self.enabled = False
        return self.reset_temperature()


class ColorTempTray(QSystemTrayIcon):
    """System tray application for color temperature control"""

    def __init__(self, parent=None):
        super().__init__(parent)

        # Initialize controller with warm temperature
        self.controller = ColorTempController()
        self.icon_off = svg_to_qicon(icon_svg("#777777"))
        self.icon_on = svg_to_qicon(icon_svg("#FFFFFF"))

        # Set initial icon (disabled state) - using Breeze icons
        self.setIcon(self.icon_off)

        # Create menu
        self.menu = QMenu()

        # Toggle action
        self.toggle_action = QAction("Night Light", self.menu)
        self.toggle_action.setCheckable(True)
        self.toggle_action.setChecked(False)
        self.toggle_action.triggered.connect(self.toggle_temperature)
        self.menu.addAction(self.toggle_action)

        self.menu.addSeparator()

        # Temperature submenu
        temp_menu = self.menu.addMenu("Temperature")

        temperatures = [
            ("Very Warm (2700K)", 2700),
            ("Warm (3400K)", 3400),
            ("Medium (4500K)", 4500),
            ("Cool (5500K)", 5500),
        ]

        for label, temp in temperatures:
            action = QAction(label, temp_menu)
            action.setData(temp)
            action.triggered.connect(lambda checked, t=temp: self.set_temp(t))
            temp_menu.addAction(action)

        self.menu.addSeparator()

        # Quit action
        quit_action = QAction("Quit", self.menu)
        quit_action.triggered.connect(self.quit_app)
        self.menu.addAction(quit_action)

        self.setContextMenu(self.menu)

        # Connect click to toggle
        self.activated.connect(self.on_tray_activated)

        # Show tray icon
        self.setVisible(True)
        self.setToolTip("Color Temperature Control (Disabled)")

    def on_tray_activated(self, reason):
        """Handle tray icon activation"""
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            # Left click toggles
            self.toggle_action.setChecked(not self.toggle_action.isChecked())
            self.toggle_temperature(self.toggle_action.isChecked())

    def toggle_temperature(self, checked):
        """Toggle color temperature on/off"""
        if checked:
            success = self.controller.enable()
            if success:
                self.setIcon(self.icon_on)
                self.setToolTip(
                    f"Color Temperature Control (Enabled - {self.controller.target_temp}K)"
                )
                self.toggle_action.setText("Night Light")
            else:
                self.toggle_action.setChecked(False)
                self.showMessage(
                    "Error",
                    "Failed to enable color temperature.\nPlease install wlsunset.",
                    QSystemTrayIcon.MessageIcon.Critical,
                )
        else:
            self.controller.disable()
            self.setIcon(self.icon_off)
            self.setToolTip("Color Temperature Control (Disabled)")
            self.toggle_action.setText("Enable Night Light")

    def set_temp(self, temp):
        """Change target temperature"""
        self.controller.target_temp = temp
        if self.controller.enabled:
            self.controller.set_temperature(temp)
            self.setToolTip(f"Color Temperature Control (Enabled - {temp}K)")

    def quit_app(self):
        """Clean up and quit"""
        if self.controller.enabled:
            self.controller.disable()
        QApplication.quit()


def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    app = QApplication(sys.argv)

    # Ensure the app doesn't quit when the last window is closed
    app.setQuitOnLastWindowClosed(False)

    # Check if system tray is available
    if not QSystemTrayIcon.isSystemTrayAvailable():
        print("System tray is not available on this system.")
        sys.exit(1)

    # Create and show tray icon
    tray = ColorTempTray()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
