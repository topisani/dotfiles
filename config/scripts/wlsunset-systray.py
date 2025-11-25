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
    <svg xmlns="http://www.w3.org/2000/svg" height="24px" width="24px" fill="{color}">
 <path id="path6" d="M 11 3 A 8 8 0 0 0 3 11 A 8 8 0 0 0 3.8066406 14.480469 C 3.8058899 14.481065 3.8054383 14.481825 3.8046875 14.482422 C 3.8107261 14.494919 3.8200735 14.505122 3.8261719 14.517578 A 8 8 0 0 0 5.0292969 16.3125 C 5.0600161 16.347081 5.0917669 16.380058 5.1230469 16.414062 A 8 8 0 0 0 5.7988281 17.066406 C 5.8310986 17.094117 5.8618396 17.123211 5.8945312 17.150391 A 8 8 0 0 0 6.7363281 17.765625 C 6.7635091 17.782791 6.7929267 17.795663 6.8203125 17.8125 A 8 8 0 0 0 7.6074219 18.234375 C 7.6890489 18.272766 7.7705505 18.310058 7.8535156 18.345703 A 8 8 0 0 0 8.6464844 18.638672 C 8.7009152 18.655514 8.7537403 18.675712 8.8085938 18.691406 A 8 8 0 0 0 9.7636719 18.898438 C 9.8587648 18.913414 9.9548375 18.922025 10.050781 18.933594 A 8 8 0 0 0 10.949219 18.998047 C 10.96636 18.998173 10.982841 19.001936 11 19.001953 C 11.124674 19.0019 11.247172 18.988252 11.371094 18.982422 A 8 8 0 0 0 11.822266 18.957031 C 11.974953 18.941179 12.12451 18.913165 12.275391 18.888672 A 8 8 0 0 0 12.626953 18.830078 C 12.77668 18.798869 12.923015 18.756424 13.070312 18.716797 A 8 8 0 0 0 13.4375 18.615234 C 13.559059 18.576244 13.677447 18.529086 13.796875 18.484375 A 8 8 0 0 0 14.238281 18.310547 C 14.335093 18.267608 14.428399 18.218625 14.523438 18.171875 A 8 8 0 0 0 14.978516 17.933594 C 15.070537 17.880726 15.160062 17.824126 15.25 17.767578 A 8 8 0 0 0 15.685547 17.474609 C 15.766146 17.416232 15.845314 17.35639 15.923828 17.294922 A 8 8 0 0 0 16.335938 16.949219 C 16.411713 16.881185 16.485251 16.811335 16.558594 16.740234 A 8 8 0 0 0 16.931641 16.353516 C 16.971224 16.309623 17.015992 16.271431 17.054688 16.226562 C 17.052558 16.22537 17.050957 16.223849 17.048828 16.222656 A 8 8 0 0 0 19 11 A 8 8 0 0 0 11 3 z M 11 4 A 7 7 0 0 1 18 11 A 7 7 0 0 1 16.185547 15.689453 C 14.228476 14.470037 12.680836 13.155603 11.167969 12.501953 C 10.533199 12.227683 9.9046094 12.054549 9.2246094 12.037109 C 8.5445894 12.019709 7.81315 12.157893 6.96875 12.501953 C 6.2713296 12.786118 5.4895401 13.239361 4.6230469 13.863281 A 7 7 0 0 1 4 11 A 7 7 0 0 1 11 4 z M 13.5 6 A 1.5 1.5 0 0 0 12 7.5 A 1.5 1.5 0 0 0 13.5 9 A 1.5 1.5 0 0 0 15 7.5 A 1.5 1.5 0 0 0 13.5 6 z"/>
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
