pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.modules.common.widgets
import qs.modules.controlcenter
import qs.modules.common

RowLayout {
    id: root
    spacing: 5
    property real size: Config.bar.size;

    signal showPopup(Item anchor, var popupContent, var properties)

    // Hidden repeater to access SystemTray items
    Repeater {
        id: itemRepeater
        model: SystemTray.items
        Item {
            required property var modelData
            property var itemData: modelData
            visible: false
        }
    }

    // Sorted + filtered list of systray item objects
    property var sortedItems: {
        void(Config.state.systrayBarOrder);
        void(Config.state.hiddenBarSystrayIds);
        void(itemRepeater.count);
        let order = Config.state.systrayBarOrder;
        let othersIdx = order.indexOf("");
        let items = [];
        for (let i = 0; i < itemRepeater.count; i++) {
            let d = itemRepeater.itemAt(i);
            if (!d) continue;
            let item = d.itemData;
            if (item.status === Status.Passive) continue;
            if (Config.state.isSystrayItemHiddenInBar(item.id)) continue;
            items.push({ obj: item, mi: i });
        }
        items.sort((a, b) => {
            let ai = order.indexOf(a.obj.id);
            let bi = order.indexOf(b.obj.id);
            if (ai < 0) ai = othersIdx >= 0 ? othersIdx + 0.5 : 9999;
            if (bi < 0) bi = othersIdx >= 0 ? othersIdx + 0.5 : 9999;
            if (ai !== bi) return ai - bi;
            return a.mi - b.mi;
        });
        return items.map(x => x.obj);
    }

    Repeater {
        model: root.sortedItems

        MouseArea {
            id: trayItem
            implicitWidth: root.size
            implicitHeight: root.size
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            scrollGestureEnabled: true

            required property var modelData
            property var item: modelData

            // visible: item.status != Status.Passive && !Config.state.isSystrayItemHiddenInBar(item.id)

            // Tray icon
            SystemIcon {
                anchors.centerIn: parent
                size: Config.bar.iconSize
                source: trayItem.item.icon
            }

            // Tooltip
            PopupToolTip {
                parent: trayItem
                text: (trayItem.item.tooltipTitle || trayItem.item.title || "") + (trayItem.item.tooltipDescription ? "\n" + trayItem.item.tooltipDescription : "")
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
                if (trayItem.item.menuOnly || trayItem.item.id == "nm-applet" || trayItem.item.id == "udiskie") {
                    root.showPopup(trayItem, menuContents, {});
                    return
                }
                if (mouse.button === Qt.LeftButton) {
                    trayItem.item.activate();
                } else {
                    // menuAnchor.open();
                    root.showPopup(trayItem, menuContents, {});
                }
            }

            onWheel: function (wheel) {
                if (wheel.y != 0) {
                    trayItem.item.scroll(wheel.y, false);
                }
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
