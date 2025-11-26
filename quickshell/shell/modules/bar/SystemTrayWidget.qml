pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.modules.common.widgets
import qs.modules.controlcenter

RowLayout {
    id: root
    spacing: 10
    property real size: 20

    signal showPopup(Item anchor, var popupContent, var properties)

    Repeater {
        model: SystemTray.items

        MouseArea {
            id: trayItem
            // implicitWidth: root.size
            implicitWidth: row.width
            implicitHeight: root.size
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            scrollGestureEnabled: true

            required property var modelData
            property var item: modelData

            visible: item.status != Status.Passive

            RowLayout {
                id: row
                // Tray icon
                SystemIcon {
                    // anchors.centerIn: parent
                    size: root.size
                    source: trayItem.item.icon
                }
                // Text {
                //     text: trayItem.item.tooltipTitle
                //     color: Config.theme.color.text
                //     font: Config.bar.font
                // }
            }

            // Tooltip
            PopupToolTip {
                id: tooltip
                anchor.item: trayItem
                anchor.edges: Edges.Bottom | Edges.Right
                visible: trayItem.containsMouse
                text: (trayItem.item.tooltipTitle || trayItem.item.title || "") + (trayItem.item.tooltipDescription ? "\n" + trayItem.item.tooltipDescription : "")
                delay: 500
            }
            Component {
                id: menuContents
                SystrayMenu {
                    menu: trayItem.item.menu
                    Layout.fillWidth: true
                }
            }

            // Handle clicks
            onClicked: function (mouse) {
                if (mouse.button === Qt.RightButton || !trayItem.item.hasMenu) {
                    trayItem.item.activate();
                } else if (mouse.button === Qt.LeftButton) {
                    // menuAnchor.open();
                    root.showPopup(root, menuContents, {});
                }
            }

            onWheel: function (wheel) {
                if (wheel.y != 0) {
                    trayItem.item.scroll(wheel.y, false);
                }
            }

            // QsMenuAnchor {
            //     id: menuAnchor
            //     anchor.item: trayItem
            //     anchor.edges: Edges.Bottom | Edges.Right
            //     menu: trayItem.item.menu
            // }

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
