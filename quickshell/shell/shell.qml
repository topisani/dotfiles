//@ pragma UseQApplication

pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.bar
import qs.modules.osd
import qs.modules.common

ShellRoot {
    id: root
    signal showPopup(anchor: Item, widget: var, props: var)
    property bool barHidden: false

    LazyLoader {
        id: barPopupLoader
        BarPopupWindow {
            id: barPopup
            Connections {
                target: root
                function onShowPopup(anchor, widget, props) {
                    barPopup.showPopup(anchor, widget, props);
                }
            }
        }
    }
    
    Variants {
        model: Quickshell.screens
        
        LazyLoader {
            active: true
            required property var modelData;
            Bar {
                id: bar
                size: Config.bar.size
                color: Config.theme.color.background
                hidden: root.barHidden
                screen: modelData

                onShowPopup: (anchor, widget, properties) => {
                    barPopupLoader.active = true
                    root.showPopup(anchor, widget, properties);
                }
            }
        }
    }

    Osd {}

    IpcHandler {
        target: "shell"

        function toggleBar() {
            root.barHidden = !root.barHidden
        }
    }
}
