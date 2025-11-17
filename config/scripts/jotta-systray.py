#!/usr/bin/env -S uv run
# /// script
# dependencies = [
#     "pyside6",
# ]
# ///

import sys
import subprocess
import signal
import json
from datetime import datetime
from pathlib import Path

from PySide6.QtWidgets import QApplication, QSystemTrayIcon, QMenu
from PySide6.QtGui import QIcon, QAction
from PySide6.QtCore import QTimer
from PySide6.QtSvg import QSvgRenderer
from PySide6.QtGui import QPixmap, QPainter

# Embedded SVG icons
def icon_svg(color):
    return f'''<?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 2 36 36">
        <path fill="{color}" d="M25.699 7v17.334a8.72 8.72 0 0 1-2.51 6.128A8.52 8.52 0 0 1 17.133 33h-3.427V15.667a8.72 8.72 0 0 1 2.51-6.129A8.52 8.52 0 0 1 22.271 7zM0 20.867h3.427c2.272 0 4.45.913 6.058 2.538a8.72 8.72 0 0 1 2.509 6.128V33H8.567a8.52 8.52 0 0 1-6.058-2.538A8.72 8.72 0 0 1 0 24.334z"></path>
        </svg>'''

UPDATE_INTERVAL_MS = 3000
ICON_IDLE = icon_svg("#999999")
ICON_SYNCING = icon_svg("#7D5FE6")

class JottaIndicator:
    def __init__(self):
        self.app = QApplication(sys.argv)
        self.app.setQuitOnLastWindowClosed(False)

        self.status_data = None
        self.auto_sync_enabled = False
        self.recent_files = []

        # Create icons from SVG
        self.icon_idle = self.svg_to_qicon(ICON_IDLE)
        self.icon_syncing = self.svg_to_qicon(ICON_SYNCING)

        # Create system tray icon
        self.tray_icon = QSystemTrayIcon(self.icon_idle, self.app)
        self.tray_icon.setToolTip("Jotta CLI - Checking...")

        # Create menu
        self.menu = QMenu()

        self.status_action = QAction("Status: Checking...", self.menu)
        self.status_action.setEnabled(False)
        self.menu.addAction(self.status_action)

        self.upload_action = QAction("", self.menu)
        self.upload_action.setEnabled(False)
        self.upload_action.setVisible(False)
        self.menu.addAction(self.upload_action)

        self.download_action = QAction("", self.menu)
        self.download_action.setEnabled(False)
        self.download_action.setVisible(False)
        self.menu.addAction(self.download_action)

        self.last_sync_action = QAction("Last sync: Unknown", self.menu)
        self.last_sync_action.setEnabled(False)
        self.menu.addAction(self.last_sync_action)

        self.menu.addSeparator()

        open_folder_action = QAction("Open Sync Folder", self.menu)
        open_folder_action.triggered.connect(self.on_open_folder)
        self.menu.addAction(open_folder_action)

        open_webapp_action = QAction("Open Jottacloud Web", self.menu)
        open_webapp_action.triggered.connect(self.on_open_webapp)
        self.menu.addAction(open_webapp_action)

        self.menu.addSeparator()

        self.toggle_action = QAction("Enable Automatic Sync", self.menu)
        self.toggle_action.triggered.connect(self.on_toggle_auto_sync)
        self.menu.addAction(self.toggle_action)

        self.trigger_action = QAction("Sync Now", self.menu)
        self.trigger_action.triggered.connect(self.on_trigger_sync)
        self.menu.addAction(self.trigger_action)

        self.menu.addSeparator()

        self.recent_files_placeholder = self.menu.addSeparator()
        self.menu.aboutToShow.connect(self.on_menu_about_to_show)

        # quit_action = QAction("Quit", self.menu)
        # quit_action.triggered.connect(self.on_quit)
        # self.menu.addAction(quit_action)

        self.tray_icon.setContextMenu(self.menu)
        self.tray_icon.show()

        # Setup timer for periodic updates
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_status)
        self.timer.start(UPDATE_INTERVAL_MS)

        # Initial update
        self.update_status()

    def svg_to_qicon(self, svg_string):
        """Convert SVG string to QIcon"""
        renderer = QSvgRenderer(svg_string.encode())
        pixmap = QPixmap(64, 64)
        pixmap.fill(0x00000000)  # Transparent background
        painter = QPainter(pixmap)
        renderer.render(painter)
        painter.end()
        return QIcon(pixmap)

    def get_sync_status(self):
        """Get sync status from jotta-cli status --json"""
        try:
            result = subprocess.run(
                ["jotta-cli", "status", "--json"],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0:
                return json.loads(result.stdout)
            else:
                return None
        except subprocess.TimeoutExpired:
            return None
        except FileNotFoundError:
            return None
        except json.JSONDecodeError:
            return None
        except Exception:
            return None

    def get_recent_files(self, count=5):
        """Get recent sync log entries"""
        try:
            result = subprocess.run(
                ["jotta-cli", "sync", "log", "-n", str(count)],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0:
                files = []
                for line in result.stdout.strip().split('\n'):
                    if '::' in line:
                        parts = line.split(' :: ', 1)
                        if len(parts) == 2:
                            timestamp_str, file_info = parts
                            # Extract action and path
                            if ' ' in file_info:
                                action, filepath = file_info.split(' ', 1)
                                files.append({
                                    'timestamp': timestamp_str.strip(),
                                    'action': action.strip(),
                                    'path': filepath.strip()
                                })
                return files
            return []
        except subprocess.TimeoutExpired:
            return []
        except FileNotFoundError:
            return []
        except Exception:
            return []

    
    def truncate_filename(self, path, max_length=50):
        """Truncate long filenames intelligently"""
        if len(path) <= max_length:
            return path
        
        # Try to keep the filename and truncate the path
        parts = path.split('/')
        filename = parts[-1]
        
        if len(filename) > max_length - 3:
            # Even filename is too long, truncate it
            return "..." + filename[-(max_length - 3):]
        
        # Build path from end until we run out of space
        remaining = max_length - len(filename) - 4  # 4 for ".../"
        path_parts = []
        
        for part in reversed(parts[:-1]):
            if len('/'.join(path_parts + [part])) <= remaining:
                path_parts.insert(0, part)
            else:
                break
        
        if path_parts:
            return "[...]/" + '/'.join(path_parts) + '/' + filename
        else:
            return "[...]/" + filename
    
    def on_menu_about_to_show(self):
        """Called when menu is about to be shown - update recent files"""
        # Remove old recent file actions
        for action in self.recent_files:
            self.menu.removeAction(action)
        self.recent_files = []
        
        # Get and add new recent files
        recent = self.get_recent_files(5)
        for file_info in recent:
            action_time = self.format_time_ago(datetime.strptime(file_info['timestamp'].split('.')[0], "%Y-%m-%d %H:%M:%S"))
            action_icon = "↓" if file_info['action'] == "Download" else "↑"
            truncated = self.truncate_filename(file_info['path'])
            action = QAction(f"{action_time} {action_icon} {truncated}", self.menu)
            # action.setEnabled(False)
            action.setToolTip(file_info['path'])  # Full path in tooltip
            self.menu.insertAction(self.recent_files_placeholder, action)
            self.recent_files.append(action)

    def format_bytes(self, bytes_val):
        """Format bytes to human readable string"""
        if bytes_val < 1024:
            return f"{bytes_val} B"
        elif bytes_val < 1024 * 1024:
            return f"{bytes_val / 1024:.1f} KB"
        elif bytes_val < 1024 * 1024 * 1024:
            return f"{bytes_val / (1024 * 1024):.1f} MB"
        else:
            return f"{bytes_val / (1024 * 1024 * 1024):.2f} GB"

    def format_time_ago(self, timestamp):
        """Format timestamp to relative time"""
        try:
            now = datetime.now()
            diff = now - timestamp

            seconds = diff.total_seconds()

            if seconds < 60:
                return "just now"
            elif seconds < 3600:
                minutes = int(seconds / 60)
                return f"{minutes}m ago"
            elif seconds < 86400:
                hours = int(seconds / 3600)
                return f"{hours}h ago"
            else:
                days = int(seconds / 86400)
                return f"{days}d ago"
        except Exception:
            return "Unknown"

    def enable_auto_sync(self):
        try:
            subprocess.run(["jotta-cli", "sync", "start"], timeout=5)
            return True
        except Exception:
            return False

    def disable_auto_sync(self):
        try:
            subprocess.run(["jotta-cli", "sync", "stop"], timeout=5)
            return True
        except Exception:
            return False

    def on_toggle_auto_sync(self):
        if self.auto_sync_enabled:
            self.disable_auto_sync()
        else:
            self.enable_auto_sync()
        # Force immediate update
        self.update_status()

    def on_trigger_sync(self):
        try:
            subprocess.run(["jotta-cli", "sync", "trigger"], timeout=5)
            return True
        except Exception:
            return False
        # Force immediate update
        self.update_status()

    def on_open_folder(self):
        """Open the Jottacloud sync folder in file browser"""
        if self.status_data:
            root_path = self.status_data.get("Sync", {}).get("RootPath", "")
            if root_path and Path(root_path).exists():
                subprocess.Popen(["xdg-open", root_path])

    def on_open_webapp(self):
        """Open Jottacloud web interface"""
        subprocess.Popen(["xdg-open", "https://www.jottacloud.com/web"])

    def update_status(self):
        status_data = self.get_sync_status()

        if status_data is None:
            self.status_action.setText("Status: Error")
            self.tray_icon.setToolTip("Jotta CLI - Error")
            self.tray_icon.setIcon(self.icon_idle)
            self.upload_action.setVisible(False)
            self.download_action.setVisible(False)
            return

        self.status_data = status_data

        # Get sync state
        sync_enabled = status_data.get("Sync", {}).get("Enabled", False)
        auto_sync = status_data.get("Sync", {}).get("Automatic", False)
        self.auto_sync_enabled = auto_sync

        # Get transfer state
        state = status_data.get("State", {})
        uploading = state.get("Uploading", {})
        downloading = state.get("Downloading", {})

        is_uploading = bool(uploading)
        is_downloading = bool(downloading)

        # Determine overall status
        if not sync_enabled:
            status_text = "Sync Disabled"
            icon = self.icon_idle
        elif is_uploading or is_downloading:
            status_text = "Syncing"
            icon = self.icon_syncing
        elif auto_sync:
            status_text = "Up to date"
            icon = self.icon_syncing
        else:
            status_text = "Paused"
            icon = self.icon_idle

        # Update main status
        self.status_action.setText(f"Status: {status_text}")
        self.tray_icon.setToolTip(f"Jotta CLI - {status_text}")
        self.tray_icon.setIcon(icon)

        # Update upload action
        if is_uploading:
            upload_info = []
            for filename, file_data in uploading.items():
                size = file_data.get("Size", 0)
                progress = file_data.get("Progress", 0)
                upload_info.append(f"{filename} ({progress}/{size})")

            if upload_info:
                self.upload_action.setText(f"↑ Uploading: {upload_info[0]}")
                self.upload_action.setVisible(True)
            else:
                self.upload_action.setText("↑ Uploading...")
                self.upload_action.setVisible(True)
        else:
            self.upload_action.setVisible(False)

        # Update download action
        if is_downloading:
            download_info = []
            for filename, file_data in downloading.items():
                size = file_data.get("Size", 0)
                progress = file_data.get("Progress", 0)
                download_info.append(f"{filename} ({progress}/{size})")

            if download_info:
                self.download_action.setText(f"↓ Downloading: {download_info[0]}")
                self.download_action.setVisible(True)
            else:
                self.download_action.setText("↓ Downloading...")
                self.download_action.setVisible(True)
        else:
            self.download_action.setVisible(False)

        # Update toggle action
        if auto_sync:
            self.toggle_action.setText("Disable Automatic Sync")
        else:
            self.toggle_action.setText("Enable Automatic Sync")

        # Update last sync time
        last_update_ms = status_data.get("Sync", {}).get("LastUpdateMS", 0)
        if last_update_ms > 0:
            time_ago = self.format_time_ago(datetime.fromtimestamp(last_update_ms/ 1000))
            self.last_sync_action.setText(f"Last sync: {time_ago}")
        else:
            self.last_sync_action.setText("Last sync: Unknown")

    def on_quit(self):
        self.timer.stop()
        self.tray_icon.hide()
        self.app.quit()

    def run(self):
        sys.exit(self.app.exec())

if __name__ == "__main__":
    # Enable Ctrl+C to work
    signal.signal(signal.SIGINT, signal.SIG_DFL)

    indicator = JottaIndicator()
    indicator.run()
