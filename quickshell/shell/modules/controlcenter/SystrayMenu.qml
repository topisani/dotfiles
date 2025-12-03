pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property alias menu: itemList.menu

    height: implicitHeight
    implicitHeight: itemList.implicitHeight
    implicitWidth: itemList.implicitWidth
    // implicitHeight: 500

    MenuItemList {
        id: itemList
        anchors.fill: parent
    }

    component MenuItemList: ColumnLayout {
        id: itemListRoot
        property alias menu: menuOpener.menu
        spacing: Config.menu.spacing
        Layout.fillHeight: false

        QsMenuOpener {
            id: menuOpener
        }

        Repeater {
            model: menuOpener.children

            delegate: Loader {
                required property QsMenuEntry modelData
                active: true
                sourceComponent: modelData.isSeparator ? separatorItem : menuItem
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
        }
    }

    component MenuItemDelegate: ColumnLayout {
        id: item
        required property QsMenuEntry entry
        property bool expanded: false
        Layout.fillHeight: false

        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: false
            implicitWidth: row.implicitWidth + 2 * Config.menu.padding
            implicitHeight: row.implicitHeight + 2 * Config.menu.padding
            Layout.alignment: Qt.AlignTop

            color: ma.containsMouse ? Config.menu.hoverBackground : "transparent"

            MouseArea {
                id: ma
                hoverEnabled: item.entry.enabled
                acceptedButtons: Qt.LeftButton
                anchors.fill: parent
                anchors.margins: Config.menu.padding

                onClicked: {
                    if (item.entry.hasChildren) {
                        item.expanded = !item.expanded;
                        if (item.expanded) {
                            item.entry.opened()
                        } else {
                            item.entry.closed()
                        }
                        entry.updateLayout()
                    } else {
                        item.entry.triggered();
                    }
                }

                RowLayout {
                    id: row
                    spacing: Config.menu.colSpacing
                    anchors.fill: parent
                    Layout.fillHeight: false

                    SystemIcon {
                        visible: item.entry.buttonType == QsMenuButtonType.CheckBox
                        source: Config.checkboxIcon(item.entry.checkState)
                        size: Config.menu.iconSize
                    }

                    SystemIcon {
                        visible: item.entry.buttonType == QsMenuButtonType.RadioButton
                        source: Config.radioButtonIcon(item.entry.checkState)
                        size: Config.menu.iconSize
                    }

                    SystemIcon {
                        visible: item.entry.icon != ""
                        source: item.entry.icon
                        size: Config.menu.iconSize
                    }

                    Text {
                        Layout.fillWidth: true
                        text: item.entry.text
                        color: item.entry.enabled ? Config.theme.color.text : Config.menu.disabledColor
                        font: Config.menu.font
                    }

                    SystemIcon {
                        source: item.expanded ? "arrow-down" : "arrow-right"
                        size: Config.menu.iconSize
                        visible: item.entry.hasChildren
                    }
                }
            }
        }
        // Submenu wrapper
        Item {
            Layout.fillWidth: true
            implicitHeight: animatedHeight
            Layout.leftMargin: Config.menu.iconSize + Config.menu.colSpacing - Config.menu.padding

            property real animatedHeight: item.expanded && submenuLoader.item ? submenuLoader.item.implicitHeight : 0
            clip: true

            Behavior on animatedHeight {
                NumberAnimation {
                    duration: Config.theme.animationDuration
                }
            }

            Loader {
                id: submenuLoader
                active: item.entry.hasChildren && (item.expanded || parent.animatedHeight > 0)
                visible: parent.animatedHeight > 0
                anchors.fill: parent

                sourceComponent: MenuItemList {
                    menu: item.entry
                }
            }
        }
    }
}
