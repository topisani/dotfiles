pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
// import Quickshell.Services.Notifications
import qs.services
import qs.modules.common
import qs.modules.common.utils as Qsu
import qs.modules.common.widgets

Item {
    id: root
    
    implicitHeight: list.implicitHeight
    implicitWidth: list.implicitWidth
    
    ListView {
        id: list
        anchors.fill: parent
        model: Notifications.notifications
        
        spacing: Config.cc.spacing
        clip: true

        delegate: NotificationCard {
            required property Notifications.Notification modelData
            notification: modelData

            width: root.width
        }
    }
}
