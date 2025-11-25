pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.modules.common

Item {
    id: root

    property var parentWindow

    function showPopup(anchor: Item, widget = null, properties = {}) {
        if (!widget) {
            return root.close();
        }
        parentWindow = anchor;
        popupLoader.sourceComponent = widget;
        popupLoader.active = true;
        if (properties) {
            for (var key in properties) {
                popupLoader.item[key] = properties[key];
            }
        }
        if (!popup.visible) popup.open();
    }

    function close() {
        popup.close();
    }

    Popup {
        id: popup
        parent: root.parentWindow
        popupType: Popup.Window
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        readonly property real shadowSize: 50
        contentWidth: popupPanel.implicitWidth
        // contentHeight: popupPanel.implicitHeight
        contentHeight: Math.max(1000, popupPanel.implicitHeight);
        padding: shadowSize
        y: parent.height

        background: MouseArea {
            acceptedButtons: Qt.AllButtons
            onClicked: {
                popup.close();
            }
        }

        enter: Transition {
            NumberAnimation {
                properties: "opacity"
                from: 0
                to: 1
                duration: Config.theme.animationDuration
            }
        }
        exit: Transition {
            NumberAnimation {
                properties: "opacity"
                from: 1
                to: 0
                duration: Config.theme.animationDuration
            }
        }

        ClippingWrapperRectangle {
            id: popupPanel

            x: popup.shadowSize
            y: -popup.shadowSize

            radius: 10
            color: Config.cc.backgroundColor
            margin: 20
            implicitHeight: popupLoader.implicitHeight + margin * 2
            implicitWidth: Math.max(popupLoader.implicitWidth + margin * 2, 400)
            // implicitHeight: 500
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                // The vertical offset makes the shadow slightly more prominent
                shadowVerticalOffset: 0
                shadowHorizontalOffset: 0
                shadowBlur: 1
                blurMultiplier: 1
                shadowColor: Config.theme.color.shadow
                opacity: popup.opacity
            }

            Loader {
                id: popupLoader
            }
        }
    }
}
