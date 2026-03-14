pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

FocusScope {
    id: root

    property alias menu: itemList.menu
    signal itemTriggered()

    height: implicitHeight
    implicitHeight: itemList.implicitHeight
    implicitWidth: itemList.implicitWidth

    MenuItemList {
        id: itemList
        focus: true
        anchors.fill: parent
        onItemTriggered: root.itemTriggered()
    }

    component MenuItemList: ColumnLayout {
        id: itemListRoot
        property alias menu: menuOpener.menu
        property int currentIndex: -1
        property int openSubmenuIndex: -1
        property var parentMenuList: null
        property int parentIndex: -1
        signal itemTriggered()
        spacing: Config.menu.spacing
        Layout.fillHeight: false
        focus: true

        onActiveFocusChanged: {
            if (activeFocus && currentIndex < 0) {
                navigateDown();
            }
        }

        function navigateUp() {
            for (let i = currentIndex - 1; i >= 0; i--) {
                if (!repeater.itemAt(i).modelData.isSeparator) {
                    currentIndex = i;
                    return;
                }
            }
        }

        function navigateDown() {
            for (let i = (currentIndex < 0 ? 0 : currentIndex + 1); i < repeater.count; i++) {
                if (!repeater.itemAt(i).modelData.isSeparator) {
                    currentIndex = i;
                    return;
                }
            }
        }

        function activateCurrent() {
            if (currentIndex < 0 || currentIndex >= repeater.count) return;
            let delegate = repeater.itemAt(currentIndex);
            if (!delegate || !delegate.item) return;
            let entry = delegate.modelData;
            if (!entry.enabled) return;
            if (entry.hasChildren) {
                openSubmenuAt(currentIndex, true);
            } else {
                entry.triggered();
                itemTriggered();
            }
        }

        function openSubmenuAt(index: int, giveFocus: bool) {
            if (openSubmenuIndex === index) {
                if (giveFocus) {
                    let d = repeater.itemAt(index);
                    if (d && d.item && d.item.submenuList) {
                        d.item.submenuList.forceActiveFocus();
                    }
                }
                return;
            }
            closeSubmenu();
            let delegate = repeater.itemAt(index);
            if (!delegate) return;
            delegate.modelData.opened();
            delegate.modelData.updateLayout();
            openSubmenuIndex = index;
            if (giveFocus) {
                Qt.callLater(function() {
                    let d = repeater.itemAt(index);
                    if (d && d.item && d.item.submenuList) {
                        d.item.submenuList.forceActiveFocus();
                    }
                });
            }
        }

        function closeSubmenu() {
            if (openSubmenuIndex >= 0 && openSubmenuIndex < repeater.count) {
                let delegate = repeater.itemAt(openSubmenuIndex);
                if (delegate) {
                    delegate.modelData.closed();
                }
            }
            openSubmenuIndex = -1;
        }

        Keys.onUpPressed: navigateUp()
        Keys.onDownPressed: navigateDown()
        Keys.onReturnPressed: activateCurrent()
        Keys.onEnterPressed: activateCurrent()
        Keys.onSpacePressed: activateCurrent()
        Keys.onLeftPressed: {
            if (currentIndex >= 0 && currentIndex < repeater.count) {
                let entry = repeater.itemAt(currentIndex).modelData;
                if (entry.hasChildren) {
                    openSubmenuAt(currentIndex, true);
                }
            }
        }
        Keys.onRightPressed: {
            if (parentMenuList) {
                parentMenuList.closeSubmenu();
                parentMenuList.forceActiveFocus();
            }
        }
        Keys.onEscapePressed: function(event) {
            if (parentMenuList) {
                parentMenuList.closeSubmenu();
                parentMenuList.forceActiveFocus();
            } else {
                event.accepted = false;
            }
        }

        QsMenuOpener {
            id: menuOpener
        }

        Repeater {
            id: repeater
            model: menuOpener.children

            delegate: Loader {
                required property QsMenuEntry modelData
                required property int index
                property bool isCurrent: index === itemListRoot.currentIndex
                property bool isSubmenuOpen: index === itemListRoot.openSubmenuIndex
                property var ownerMenuList: itemListRoot
                active: true
                sourceComponent: (modelData && modelData.isSeparator) ? separatorItem : menuItem
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.alignment: Qt.AlignTop
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    Component {
        id: separatorItem
        Rectangle {
            height: Config.menu.padding * 2
            color: "transparent"
            Rectangle {
                implicitWidth: parent.width - Config.menu.padding * 2
                anchors.centerIn: parent
                implicitHeight: 1
                y: Config.menu.padding
                color: Config.menu.separatorColor
            }
        }
    }

    Component {
        id: menuItem
        MenuItemDelegate {
            entry: parent.modelData
            isCurrent: parent.isCurrent
            isSubmenuOpen: parent.isSubmenuOpen
            ownerMenuList: parent.ownerMenuList
            ownerIndex: parent.index
        }
    }

    component MenuItemDelegate: Item {
        id: item
        required property QsMenuEntry entry
        property bool isCurrent: false
        property bool isSubmenuOpen: false
        property var ownerMenuList: null
        property int ownerIndex: -1
        readonly property var submenuList: submenuLoader.item

        implicitWidth: Math.max(row.implicitWidth + 2 * Config.menu.padding, 200)
        implicitHeight: row.implicitHeight + 2 * Config.menu.padding

        Rectangle {
            anchors.fill: parent
            color: (item.isCurrent) ? Config.menu.hoverBackground : "transparent"
        }

        MouseArea {
            id: ma
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            anchors.fill: parent

            onContainsMouseChanged: {
                if (containsMouse && item.entry && item.ownerMenuList) {
                    item.ownerMenuList.currentIndex = item.ownerIndex;
                    if (item.entry.hasChildren) {
                        item.ownerMenuList.openSubmenuAt(item.ownerIndex, false);
                    } else {
                        item.ownerMenuList.closeSubmenu();
                    }
                }
            }

            onClicked: {
                if (item.entry && !item.entry.hasChildren) {
                    item.entry.triggered();
                    if (item.ownerMenuList) item.ownerMenuList.itemTriggered();
                }
            }
        }

        RowLayout {
            id: row
            spacing: Config.menu.colSpacing
            anchors.fill: parent
            anchors.margins: Config.menu.padding

            SystemIcon {
                visible: item.entry && item.entry.buttonType == QsMenuButtonType.CheckBox
                source: item.entry ? Config.checkboxIcon(item.entry.checkState) : ""
                size: Config.menu.iconSize
            }

            SystemIcon {
                visible: item.entry && item.entry.buttonType == QsMenuButtonType.RadioButton
                source: item.entry ? Config.radioButtonIcon(item.entry.checkState) : ""
                size: Config.menu.iconSize
            }

            SystemIcon {
                visible: item.entry && item.entry.icon != ""
                source: item.entry ? item.entry.icon : ""
                size: Config.menu.iconSize
            }

            Text {
                Layout.fillWidth: true
                text: item.entry ? item.entry.text : ""
                color: (item.entry && item.entry.enabled) ? Config.theme.color.text : Config.menu.disabledColor
                font: Config.menu.font
            }

            SystemIcon {
                source: "arrow-right"
                size: Config.menu.iconSize
                visible: item.entry && item.entry.hasChildren
            }
        }

        Popup {
            id: submenuPopup
            visible: item.isSubmenuOpen && submenuLoader.item
            popupType: Popup.Window
            focus: true
            x: -(submenuPopup.width + 2)
            y: 0
            padding: Config.cc.padding
            closePolicy: Popup.NoAutoClose

            onOpened: {
                if (submenuLoader.item) {
                    submenuLoader.item.forceActiveFocus();
                }
            }

            background: Rectangle {
                color: Config.cc.menuBackground
                radius: Config.cc.radius
                border.width: 1
                border.color: Config.theme.color.inactive
            }

            contentItem: Loader {
                id: submenuLoader
                active: item.entry && item.entry.hasChildren
                focus: true
                sourceComponent: Component {
                    MenuItemList {
                        menu: item.entry
                        parentMenuList: item.ownerMenuList
                        parentIndex: item.ownerIndex
                        onItemTriggered: {
                            if (item.ownerMenuList) item.ownerMenuList.itemTriggered();
                        }
                    }
                }
            }
        }
    }
}
