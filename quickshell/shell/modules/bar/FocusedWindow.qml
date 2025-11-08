import QtQuick
import qs.modules.common
import qs.services

Row {
    id: root
    spacing: 5
    
    property var focusedWindow: Niri.focusedWindow || Niri.windows.findById(Niri.workspaces.focusedWorkspace?.activeWindowId || 0)
    
    Image {
        anchors.verticalCenter: parent.verticalCenter
        source: root.focusedWindow?.iconPath ? "file://" + root.focusedWindow?.iconPath : ""
        sourceSize.width: Config.focusedWindow.icon.scale * Config.theme.widget.size
        sourceSize.height: Config.focusedWindow.icon.scale * Config.theme.widget.size
        visible: Config.focusedWindow.icon.enabled && root.focusedWindow?.iconPath !== ""
        smooth: true
    }

    // Fallback for missing icons
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Config.focusedWindow.icon.scale * Config.theme.widget.size
        height: Config.focusedWindow.icon.scale * Config.theme.widget.size
        color: Config.theme.color.inactive
        visible: Config.focusedWindow.icon.enabled && root.focusedWindow?.iconPath === ""
        radius: 12
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.focusedWindow?.title ?? ""
        font: Config.focusedWindow.font
        color: Config.theme.color.text
        visible: Config.focusedWindow.title.enabled
    }
}
