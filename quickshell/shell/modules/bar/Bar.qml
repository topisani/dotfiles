pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.controlcenter
import qs.services as Services

Item {
    id: root
    property int size: 30
    property color color: "gray"

    property bool hidden: false

    signal showPopup(Item anchor, var popupContent, var properties)
    signal setCcOpen(bool open)
    
    property bool showTopLayer: !hidden || Services.Niri.overviewOpen
    property bool reserveSpace: showTopLayer
    property bool topLayerShadow: Services.Niri.overviewOpen
    required property var screen
    required property bool ccOpen
    property bool popupOpen: false

    PanelWindow {
        id: bottomLayerWindow
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.focusable: true
        exclusionMode: ExclusionMode.Ignore
        screen: root.screen
        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: root.size + 100
        color: "transparent"

        Rectangle {
            id: bottomLayerContainer
            anchors.top: parent.top
            height: root.size + 2 // Helps with flickering during animations
            color: root.color
            width: parent.width
            
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                // The vertical offset makes the shadow slightly more prominent
                shadowVerticalOffset: 0
                shadowHorizontalOffset: 0
                shadowBlur: 1
                blurMultiplier: 1
                shadowColor: Config.theme.color.shadow
            }
        }
        
    }

    PanelWindow {
        id: topLayerWindow
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        // WlrLayershell.focusable: true

        implicitHeight:root.size + (50 * root.topLayerShadow)
        // visible: !root.hidden; // || barContent.opacity > 0
        screen: root.screen

        exclusiveZone: root.reserveSpace ? root.size : 0
        Behavior on exclusiveZone {
            NumberAnimation {
                duration: Config.theme.animationDuration
            }
        }
        
        mask: Region {
            item: topLayerContainer
        }
        
        anchors {
            top: true
            left: true
            right: true
        }

        Rectangle {
            id: topLayerContainer
            anchors.top: parent.top
            width: parent.width
            color: "transparent"
            height: root.showTopLayer * root.size
            
            Behavior on height {
                NumberAnimation {
                    duration: Config.theme.animationDuration
                }
            }
            
            layer.enabled: root.topLayerShadow
            layer.effect: MultiEffect {
                shadowEnabled: true
                // The vertical offset makes the shadow slightly more prominent
                shadowVerticalOffset: 0
                shadowHorizontalOffset: 0
                shadowBlur: 1
                blurMultiplier: 1
                shadowColor: Config.theme.color.shadow
            }
        }
    }

    property bool showOverlay: (root.ccOpen || root.popupOpen) && root.showTopLayer

    PanelWindow {
        id: overlayLayerWindow
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.focusable: true

        implicitHeight: root.size
        screen: root.screen

        mask: Region {
            item: overlayLayerContainer
        }

        anchors {
            top: true
            left: true
            right: true
        }

        Rectangle {
            id: overlayLayerContainer
            anchors.top: parent.top
            width: parent.width
            color: "transparent"
            height: root.showOverlay ? root.size : 0
        }
    }

    Rectangle {
        id: barContent
        parent: root.showOverlay ? overlayLayerContainer : (root.showTopLayer ? topLayerContainer : bottomLayerContainer)
        anchors.fill: parent
        color: root.color

        RowLayout {
            id: leftLayout
            spacing: Config.bar.spacing
            implicitHeight: root.size
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                leftMargin: 5
                top: parent.top
            }

            Workspaces {}
        }

        RowLayout {
            id: centerLayout
            spacing: Config.bar.spacing
            implicitHeight: root.size

            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
            }
            FocusedWindow {}
        }

        RowLayout {
            id: rightLayout
            spacing: Config.bar.spacing

            anchors {
                verticalCenter: parent.verticalCenter
                right: parent.right
            }

            PipewireWidget {
                id: pipewire
                size: root.size
                Component {
                    id: audioMixer
                    AudioMixer {
                        alwaysShowOutputSelector: true
                    }
                }
                TapHandler {
                    onTapped: { root.popupOpen = true; root.showPopup(pipewire, audioMixer, {}); }
                }
            }

            Battery {
                visible: Services.Battery.available
                size: root.size
            }

            DateTime {
                id: dateTime
                Component {
                    id: calendarWidget
                    CalendarWidget {}
                }
                TapHandler {
                    onTapped: { root.popupOpen = true; root.showPopup(dateTime, calendarWidget, {}); }
                }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: {
                        const iso = Qt.formatDateTime(new Date(), "yyyy-MM-dd");
                        Quickshell.execDetached(["sh", "-c", "echo -n '" + iso + "' | wl-copy"]);
                        Quickshell.execDetached(["notify-send", "--transient", "-a", "Shell", "Copied date", iso]);
                    }
                }
            }

            SystemTrayWidget {
                onShowPopup: (anchor, comp, props) => { root.popupOpen = true; root.showPopup(anchor, comp, props); }
            }
            
            BarButton {
                id: overflowButton
                implicitWidth: root.size
                implicitHeight: root.size
                SystemIcon {
                    source: "overflow-menu-symbolic"
                    size: root.size
                }

                Component {
                    id: systrayFilterMenu
                    SystrayFilterMenu {}
                }

                onClicked: {
                    root.setCcOpen(!root.ccOpen)
                }

                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: { root.popupOpen = true; root.showPopup(overflowButton, systrayFilterMenu, {}); }
                }
            }
        }
    }
}
