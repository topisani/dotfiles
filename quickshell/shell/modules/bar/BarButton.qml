import Quickshell.Services.Pipewire
import QtQuick.Layouts
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root
    property real size: 20
    implicitWidth: size + 4
    implicitHeight: size
    color: hover.hovered ? Config.theme.color.inactive : "transparent"

    property string icon

    signal clicked

    Behavior on color {
        ColorAnimation {
            duration: Config.theme.animationDuration
        }
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: root.clicked()
    }

    RowLayout {
        spacing: Config.bar.spacing
        SystemIcon {
            visible: root.icon
            Layout.alignment: Qt.AlignVCenter
            Layout.margins: 3
            size: root.size - 6
            source: root.icon
        }
    }
}
