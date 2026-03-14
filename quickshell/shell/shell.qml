//@ pragma UseQApplication

pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.bar
import qs.modules.osd
import qs.modules.controlcenter
import qs.modules.common
import qs.modules.notifications
import qs.services

ShellRoot {
    id: root
    signal showPopup(anchor: Item, widget: var, props: var)
    signal popupClosed()
    property bool barHidden: false
    property alias ccOpen: cc.shouldShow

    BarPopupWindow {
        id: barPopup
        onPopupOpenChanged: {
            if (!popupOpen) root.popupClosed();
        }
        Connections {
            target: root
            function onShowPopup(anchor, widget, props) {
                barPopup.showPopup(anchor, widget, props);
            }
        }
    }

    Variants {
        model: Quickshell.screens

        LazyLoader {
            active: true
            required property var modelData;
            Bar {
                id: bar
                size: Config.bar.size
                color: Config.theme.color.background
                hidden: root.barHidden
                screen: modelData
                ccOpen: root.ccOpen
                onShowPopup: (anchor, widget, properties) => {
                    root.showPopup(anchor, widget, properties);
                }

                onSetCcOpen: (open) => {
                    root.ccOpen = open
                }

                Connections {
                    target: root
                    function onPopupClosed() {
                        bar.popupOpen = false;
                    }
                }
            }
        }
    }

    ControlCenter {
        id: cc
        onShouldShowChanged: {
            Notifications.showPopups = !cc.shouldShow
        }
    }

    Osd {}

    NotificationPopup {
        id: notificationPopup
    }

    IpcHandler {
        target: "shell"

        function toggleBar() {
            root.barHidden = !root.barHidden
        }

        function toggleCC() {
            root.ccOpen = !root.ccOpen
        }
    }
}
