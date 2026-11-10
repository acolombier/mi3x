import Mixxx.Controls 1.0 as MixxxControls
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Shapes 1.12

MixxxControls.WaveformOverviewMarker {
    id: root

    property real pendingNewPosition: -1
    property alias position: marker.x
    property bool showHint: false

    key: "playposition"

    Shape {
        id: shape

        readonly property real indicatorSize: 3

        anchors.fill: parent
        antialiasing: true
        layer.samples: 2
        layer.smooth: true
        visible: root.control.value >= 0

        ShapePath {
            id: path

            startX: marker.x + shape.indicatorSize
            startY: 0
            strokeColor: root.color
            strokeWidth: 1

            PathLine {
                x: marker.x
                y: shape.indicatorSize
            }
            PathLine {
                id: marker

                x: Math.round(root.width * (root.pendingNewPosition >= 0 ? root.pendingNewPosition : root.control.value) * Screen.devicePixelRatio) / Screen.devicePixelRatio
                y: root.height
            }
            PathLine {
                x: marker.x
                y: shape.indicatorSize
            }
            PathLine {
                x: marker.x - shape.indicatorSize - path.strokeWidth
                y: 0
            }
        }
    }
    Rectangle {
        id: label

        anchors.bottom: root.bottom
        bottomRightRadius: 4
        color: Qt.alpha('black', 0.6)
        height: text.implicitHeight + 2
        topRightRadius: 4
        visible: root.showHint
        width: text.implicitWidth + 2
        x: Math.min(marker.x, root.width - width)

        Text {
            id: text

            anchors.centerIn: parent
            color: 'white'
            text: control.value

            MixxxControls.TrackTime {
                id: control

                group: root.group
                position: root.pendingNewPosition >= 0 ? pendingNewPosition : playPositionControl.value
            }
            Mixxx.ControlProxy {
                id: playPositionControl

                group: root.group
                key: "playposition"
            }
        }
    }
}
