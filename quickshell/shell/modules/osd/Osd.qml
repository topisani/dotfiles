pragma ComponentBehavior: Bound
import QtQuick.Effects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.widgets

Scope {
    id: root

    // Bind the pipewire node so its volume will be tracked
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Connections {
        target: Pipewire.defaultAudioSink?.audio

        function onVolumeChanged() {
            root.shouldShowOsd = true;
            hideTimer.restart();
        }

        function onMutedChanged() {
            root.shouldShowOsd = true;
            hideTimer.restart();
        }
    }

    readonly property real volume: Pipewire.defaultAudioSink?.audio.volume || 0
    readonly property bool muted: Pipewire.defaultAudioSink?.audio.muted || false
    readonly property string iconSource: Config.audioIcon(volume, muted)

    property bool shouldShowOsd: false
    property real panelOpacity: root.shouldShowOsd ? 1.0 : 0

    Behavior on panelOpacity {
        NumberAnimation {
            duration: 100
        }
    }

    Timer {
        id: hideTimer
        interval: 1000
        onTriggered: root.shouldShowOsd = false
    }

    // The OSD window will be created and destroyed based on shouldShowOsd.
    // PanelWindow.visible could be set instead of using a loader, but using
    // a loader will reduce the memory overhead when the window isn't open.
    LazyLoader {
        active: root.shouldShowOsd || root.panelOpacity > 0

        PanelWindow {
            // Since the panel's screen is unset, it will be picked by the compositor
            // when the window is created. Most compositors pick the current active monitor.

            anchors.right: true
            anchors.bottom: true
            margins.bottom: 0
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay

            implicitHeight: panel.height + 100
            implicitWidth: panel.width + 100

            color: "transparent"

            // An empty click mask prevents the window from blocking mouse events.
            mask: Region {}

            ClippingRectangle {
                anchors.centerIn: parent
                id: panel
                radius: 5
                color: "transparent"
                width: 400
                implicitHeight: 50
                opacity: root.panelOpacity

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    // The vertical offset makes the shadow slightly more prominent
                    shadowVerticalOffset: 0
                    shadowHorizontalOffset: 0
                    shadowBlur: 1
                    blurMultiplier: 1
                    shadowColor: "#40000000"
                }

                Rectangle {
                    anchors.fill: parent
                    color: Config.osd.progressTrackColor

                    Rectangle {
                        visible: !root.muted
                        width: Math.min(root.volume, 1.0) * parent.width
                        color: Config.osd.progressBarColor
                        height: parent.height
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 15
                            rightMargin: 15
                        }

                        spacing: 10

                        SystemIcon {
                            size: 30
                            source: root.iconSource
                        }

                        Text {
                            Layout.horizontalStretchFactor: 2
                            Layout.fillWidth: true
                            verticalAlignment: Text.AlignVCenter
                            text: Pipewire.defaultAudioSink.nickname || Pipewire.defaultAudioSink.description
                            color: Config.osd.textColor
                            font: Config.osd.font
                        }

                        Text {
                            verticalAlignment: Text.AlignVCenter
                            text: root.muted ? "Muted" : `${Math.round(root.volume * 100)}%`
                            color: Config.osd.textColor
                            font: Config.osd.font
                        }
                    }
                }
            }
        }
    }
}
