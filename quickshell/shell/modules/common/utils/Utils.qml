pragma Singleton
import Quickshell

Singleton {
    id: root

    function formatTimestamp(timestamp) {
        if (!timestamp)
            return "Unknown";

        const now = new Date();
        const notifDate = new Date(timestamp);
        const seconds = Math.floor((now - notifDate) / 1000);

        // Less than 1 hour: show "x minutes ago"
        if (seconds < 3600) {
            const minutes = Math.floor(seconds / 60);
            if (minutes === 0) {
                return "now";
            }
            return minutes + "m ago";
        }
        
        // Check if same day
        const isToday = now.getFullYear() === notifDate.getFullYear() && now.getMonth() === notifDate.getMonth() && now.getDate() === notifDate.getDate();

        if (isToday) {
            // Show time (e.g., "14:30" or "2:30 PM")
            return notifDate.toLocaleTimeString(Qt.locale(), "hh:mm");
        } else {
            // Show date (e.g., "Dec 1" or "12/01")
            return notifDate.toLocaleDateString(Qt.locale(), "MMM d");
        }
    }
}
