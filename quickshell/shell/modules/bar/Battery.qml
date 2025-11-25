pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick.Layouts

Rectangle {
    id: root
    property real size: 20
    // readonly property var chargeState: Battery.chargeState
    // readonly property bool isCharging: Battery.isCharging
    // readonly property bool isPluggedIn: Battery.isPluggedIn
    // readonly property real percentage: Battery.percentage
    // readonly property bool isLow: percentage <= Config.battery.low / 100
    // readonly property bool isCritical: percentage <= Config.battery.critical / 100
    
    WheelHandler {
        property: "percentage"
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    implicitWidth: row.implicitWidth
    implicitHeight: size
    color: hover.hovered ? Config.theme.color.inactive : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Config.theme.animationDuration
        }
    }

    HoverHandler {
        id: hover
    }

    RowLayout {
        anchors.margins: 3
        id: row
        spacing: 10
        SystemIcon {
            source: Battery.iconSource
            size: root.size
        }
        
        Text {
            text: `${Math.round(Battery.percentage * 100)}%`
            font: Config.bar.font
            color: Config.theme.color.text
        }
    }
}

