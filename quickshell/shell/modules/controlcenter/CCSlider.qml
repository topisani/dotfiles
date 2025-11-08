import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets

ClippingRectangle {
    id: root
    property string icon: ""
    property string text: ""

    radius: 10
    height: Config.cc.iconSize + 2 * Config.cc.padding
    implicitWidth: row.implicitWidth
    color: "transparent"

    property alias value: slider.value
    // margin: 15

    SliderBar {
        id: slider
        anchors.fill: parent
        trackColor: Config.theme.color.inactive
        highlightColor: Config.theme.color.active
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: Config.cc.padding
        SystemIcon {
            source: root.icon
            size: Config.cc.iconSize
        }
        Text {
            color: Config.theme.color.text
            font: Config.cc.font
            text: root.text
        }
    }}

