import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common

Rectangle {
    id: root

    implicitWidth: text.implicitWidth + 4
    implicitHeight: text.implicitHeight
    color: hover.hovered ? Config.theme.color.inactive : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Config.theme.animationDuration
        }
    }

    HoverHandler {
        id: hover
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        id: text
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, Config.datetime.time.format || "hh:mm")
        font: Config.bar.font
        color: Config.theme.color.text
    }
}
