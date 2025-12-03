pragma Singleton
import Quickshell
import QtQuick
import qs.modules.common

Singleton {
    id: root
    // Global theme. Source of default and base values for all components.
    readonly property var theme: QtObject {
        readonly property var color: QtObject {
            readonly property color active: "#178ca6"
            readonly property color inactive: "#021c2d" // #112126"
            readonly property color text: "#FEFBFC"
            readonly property color textMuted: "#999999"
            readonly property color foreground: "#FFFFFF"
            readonly property color background: "#000000"
            readonly property color background2: "#090a0f"
            readonly property color ok: "#1A7F39"
            readonly property color error: "#F24130"
            readonly property color errorMuted: "#3A1E1B" // "#9E453C"
            readonly property color warning: "#E5BF00"
            readonly property color shadow: "#D0000000"
        }
        readonly property var font: QtObject {
            readonly property string family: "Monospace"
            // Size in pixels of all fonts. The actual size of fonts in
            // individual components will be proportial to this value.
            readonly property real size: 10
            readonly property int weight: 600
        }
        readonly property var widget: QtObject {
            // Size in pixels of all widgets. The actual size of
            // individual widgets will be proportial to this value.
            readonly property real size: 18
        }
        
        readonly property real animationDuration: 100
    }

    readonly property var bar: QtObject {
        readonly property int size: 20
        readonly property int spacing: 10
        readonly property var font: QtObject {
            readonly property string family: "Monospace"
            // Size in pixels of all fonts. The actual size of fonts in
            // individual components will be proportial to this value.
            readonly property real pointSize: 10
            readonly property int weight: 500
        }
    }
    
    readonly property var popup: QtObject {
        readonly property color backdropColor: "transparent"
    }
    
    readonly property var cc: QtObject {
        readonly property color backgroundColor: root.theme.color.background2
        readonly property color menuBackground: "#0d1016" // "#0b1112"
        readonly property color overlayColor: "#20000000"
        readonly property color buttonColor: root.theme.color.inactive
        readonly property color borderColor: root.theme.color.inactive
        readonly property color borderColorUrgent: root.theme.color.error
        readonly property real iconSize: 24
        readonly property real padding: 10
        readonly property real spacing: 10
        readonly property real width: 600
        readonly property real radius: 4
        readonly property real borderWidth: 1
        readonly property var font: QtObject {
            readonly property string family: "Monospace"
            readonly property real pointSize: 11
        }
        readonly property var fontSmall: QtObject {
            readonly property string family: "Monospace"
            readonly property real pointSize: 10
        }
    }
    
    readonly property var notifications: QtObject {
        readonly property real popupExpireSeconds: 20
    }
    
    readonly property var menu: QtObject {
        readonly property int iconSize: 18
        readonly property color hoverBackground: "#12161e"
        readonly property color disabledColor: root.theme.color.textMuted
        readonly property color separatorColor: "#15161e"
        readonly property int spacing: 0
        readonly property int colSpacing: 10
        readonly property int padding: 4
        readonly property var font: QtObject {
            readonly property string family: "Monospace"
            // Size in pixels of all fonts. The actual size of fonts in
            // individual components will be proportial to this value.
            readonly property real pointSize: 10
        }
    }

    readonly property var osd: QtObject {
        readonly property color backgroundColor: root.theme.color.background2
        readonly property color progressTrackColor: "#005973"
        readonly property color progressBarColor: root.theme.color.active
        readonly property color textColor: "#FFFFFF"
        readonly property var font: QtObject {
            readonly property string family: "Monospace"
            // Size in pixels of all fonts. The actual size of fonts in
            // individual components will be proportial to this value.
            readonly property real pointSize: 11
            readonly property int weight: 600
        }
    }

    readonly property var focusedWindow: QtObject {
        readonly property bool enabled: true
        readonly property var icon: QtObject {
            readonly property bool enabled: false
            readonly property real scale: 0.9
        }
        readonly property var title: QtObject {
            readonly property bool enabled: true
        }
        readonly property var font: root.bar.font
    }

    readonly property var battery: QtObject {
        readonly property bool enabled: true
        readonly property real scale: 1.5
        readonly property int low: 20
        readonly property int critical: 10
        readonly property int suspend: 5
        readonly property bool automaticSuspend: true
        readonly property bool showPercentage: false
    }

    readonly property var datetime: QtObject {
        readonly property bool enabled: true
        readonly property real scale: 1
        readonly property var time: QtObject {
            readonly property bool enabled: true
            readonly property string format: "hh:mm"
        }
        readonly property var date: QtObject {
            readonly property bool enabled: false
            readonly property string format: "yyyy-MM-dd"
        }
        readonly property var font: root.theme.font
    }

    readonly property var workspaces: QtObject {
        readonly property bool enabled: true
        readonly property var icon: QtObject {
            readonly property real scale: 0.7
            readonly property real radius: 1
        }
        
        readonly property color inactiveColor: "#333333"
    }

    readonly property var systray: QtObject {
        readonly property bool enabled: true
    }

    function audioIcon(volume, muted) {
        if (muted) {
            return "audio-volume-muted"
        }
        if (volume < 0.33) {
            return "audio-volume-low"
        }
        if (volume < 0.66) {
            return "audio-volume-medium"
        }
        if (volume <= 1.00) {
            return "audio-volume-high"
        }
        return "audio-volume-overamplified"
    }
    
    function checkboxIcon(state) {
        if (state == Qt.Checked || state === true) {
            return "checkbox"
        }
        if (state == Qt.PartiallyChecked) {
            return "checkbox-partially-checked"
        }
        return "box"
    }
    
    function radioButtonIcon(state) {
        if (state == Qt.Checked || state === true) {
            return "checkbox"
        }
        if (state == Qt.PartiallyChecked) {
            return "checkbox-partially-checked"
        }
        return "box-symbolic"
    }
}
