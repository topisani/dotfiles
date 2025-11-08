import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root
    required property real size
    required property string source

    implicitHeight: size
    implicitWidth: size

    readonly property string sourcePath: (() => {
            console.debug("test")
            if (!source)
                return "";
            if (source.indexOf("/") >= 0) {
                return source;
            }
            let res = Quickshell.iconPath(source, "");
            return res
        })()

    IconImage {
        id: image
        source: root.sourcePath
        visible: root.sourcePath
        width: root.size
        height: root.size
    }
}
