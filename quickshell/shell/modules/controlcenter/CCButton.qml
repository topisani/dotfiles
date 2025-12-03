import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.utils
import qs.modules.common.widgets

WrapperMouseArea {
    id: root
    property string icon: ""
    property string text: ""
    property bool state: false
    property var font: Config.cc.font
    property real radius: Config.cc.radius
    property real iconSize: Config.cc.iconSize
    property real padding: Config.cc.padding
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true

    WrapperRectangle {
        radius: root.radius
        margin: root.padding
        color: ColorUtils.mix(Config.theme.color.inactive, Config.theme.color.active, root.state ? (1 - 0.25 * root.containsMouse) : 0.25 * root.containsMouse)

        Behavior on color {
            ColorAnimation {
                duration: Config.theme.animationDuration
            }
        }

        RowLayout {
            id: row
            SystemIcon {
                Layout.alignment: Layout.Center
                visible: isValid
                source: root.icon
                size: root.iconSize
            }
            Text {
                visible: root.text != ""
                color: Config.theme.color.text
                font: root.font
                text: root.text
            }
        }
    }
}
