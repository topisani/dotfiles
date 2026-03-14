import QtQuick
import QtQuick.Controls
import qs.modules.common

ToolTip {
    id: tooltip
    popupType: Popup.Window
    delay: 500
    timeout: -1
    
    y: Math.round(parent.height)

    property bool _hovered: parentHover.hovered || tooltipHover.hovered
    on_HoveredChanged: {
        if (_hovered) {
            hideTimer.stop();
            visible = true;
        } else {
            hideTimer.start();
        }
    }

    Timer {
        id: hideTimer
        interval: 100
        onTriggered: tooltip.visible = false
    }

    HoverHandler {
        id: parentHover
        parent: tooltip.parent
    }

    HoverHandler {
        id: tooltipHover
    }

    background: Rectangle {
        color: Config.theme.color.background2
        radius: 4
    }

    contentItem: Text {
        text: tooltip.text
        color: Config.theme.color.text
        font: Config.bar.font
    }
}
