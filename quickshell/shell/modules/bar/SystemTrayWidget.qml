pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.SystemTray
import qs.modules.common.widgets

RowLayout {
    id: root
    spacing: 10
    property real size: 20

    Repeater {
        model: SystemTray.items

        MouseArea {
            id: trayItem
            width: root.size
            height: root.size
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            scrollGestureEnabled: true

            required property var modelData
            property var item: modelData

            visible: item.status != Status.Passive

            // Tray icon
            IconImage {
                anchors.centerIn: parent
                width: root.size
                height: root.size
                source: trayItem.item.icon
                smooth: true
            }

            // Tooltip
            PopupToolTip {
                anchor.item: trayItem
                anchor.edges: Edges.Bottom | Edges.Right
                visible: trayItem.containsMouse
                text: (trayItem.item.tooltipTitle || trayItem.item.title || "") + (trayItem.item.tooltipDescription ? "\n" + trayItem.item.tooltipDescription : "")
                delay: 500
            }

            // Handle clicks
            onClicked: function (mouse) {
                console.debug(item.title);
                if (mouse.button === Qt.RightButton || trayItem.item.onlyMenu) {
                    menuAnchor.open();
                } else if (mouse.button === Qt.LeftButton) {
                    trayItem.item.activate();
                }
            }

            onWheel: function (wheel) {
                if (wheel.y != 0) {
                    trayItem.item.scroll(wheel.y, false);
                }
            }

            QsMenuAnchor {
                id: menuAnchor
                anchor.item: trayItem
                anchor.edges: Edges.Bottom | Edges.Right
                menu: trayItem.item.menu
            }

            // Visual feedback on hover
            Rectangle {
                anchors.fill: parent
                color: "#313244"
                radius: 4
                opacity: parent.containsMouse ? 0.3 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }
        }
    }
}
