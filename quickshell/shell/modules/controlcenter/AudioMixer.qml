import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.utils

ColumnLayout {
    id: root
    spacing: Config.cc.padding

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property real volume: Pipewire.defaultAudioSink?.audio.volume || 0.0
    readonly property bool muted: Pipewire.defaultAudioSink?.audio.muted || false

    RowLayout {
        spacing: Config.cc.padding
        CCButton {
            icon: Config.audioIcon(root.volume, root.muted)
            state: !root.muted
            onClicked: {
                Pipewire.defaultAudioSink.audio.muted = !root.muted;
            }
        }

        CCSlider {
            Layout.fillWidth: true

            value: root.volume
            onValueChanged: {
                Pipewire.defaultAudioSink.audio.volume = value;
            }
        }
    }

    ColumnLayout {
        id: column
        spacing: 4

        Repeater {
            model: Pipewire.nodes.values.filter(n => n.audio && !n.isStream && n.isSink).sort((a, b) => a.description < b.description)

            Item {
                id: item

                required property PwNode modelData
                property bool isActive: modelData.id == Pipewire.preferredDefaultAudioSink?.id
                Layout.fillWidth: true

                Layout.preferredHeight: Config.cc.iconSize

                RowLayout {
                    Item {
                        implicitHeight: Config.cc.iconSize
                        implicitWidth: Config.cc.iconSize

                        Rectangle {
                            anchors.centerIn: parent
                            radius: Config.cc.iconSize
                            width: Config.cc.iconSize / 4
                            height: width
                            color: item.isActive ? Config.theme.color.active : Config.theme.color.inactive
                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.theme.animationDuration
                                }
                            }
                        }
                    }
                    Text {
                        id: text
                        verticalAlignment: Text.AlignVCenter
                        text: item.modelData.nickname || item.modelData.description
                        color: Config.theme.color.textMuted
                    }
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    onClicked: Pipewire.preferredDefaultAudioSink = parent.modelData
                }

                states: [
                    State {
                        when: item.isActive
                        PropertyChanges {
                            text.color: Config.theme.color.text
                        }
                    },
                    State {
                        when: ma.containsMouse
                        PropertyChanges {
                            text.color: ColorUtils.mix(Config.theme.color.text, Config.theme.color.textMuted, 0.5)
                        }
                    }
                ]
            }
        }
    }
}
