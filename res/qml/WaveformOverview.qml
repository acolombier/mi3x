import "." as Skin
import Mixxx 1.0 as Mixxx
import Mixxx.Controls 1.0 as MixxxControls
import QtQuick 2.12
import "Theme"

Item {
    id: root

    required property string group

    states: [
        State {
            when: passthroughControl.value == 0

            PropertyChanges {
                opacity: 1
                target: waveformContainer
                visible: true
            }
            PropertyChanges {
                opacity: 0
                target: passthroughContainer
                visible: false
            }
        },
        State {
            when: passthroughControl.value != 0

            PropertyChanges {
                opacity: 0
                target: waveformContainer
                visible: false
            }
            PropertyChanges {
                opacity: 1
                target: passthroughContainer
                visible: true
            }
        }
    ]
    transitions: [
        Transition {
            enabled: passthroughContainer.visible

            SequentialAnimation {
                PropertyAction {
                    property: "visible"
                    target: waveformContainer
                }
                ParallelAnimation {
                    NumberAnimation {
                        duration: 150
                        property: "opacity"
                        target: waveformContainer
                    }
                    NumberAnimation {
                        duration: 150
                        property: "opacity"
                        target: passthroughContainer
                    }
                }
                PropertyAction {
                    property: "visible"
                    target: passthroughContainer
                }
            }
        },
        Transition {
            enabled: waveformContainer.visible

            SequentialAnimation {
                PropertyAction {
                    property: "visible"
                    target: passthroughContainer
                }
                ParallelAnimation {
                    NumberAnimation {
                        duration: 150
                        property: "opacity"
                        target: waveformContainer
                    }
                    NumberAnimation {
                        duration: 150
                        property: "opacity"
                        target: passthroughContainer
                    }
                }
                PropertyAction {
                    property: "visible"
                    target: waveformContainer
                }
            }
        }
    ]

    Mixxx.ControlProxy {
        id: passthroughControl

        group: root.group
        key: "passthrough"
    }
    Rectangle {
        id: waveformContainer

        anchors.fill: parent
        color: Theme.deckBackgroundColor

        MixxxControls.WaveformOverview {
            id: overview

            anchors.fill: parent
            channels: Mixxx.WaveformOverview.Channels.LeftChannel
            colorHigh: Theme.white
            colorLow: Theme.green
            colorMid: Theme.blue
            group: root.group
            renderer: Mixxx.WaveformOverview.Renderer.Filtered

            mouse {
                onPositionChanged: mouse => {
                    playPositionMarker.pendingNewPosition = Qt.binding(() => overview.mouse.containsPress ? mouse.x / overview.width : -1);
                }
            }
            Item {
                id: markers

                anchors.fill: parent
                visible: trackLoadedControl.value

                Rectangle {
                    id: progress

                    color: Qt.alpha('black', 0.6)
                    height: root.height
                    width: playPositionMarker.position
                    x: 0
                }
                Skin.WaveformOverviewLoopMarker {
                    id: loopMarker

                    anchors.fill: parent
                    group: root.group
                }
                Repeater {
                    model: 8

                    Skin.WaveformOverviewHotcueMarker {
                        required property int index

                        anchors.fill: parent
                        group: root.group // qmllint disable unqualified
                        hotcueNumber: this.index + 1
                    }
                }
                Skin.WaveformOverviewPlayMarker {
                    id: playPositionMarker

                    anchors.fill: parent
                    group: root.group
                    showHint: overview.mouse.containsPress
                }
            }
        }
    }
    Rectangle {
        id: passthroughContainer

        anchors.fill: parent
        color: "transparent"

        Skin.SectionText {
            anchors.centerIn: parent
            text: "Passthrough Enabled"
        }
    }
}
