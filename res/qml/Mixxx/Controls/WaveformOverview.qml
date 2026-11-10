import Mixxx 1.0 as Mixxx
import Mixxx.Controls 1.0 as MixxxControls
import QtQuick 2.12

Mixxx.WaveformOverview {
    id: root

    required property string group
    property alias mouse: mouse
    readonly property var player: Mixxx.PlayerManager.getPlayer(root.group)

    track: player?.currentTrack

    Mixxx.ControlProxy {
        id: trackLoadedControl

        group: root.group
        key: "track_loaded"

        onValueChanged: value => {
            markers.visible = value;
        }
    }
    Mixxx.ControlProxy {
        id: playPositionControl

        group: root.group
        key: "playposition"
    }
    MouseArea {
        id: mouse

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        onReleased: mouse => {
            playPositionControl.value = mouse.x / this.width;
        }
    }
}
