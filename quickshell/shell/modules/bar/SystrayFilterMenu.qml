pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root
    spacing: Config.menu.spacing
    focus: true

    property int currentIndex: -1

    onActiveFocusChanged: {
        if (activeFocus && currentIndex < 0) {
            navigateDown();
        }
    }

    function navigateUp() {
        for (let i = currentIndex - 1; i >= 0; i--) {
            let item = repeater.itemAt(i);
            if (item && item.visible) {
                currentIndex = i;
                return;
            }
        }
    }

    function navigateDown() {
        for (let i = (currentIndex < 0 ? 0 : currentIndex + 1); i < repeater.count; i++) {
            let item = repeater.itemAt(i);
            if (item && item.visible) {
                currentIndex = i;
                return;
            }
        }
    }

    function activateCurrent() {
        if (currentIndex < 0 || currentIndex >= repeater.count) return;
        let item = repeater.itemAt(currentIndex);
        if (item) Config.state.toggleSystrayItemInBar(item.item.id);
    }

    Keys.onUpPressed: navigateUp()
    Keys.onDownPressed: navigateDown()
    Keys.onReturnPressed: activateCurrent()
    Keys.onEnterPressed: activateCurrent()
    Keys.onSpacePressed: activateCurrent()

    Text {
        text: "Systray Bar Visibility"
        font.family: Config.menu.font.family
        font.pointSize: Config.menu.font.pointSize
        font.bold: true
        color: Config.theme.color.text
        Layout.bottomMargin: 4
    }

    Repeater {
        id: repeater
        model: SystemTray.items

        Rectangle {
            id: itemRow
            required property var modelData
            required property int index
            property var item: modelData
            // visible: item.status != Status.Passive

            Layout.fillWidth: true
            implicitHeight: rowLayout.implicitHeight + 4
            color: (index === root.currentIndex || itemHover.hovered) ? Config.menu.hoverBackground : "transparent"
            radius: Config.cc.radius

            HoverHandler {
                id: itemHover
            }

            TapHandler {
                onTapped: Config.state.toggleSystrayItemInBar(itemRow.item.id)
            }

            RowLayout {
                id: rowLayout
                anchors.fill: parent
                anchors.leftMargin: Config.menu.padding
                anchors.rightMargin: Config.menu.padding
                spacing: Config.menu.colSpacing

                SystemIcon {
                    source: Config.checkboxIcon(!Config.state.isSystrayItemHiddenInBar(itemRow.item.id))
                    size: Config.menu.iconSize
                }

                SystemIcon {
                    source: itemRow.item.icon
                    size: Config.menu.iconSize
                }

                Text {
                    text: itemRow.item.id
                    font.family: Config.menu.font.family
                    font.pointSize: Config.menu.font.pointSize
                    color: Config.theme.color.text
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
        }
    }
}
