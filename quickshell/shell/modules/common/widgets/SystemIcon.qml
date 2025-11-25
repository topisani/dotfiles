import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root
    required property real size
    required property string source

    implicitHeight: size
    implicitWidth: size

    function sourcePath(source) {
            if (source === "")
                return "";
            source = source.replace(/^image:\/\/icon\//, "")
            switch (source) {
                case "blueman-active": 
                    source = "bluetooth-activated"
                break;
                case "blueman-tray": 
                    source = "bluetooth"
                break;
                case "blueman-disabled": 
                    source = "bluetooth-inactive"
                break;
            }
            if (source.startsWith("bluetooth")) {
                source = "network-" + source
            }
            if (source.indexOf("/") >= 0) {
                return source;
            }
            return Quickshell.iconPath(source, true);
        }

    IconImage {
        id: image
        source: root.sourcePath(root.source)
        visible: source != "" && status == Image.Ready
        width: root.size
        height: root.size
    }
}
