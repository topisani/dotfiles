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
    readonly property bool popupOpen: popup.visible

    function showPopup(anchor: Item, widget = null, properties = {}) {
        if (!widget) {
            return root.close();
        }
        // Toggle: clicking the same anchor while open closes the popup
        if (parentWindow === anchor && popup.visible) {
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
        popup.open();
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
        onClosed: popupLoader.active = false

        readonly property real shadowSize: 50
        contentWidth: popupPanel.implicitWidth
        // contentHeight: popupPanel.implicitHeight
        contentHeight: Math.max(1000, popupPanel.implicitHeight);
        // padding: shadowSize
        // padding: 0
        topPadding: 0
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

            // x: popup.shadowSize
            // y: -popup.shadowSize

            radius: 5
            color: Config.cc.backgroundColor
            margin: 10
            implicitHeight: popupLoader.implicitHeight + margin * 2
            implicitWidth: Math.max(popupLoader.implicitWidth + margin * 2, 400)
            border {
                width: 1
                color: Config.theme.color.inactive
            }
            // implicitHeight: 500
            layer.enabled: false
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
