pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.modules.common.widgets
import qs.modules.common
import qs.modules.controlcenter

GridLayout {
    id: root
    columnSpacing: Config.cc.spacing
    rowSpacing: Config.cc.spacing

    property string openId: ""
    signal showPopup(Item anchor, var comp, var props)

    Repeater {
        model: SystemTray.items

        Item {
            id: trayItem
            Layout.fillWidth: true
            required property var modelData
            property var item: modelData
            visible: item.status != Status.Passive

            implicitHeight: button.implicitHeight
            implicitWidth: button.implicitWidth

            property string longText: (trayItem.item.tooltipTitle || trayItem.item.title || "") + (trayItem.item.tooltipDescription ? "\n" + trayItem.item.tooltipDescription : "")

            CCButton {
                id: button
                hoverEnabled: true
                // acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                // scrollGestureEnabled: true
                anchors.fill: parent
                state: root.openId == trayItem.item.id
                // text: trayItem.longText

                icon: trayItem.item.icon

                // Handle clicks
                onClicked: {
                    // if (mouse.button === Qt.RightButton || !trayItem.item.hasMenu) {
                    //     trayItem.item.activate();
                    // }
                    if (trayItem.item.hasMenu) {
                        if (root.openId == trayItem.item.id) {
                            root.showPopup(null, null, {});
                            root.openId = "";
                        } else {
                            root.showPopup(root, menuContents, {});
                            root.openId = trayItem.item.id;
                        }
                    }
                }

                onDoubleClicked: {
                    trayItem.item.activate();
                    if (trayItem.item.hasMenu) {
                        root.showPopup(root, menuContents, {});
                        root.openId = trayItem.item.id;
                    }
                }

                WheelHandler {
                    onWheel: function (wheel) {
                        if (wheel.y != 0) {
                            trayItem.item.scroll(wheel.y, false);
                        }
                    }
                }
            }

            // // Tooltip
            // PopupToolTip {
            //     id: tooltip
            //     anchor.item: trayItem
            //     anchor.edges: Edges.Bottom | Edges.Left
            //     visible: button.containsMouse
            //     text: trayItem.longText
            //     delay: 500
            // }

            Component {
                id: menuContents
                ColumnLayout {
                    spacing: Config.cc.spacing
                    Text {
                        text: trayItem.longText
                        font: Config.cc.font
                        color: Config.theme.color.text
                    }
                    SystrayMenu {
                        menu: trayItem.item.menu
                        Layout.fillWidth: true
                    }

                    // Fixes alignment during animation
                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
        }
    }
}
