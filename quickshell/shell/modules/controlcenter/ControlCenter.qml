pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.utils
import qs.modules.controlcenter
import qs.services as Services

Item {
    id: root

    function open() {
        shouldShow = true;
    }
    function close() {
        shouldShow = false;
    }

    function openPopup(comp, props) {
        root.open();
        // _openPopup(comp, props);
    }

    signal _openPopup(comp: var, props: var)

    property bool shouldShow: false
    property real panelOpacity: root.shouldShow ? 1.0 : 0

    Behavior on panelOpacity {
        NumberAnimation {
            duration: Config.theme.animationDuration
        }
    }

    LazyLoader {
        id: loader
        active: root.shouldShow || root.panelOpacity > 0

        PanelWindow {
            id: overlayPanel
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.focusable: true

            anchors {
                top: true
                bottom: true
                right: true
                left: true
            }

            color: ColorUtils.transparentize(Config.cc.overlayColor, 1 - root.panelOpacity)

            Rectangle {
                id: cc

                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.rightMargin: -Config.cc.width * (1 - root.panelOpacity)
                implicitWidth: Config.cc.width

                color: Config.cc.backgroundColor
                layer.enabled: true
                opacity: root.panelOpacity
                // border.color: Config.cc.borderColor
                // border.width: Config.cc.borderWidth

                layer.effect: MultiEffect {
                    shadowEnabled: true
                    // The vertical offset makes the shadow slightly more prominent
                    shadowVerticalOffset: 0
                    shadowHorizontalOffset: 0
                    shadowBlur: 1
                    blurMultiplier: 1
                    shadowColor: Config.theme.color.shadow
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Config.cc.padding * 2
                    spacing: Config.cc.spacing
                    
                    AudioMixer {
                        id: audioMixer
                    }

                    SystrayIconGrid {
                        id: systrayIconGrid
                        Layout.fillWidth: true

                        onShowPopup: (anchor, comp, props) => {
                            root._openPopup(comp, props);
                        }
                    }

                    CCCard {
                        visible: popupLoader.active || animatedHeight > 0
                        border.color: Config.theme.color.active
                        border.width: Config.cc.borderWidth
                        color: Config.theme.color.inactive
                        
                        implicitHeight: animatedHeight + 2 * margin

                        property real animatedHeight: popupLoader.active ? popupLoader.implicitHeight : 0
                        clip: true

                        Behavior on animatedHeight {
                            NumberAnimation {
                                duration: Config.theme.animationDuration
                            }
                        }
                        
                        Loader {
                            id: popupLoader
                            active: false

                            Connections {
                                target: root

                                function on_OpenPopup(comp, props) {
                                    systrayIconGrid.openId = "";
                                    audioMixer.expanded = false
                                    if (comp == null) {
                                        popupLoader.active = false
                                        return
                                    }
                                    popupLoader.sourceComponent = comp;
                                    popupLoader.active = true;
                                    if (props) {
                                        for (var key in props) {
                                            popupLoader.item[key] = props[key];
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Text {
                        Layout.topMargin: 10
                        text: "Notifications"
                        font: Config.cc.font
                        color: Config.theme.color.text
                    }
                    
                    NotificationCenter {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    // Item {
                    //     id: filler
                    //     Layout.fillWidth: true
                    //     Layout.fillHeight: true
                    // }

                    // CCCard {
                    //     Layout.fillWidth: false
                    //     Layout.alignment: Qt.AlignRight
                    //     CalendarWidget {}
                    // }
                }
            }

            MouseArea {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.right: cc.left

                onClicked: root.close()
            }
        }
    }
}
