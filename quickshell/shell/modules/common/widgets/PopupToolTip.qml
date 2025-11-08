import Quickshell
import QtQuick

Item {
    id: tooltip

    property string text: ""
    property int delay: 500
    property alias anchor: internal.anchor

    // Internal actual visibility state
    PopupWindow {
        id: internal

        implicitWidth: tooltipText.width + 16
        implicitHeight: tooltipText.height + 16
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: "#333333"
            radius: 4

            Text {
                id: tooltipText
                text: tooltip.text
                color: "white"
                anchors.centerIn: parent
            }
        }
    }

    Timer {
        id: showTimer
        interval: tooltip.delay
        onTriggered: function () {
            internal.visible = true;
        }
    }
    // Watch the public visible property
    onVisibleChanged: {
        if (visible) {
            showTimer.start();
        } else {
            showTimer.stop();
            internal.visible = false;
        }
    }
}
