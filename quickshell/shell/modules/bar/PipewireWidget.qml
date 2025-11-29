import Quickshell.Services.Pipewire
import QtQuick.Layouts
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root
    property real size: 20
    implicitWidth: size + 4
    implicitHeight: size
    color: hover.hovered ? Config.theme.color.inactive : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Config.theme.animationDuration
        }
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property real volume: Pipewire.defaultAudioSink?.audio.volume || 0.0
    readonly property bool muted: Pipewire.defaultAudioSink?.audio.muted || false

    AsyncScrollHandler {
        value: root.volume
        onScrolled: position => {
            Pipewire.defaultAudioSink.audio.volume = position;
        }
    }

    HoverHandler {
        id: hover
    }

    SystemIcon {
        anchors.centerIn: parent
        anchors.margins: 3
        source: Config.audioIcon(root.volume, root.muted)
        size: root.size
    }
}
