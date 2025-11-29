pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.utils
import qs.modules.controlcenter
import qs.services as Services

GridLayout {
    columns: 2
    Layout.fillWidth: false
    Layout.fillHeight: false

    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    DayOfWeekRow {
        locale: grid.locale

        Layout.column: 1
        Layout.fillWidth: true

        delegate: Text {
            text: shortName
            font: Config.cc.font
            color: Config.theme.color.textMuted
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            required property string shortName
        }
    }

    WeekNumberColumn {
        month: grid.month
        year: grid.year
        locale: grid.locale

        Layout.fillHeight: true

        delegate: Text {
            text: weekNumber
            font: Config.cc.font
            color: Config.theme.color.textMuted
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            required property int weekNumber
        }
    }

    MonthGrid {
        id: grid
        month: clock.date.getMonth()
        year: clock.date.getFullYear()

        Layout.fillWidth: true
        Layout.fillHeight: false
        delegate: Rectangle {
            id: monthBg
            required property var model
            implicitWidth: monthText.implicitWidth + 2 * Config.cc.padding
            implicitHeight: monthText.implicitHeight + 2
            color: (model.date.getMonth() == clock.date.getMonth() && model.date.getDate() == clock.date.getDate()) ? Config.theme.color.active : "transparent"
            radius: Config.cc.radius
            Text {
                id: monthText
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                opacity: monthBg.model.month === clock.date.getMonth() ? 1 : 0.5
                text: monthBg.model.day
                font: Config.cc.font
                color: Config.theme.color.text
            }
        }
    }
}

