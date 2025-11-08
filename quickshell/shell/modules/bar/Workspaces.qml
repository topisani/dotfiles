import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.services

Rectangle {
    color: Config.theme.color.background
    width: rowLayout.implicitWidth

    Rectangle {
        anchors {
            leftMargin: 10
            rightMargin: 10
        }

        RowLayout {
            id: rowLayout
            anchors {
                verticalCenter: parent.verticalCenter
            }
            spacing: 5

            Repeater {
                model: Niri.workspaces

                Rectangle {
                    visible: index < 11
                    width: Config.workspaces.icon.scale * Config.theme.widget.size
                    height: Config.workspaces.icon.scale * Config.theme.widget.size
                    radius: Config.workspaces.icon.scale * Config.theme.widget.size * Config.workspaces.icon.radius
                    color: model.isActive ? Config.theme.color.active : Config.workspaces.inactiveColor
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Niri.focusWorkspaceById(model.id)
                    }
                }
            }
        }
    }
}
