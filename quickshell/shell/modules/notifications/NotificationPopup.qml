pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQml.Models
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.utils
import qs.modules.controlcenter
import qs.services

Item {
    id: root

    property real panelOpacity: root.shouldShow ? 1.0 : 0
    property bool shouldShow: hasPopupNotifications && Notifications.showPopups
    
    property bool hasPopupNotifications: {
        for (let i = 0; i < Notifications.notifications.count; i++) {
            if (Notifications.notifications.get(i).modelData.showPopup) {
                return true
            }
        }
        return false
    }

    Behavior on panelOpacity {
        NumberAnimation {
            duration: Config.theme.animationDuration
        }
    }

    LazyLoader {
        id: loader
        active: (root.hasPopupNotifications && root.shouldShow) || root.panelOpacity > 0

        PanelWindow {
            id: overlayPanel
            WlrLayershell.layer: WlrLayer.Overlay
            focusable: false

            anchors {
                top: true
                right: true
            }

            implicitHeight: panel.height + 100
            implicitWidth: panel.width + 100

            color: "transparent"

            ColumnLayout {
                id: panel
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 20
                width: 400
                spacing: 10
                opacity: root.panelOpacity
                
                Repeater {
                    model: Notifications.notifications
                    
                    NotificationCard {
                        id: item
                        required property Notifications.Notification modelData;
                        notification: modelData
                        visible: modelData.showPopup
                        Layout.fillWidth: true
                        
                        TapHandler {
                            onTapped: {
                                item.modelData.dismissPopup()
                            }
                        }

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            // The vertical offset makes the shadow slightly more prominent
                            shadowVerticalOffset: 0
                            shadowHorizontalOffset: 0
                            shadowBlur: 1
                            blurMultiplier: 1
                            shadowColor: "#40000000"
                        }
                    }
                }
            }
        }
    }
}
