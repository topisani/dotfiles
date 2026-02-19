#!/bin/python
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('AppIndicator3', '0.1')
from gi.repository import Gtk, AppIndicator3, GLib
import subprocess
import logging
import signal
import os
import urllib.request

# Configure logging
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

PROFILES_PER_PAGE = 25
# ICON_URL = "https://raw.githubusercontent.com/FrameworkComputer/tuned-gui/main/images/logo_white_targeted.png"
# ICON_PATH = os.path.expanduser("~/.local/share/icons/tuned_logo.png")  # Path to save the downloaded icon
ICON_PATH="battery-profile-balanced"

class TunedIndicator:
    def __init__(self):
        # Verify 'tuned-adm' command availability
        if not self.command_exists('tuned-adm'):
            logging.error("'tuned-adm' command not found. Make sure 'tuned' is installed.")
            return
        
        # Download the PNG icon
        # self.download_icon(ICON_URL, ICON_PATH)

        # Initialize the AppIndicator with the PNG icon
        self.indicator = AppIndicator3.Indicator.new(
            "tuned-indicator",
            ICON_PATH,
            AppIndicator3.IndicatorCategory.SYSTEM_SERVICES)
        self.indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
        
        self.current_page = 0  # Current page for pagination
        self.indicator.set_menu(self.create_menu())

        # Initial update to ensure system is ready
        self.update_menu_items()

        # Setup signal handlers for system events
        signal.signal(signal.SIGUSR1, self.handle_signal)
        signal.signal(signal.SIGUSR2, self.handle_signal)

    def command_exists(self, cmd):
        """Check if a command exists."""
        return subprocess.call(f"type {cmd}", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE) == 0

    def download_icon(self, url, path):
        """Download the icon from the specified URL and save it to the specified path."""
        try:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            urllib.request.urlretrieve(url, path)
            logging.info(f"Icon downloaded successfully: {path}")
        except Exception as e:
            logging.error(f"Failed to download icon: {e}")

    def create_menu(self):
        """Create the indicator menu and populate it with profile items and controls."""
        self.menu = Gtk.Menu()
        self.menu.set_size_request(300, -1)  # Set the minimum width of the menu
        return self.menu

    def get_profiles(self):
        """Retrieve the list of available profiles using the 'tuned-adm list' command."""
        try:
            output = subprocess.check_output(['tuned-adm', 'list'], stderr=subprocess.STDOUT, text=True)
            profiles = [line.strip('- ').split(' - ')[0].strip() for line in output.split('\n') if line.startswith('- ')]
            logging.debug(f"Profiles retrieved: {profiles}")
            return profiles
        except subprocess.CalledProcessError as e:
            logging.error(f"Error getting profiles: {e.output}")
            return []

    def get_active_profile(self):
        """Retrieve the current active profile using the 'tuned-adm active' command."""
        try:
            output = subprocess.check_output(['tuned-adm', 'active'], stderr=subprocess.STDOUT, text=True)
            if "No current active profile" in output:
                return None
            else:
                # Extract the profile name
                active_profile = output.split(':', 1)[1].strip().split()[0]
                logging.debug(f"Active profile detected: {active_profile}")
                return active_profile
        except subprocess.CalledProcessError as e:
            logging.error(f"Error getting active profile: {e.output}")
            return None

    def normalize_profile_name(self, profile):
        """Normalize profile name by removing trailing hyphen."""
        if profile == 'intel-best_power_efficiency_mode- Intel epp 70 TuneD profile':
            return 'intel-best_power_efficiency_mode'
        return profile

    def update_menu_items(self):
        """Update the indicator menu with the current set of profiles and pagination controls."""
        # Clear existing menu items
        for item in self.menu.get_children():
            self.menu.remove(item)

        profiles = self.get_profiles()
        active_profile = self.get_active_profile()
        logging.debug(f"Updating menu items. Active profile: {active_profile}")
        start = self.current_page * PROFILES_PER_PAGE
        end = min(start + PROFILES_PER_PAGE, len(profiles))
        current_profiles = profiles[start:end]

        # Add profile items to the menu
        for profile in current_profiles:
            logging.debug(f"Adding profile to menu: {profile}")
            item = Gtk.CheckMenuItem(label=profile)
            item.set_size_request(300, -1)  # Set the minimum width of each menu item
            normalized_profile = self.normalize_profile_name(profile)
            if normalized_profile == active_profile:
                item.set_active(True)
                logging.debug(f"Set active profile: {profile}")
            item.set_tooltip_text(profile)  # Ensure the full profile name is visible
            item.connect('activate', self.on_profile_click, profile)
            self.menu.append(item)
            item.show_all()

        # Add pagination controls if needed
        if self.current_page > 0:
            prev_item = Gtk.MenuItem(label="Previous")
            prev_item.connect('activate', self.on_prev_page)
            self.menu.append(prev_item)
            prev_item.show_all()

        if end < len(profiles):
            next_item = Gtk.MenuItem(label="Next")
            next_item.connect('activate', self.on_next_page)
            self.menu.append(next_item)
            next_item.show_all()

        separator = Gtk.SeparatorMenuItem()
        self.menu.append(separator)
        separator.show_all()

        # Add option to turn off the applet
        off_item = Gtk.MenuItem(label="Turn Off Applet")
        off_item.connect('activate', self.on_turn_off_applet_click)
        self.menu.append(off_item)
        off_item.show_all()

        self.menu.show_all()

    def on_prev_page(self, widget):
        """Handle the 'Previous' button click to show the previous page of profiles."""
        if self.current_page > 0:
            self.current_page -= 1
            self.update_menu_items()

    def on_next_page(self, widget):
        """Handle the 'Next' button click to show the next page of profiles."""
        profiles = self.get_profiles()
        if (self.current_page + 1) * PROFILES_PER_PAGE < len(profiles):
            self.current_page += 1
            self.update_menu_items()

    def on_profile_click(self, widget, profile):
        """Handle profile menu item click to switch to the selected profile."""
        if widget.get_active():
            # Use the correct profile name
            normalized_profile = self.normalize_profile_name(profile)
            logging.debug(f"Attempting to switch to profile: {normalized_profile} (original: {profile})")
            try:
                # Use the correct profile name
                command = ['tuned-adm', 'profile', normalized_profile]
                logging.debug(f"Running command: {command}")
                subprocess.check_output(command, stderr=subprocess.STDOUT, text=True)
                logging.info(f"Successfully switched to profile: {normalized_profile}")
                # Update the menu items to reflect the new active profile
                self.update_menu_items()
            except subprocess.CalledProcessError as e:
                logging.error(f"Failed to switch profile: {e.output}")

    def on_turn_off_applet_click(self, widget):
        """Handle the 'Turn Off Applet' menu item click to exit the applet."""
        logging.info("Turning off the applet")
        os._exit(0)  # Exit the applet

    def handle_signal(self, signum, frame):
        """Handle signals to update the active profile."""
        if signum in (signal.SIGUSR1, signal.SIGUSR2):
            self.update_menu_items()

if __name__ == "__main__":
    # Initialize and run the applet
    try:
        indicator = TunedIndicator()
        Gtk.main()
    except Exception as e:
        logging.error(f"Error initializing the TunedIndicator: {e}")

