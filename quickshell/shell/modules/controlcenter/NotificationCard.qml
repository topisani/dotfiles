pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.utils as Qsu
import qs.modules.common.widgets

ClippingRectangle {
    id: root
    required property Notifications.Notification notification
    readonly property string image: Notifications.getImage(notification)
    readonly property string appIcon: Notifications.getAppIcon(notification)
    readonly property bool urgent: notification.urgency == NotificationUrgency.Critical
    readonly property var defaultAction: Array.from(root.notification.actions.values()).find(a => a.identifier == "default")
    readonly property var progressValue: root.notification.hints["value"]

    radius: Config.cc.radius
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight
    border.color: urgent ? Config.theme.color.errorMuted : Config.cc.borderColor
    border.width: Config.cc.borderWidth
    border.pixelAligned: true

    color: hover.hovered ? Config.theme.color.inactive : Config.cc.menuBackground
    // color: urgent ? "#4D2925" : Config.cc.menuBackground

    Behavior on color {
        ColorAnimation {
            duration: Config.theme.animationDuration
        }
    }

    HoverHandler {
        id: hover
        enabled: root.defaultAction != null
    }

    TapHandler {
        enabled: root.defaultAction != null
        onTapped: root.defaultAction?.invoke()
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Image {
                source: root.image
                visible: root.image
                Layout.preferredWidth: col.width * 0.2
                Layout.preferredHeight: 30
                Layout.fillHeight: true
                fillMode: Image.PreserveAspectCrop
            }

            Item {
                id: paddedContents
                Layout.fillWidth: true
                // Layout.margins: Config.cc.padding
                implicitWidth: paddedLayout.implicitWidth + 2 * paddedLayout.anchors.margins
                implicitHeight: paddedLayout.implicitHeight  + 2 * paddedLayout.anchors.margins
                
                Rectangle {
                    id: progressBar
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * root.progressValue / 100
                    color: Config.theme.color.inactive
                }
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Config.cc.padding
                    id: paddedLayout
                    
                    RowLayout {

                        SystemIcon {
                            size: Config.cc.iconSize
                            source: root.appIcon
                            visible: source
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.notification.summary
                            font: Config.cc.font
                            color: Config.theme.color.text
                            wrapMode: Text.Wrap
                        }

                        CCButton {
                            icon: "gtk-close"
                            padding: 2
                            iconSize: Config.cc.iconSize * 0.75
                            onClicked: root.notification.dismiss()
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: text
                        text: root.notification.body.replace(/\n/g, '<br/>')
                        font: Config.cc.fontSmall
                        color: Config.theme.color.text
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            visible: text
                            text: root.notification.appName
                            font: Config.cc.fontSmall
                            color: Config.theme.color.textMuted
                        }
                        Text {
                            horizontalAlignment: Qt.AlignRight
                            visible: text
                            text: Qsu.Utils.formatTimestamp(root.notification.timestamp)
                            font: Config.cc.fontSmall
                            color: Config.theme.color.textMuted
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.notification.actions
            spacing: Config.cc.borderWidth

            Repeater {
                model: root.notification.actions
                CCButton {
                    required property NotificationAction modelData
                    visible: modelData.text != ""
                    Layout.fillWidth: true
                    radius: 0

                    text: modelData.text
                    font: Config.cc.fontSmall
                    icon: root.notification.hasActionIcons ? (modelData.identifier || null) : null;

                    onClicked: modelData.invoke()
                }
            }
        }
    }
}
