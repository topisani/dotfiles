import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root
    required property real size
    required property string source
    readonly property bool isValid: sourcePath != ""

    implicitHeight: size
    implicitWidth: size

    readonly property string sourcePath: {
        let res = source
        // console.error("Requested icon", res)
        if (res === "")
            return "";
        res = res.replace(/^image:\/\/icon\//, "")
        switch (res) {
            case "blueman-active": 
                res = "bluetooth-activated"
            break;
            case "blueman-tray": 
                res = "bluetooth"
            break;
            case "blueman-disabled": 
                res = "bluetooth-inactive"
            break;
        }
        if (res.startsWith("bluetooth")) {
            res = "network-" + res
        }
        if (res.indexOf("/") >= 0) {
            return res;
        }
        return Quickshell.iconPath(res, true);
    }

    IconImage {
        id: image
        source: root.sourcePath
        visible: root.isValid
        width: root.size
        height: root.size
    }
}
