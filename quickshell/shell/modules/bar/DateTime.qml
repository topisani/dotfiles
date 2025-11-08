import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common

RowLayout {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        text: Qt.formatDateTime(clock.date, Config.datetime.time.format || "hh:mm")
        font: Config.bar.font
        color: Config.theme.color.text
    }
}
