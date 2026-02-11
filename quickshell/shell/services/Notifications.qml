pragma Singleton
import Quickshell
import Quickshell.Services.Notifications as QsNotif
import QtQuick
import qs.modules.common

Singleton {
    id: root

    property bool doNotDisturb: false
    property bool showPopups: true

    signal notification(n: Notification)

    // property alias notifications: root.server.trackedNotifications
    property ListModel notifications: ListModel {}

    function getImage(n: Notification): string {
        // Niri screenshot notifications send screenshot as appIcon instead of image
        if (n.appName == "niri") {
            return n.appIcon;
        }
        // Networkmananger sends its icons as images
        if (n.desktopEntry == "org.freedesktop.network-manager-applet") {
            return "";
        }
        return n.image;
    }

    function getAppIcon(n: Notification): string {
        // Niri screenshot notifications send screenshot as appIcon instead of image
        if (n.appName == "niri") {
            return "";
        }
        // Networkmananger sends its icons as images
        if (n.desktopEntry == "org.freedesktop.network-manager-applet") {
            return n.image;
        }
        return n.appIcon;
    }
    
    function dismissAll() {
        for (let i = notifications.count - 1; i >= 0; i--) {
            notifications.get(i).modelData.dismiss();
        }
    }

    Component {
        id: notificationWrapper
        Notification {}
    }

    QsNotif.NotificationServer {
        id: server
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true
        persistenceSupported: true
        bodyMarkupSupported: true

        onNotification: notification => {
            notification.tracked = true;
            // if (!notification.lastGeneration || (notification.timestamp == null)) {
            //     notification.timestamp = new Date();
            // }
            // notification.showPopup = true
            let obj = notificationWrapper.createObject(notification, {
                "base": notification
            });
            
            obj.closed.connect(() => {
                for (let i = 0; i < root.notifications.count; i++) {
                    if (root.notifications.get(i).modelData === obj) {
                        root.notifications.remove(i)
                        break
                    }
                }
            })
            
            root.notifications.insert(0, { modelData: obj })
            if (!notification.lastGeneration) {
                root.notification(obj);
            }
        }
    }

    component Notification: QtObject {
        id: nroot
        required property QsNotif.Notification base
        
        property var lock: RetainableLock {
            object: nroot.base
            locked: true
        }

        // Aliases
        property int id: base.id
        property list<QsNotif.NotificationAction> actions: base.actions
        property string summary: base.summary
        property string body: base.body
        // property real expireTimeout: base.expireTimeout
        property bool hasInlineReply: base.hasInlineReply
        property var hints: base.hints
        property string inlineReplyPlaceholder: base.inlineReplyPlaceholder
        property int urgency: base.urgency
        property bool hasActionIcons: base.hasActionIcons
        // property bool transient: base.transient
        property string appName: base.appName
        property string appIcon: base.appIcon
        property string desktopEntry: base.desktopEntry
        property bool lastGeneration: base.lastGeneration
        property bool resident: base.resident
        property string image: base.image

        // Extra properties
        property date timestamp: new Date()
        property bool showPopup: !lastGeneration
        property real expireTimeout: base.expireTimeout < 0 ? Config.notifications.popupExpireSeconds : base.expireTimeout

        signal closed

        function dismiss() {
            base.dismiss();
        }

        function dismissPopup() {
            showPopup = false;
            if (base.transient) {
                dismiss();
            }
        }
        
        function _notificationUpdated() {
            timestamp = new Date()
            showPopup = true
            timer.restart()
        }

        property Connections baseConnections: Connections {
            target: nroot.base
            
            function onHintsChanged() {
                nroot._notificationUpdated()
            }
            
            function onBodyChanged() {
                nroot._notificationUpdated()
            }
            
            function onSummaryChanged() {
                nroot._notificationUpdated()
            }

            function onClosed() {
                nroot.closed();
            }
        }

        property Timer timer: Timer {
            interval: nroot.expireTimeout * 1000
            running: nroot.expireTimeout > 0
            onTriggered: {
                nroot.showPopup = false;
                if (nroot.base.transient) {
                    nroot.base.expire();
                }
            }
        }
    }
}
