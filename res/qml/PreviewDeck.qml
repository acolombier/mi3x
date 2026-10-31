import "." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "Theme"
import "Deck" as DeckComponent

Rectangle {
    id: root

    readonly property var group: "[PreviewDeck1]"
    readonly property var player: Mixxx.PlayerManager.getPlayer(root.group)

    clip: true
    color: Theme.deckBackgroundColor

    Image {
        id: coverArt

        anchors.fill: root.height > 200 ? undefined : parent
        asynchronous: true
        layer.enabled: true
        source: root.player.currentTrack?.coverArtUrl
        width: parent.width

        layer.effect: MultiEffect {
            blur: root.height > 150 ? 0 : 1.5
            blurEnabled: true
            blurMax: 32

            Behavior on blur {
                NumberAnimation {
                    duration: 1500
                }
            }
        }
    }
    Rectangle {
        id: footer

        property real backgroundAlpha: root.height > 150 ? 0.9 : 0.4

        anchors.bottom: parent.bottom
        height: layout.height
        width: parent.width

        Behavior on backgroundAlpha {
            NumberAnimation {
                duration: 1500
            }
        }
        gradient: Gradient {
            orientation: Gradient.vertical

            GradientStop {
                color: Qt.alpha(Theme.backgroundColor, footer.backgroundAlpha)
                position: 1
            }
            GradientStop {
                color: Qt.alpha(Theme.backgroundColor, footer.backgroundAlpha)
                position: 0.35
            }
            GradientStop {
                color: 'transparent'
                position: 0
            }
        }

        GridLayout {
            id: layout

            anchors.bottom: parent.bottom
            columns: 2
            rowSpacing: 0
            width: parent.width

            ScrollingText {
                id: detailViewport

                Layout.alignment: Qt.AlignBottom
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.margins: 3
                Layout.topMargin: 20
                color: 'transparent'

                text {
                    color: Theme.lightGray2
                    font.bold: true
                    font.pixelSize: 16
                    text: `${root.player.currentTrack.title} - ${root.player.currentTrack.artist}`
                }
            }
            Mixxx.WaveformOverview {
                id: waveformOverview

                Layout.fillWidth: true
                Layout.preferredHeight: 60
                track: root.player.currentTrack
            }
            DeckComponent.PlayButton {
                Layout.preferredHeight: 60
                Layout.preferredWidth: 60
                group: root.group
            }
        }
    }
    Mixxx.PlayerDropArea {
        anchors.fill: parent
        group: root.group
        player: root.player
    }
}
