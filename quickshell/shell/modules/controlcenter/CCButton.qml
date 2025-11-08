import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets

WrapperMouseArea {
    id: root
    property string icon: ""
    property string text: ""
    property bool state: false
    acceptedButtons: Qt.LeftButton

    WrapperRectangle {
        radius: 10
        margin: Config.cc.padding
        color: root.state ? Config.theme.color.active : Config.theme.color.inactive

        Behavior on color {
            ColorAnimation {
                duration: Config.theme.animationDuration
            }
        }

        RowLayout {
            id: row
            SystemIcon {
                visible: root.icon != ""
                source: root.icon
                size: Config.cc.iconSize
            }
            Text {
                visible: root.text != ""
                color: Config.theme.color.text
                font: Config.cc.font
                text: root.text
            }
        }
    }
}
