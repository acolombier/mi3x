import Mixxx 1.0 as Mixxx
import Mixxx.Controls 1.0 as MixxxControls
import QtQuick 2.12
import QtQuick.Shapes 1.12
import "Theme"

MixxxControls.Hotcue {
    id: root

    readonly property color renderingColor: Qt.alpha(root.color || Theme.deckActiveColor, mouse.containsMouse ? 0.6 : 1)

    activate: mouse.containsPress
    visible: isSet

    Mixxx.ControlProxy {
        id: trackSamplesControl

        group: root.group
        key: "track_samples"
    }
    Shape {
        id: shapeStart

        anchors.fill: parent
        antialiasing: true
        layer.samples: 2
        layer.smooth: true
        visible: root.isSet

        ShapePath {
            startX: marker.x
            startY: 0
            strokeColor: root.renderingColor
            strokeWidth: 1

            PathLine {
                id: marker

                property bool hovered: false

                x: {
                    const totalSamples = trackSamplesControl.value;
                    return (totalSamples > 0) ? root.width * (root.position / totalSamples) : 0;
                }
                y: root.height
            }
        }
    }
    Rectangle {
        id: label

        bottomRightRadius: 4
        color: root.renderingColor
        height: text.implicitHeight + 2
        topRightRadius: 4
        width: text.implicitWidth + 2
        x: marker.x
        y: marker.y - text.implicitHeight

        Text {
            id: text

            anchors.centerIn: parent
            color: Mixxx.ColorUtils.chooseColorByBrightness(root.renderingColor, Theme.white, Theme.midGray3, 127)
            text: root.hotcueNumber
        }
    }
    Shape {
        id: shapeEnd

        anchors.fill: parent
        antialiasing: true
        layer.samples: 2
        layer.smooth: true
        visible: root.isSet && root.type != MixxxControls.Hotcue.Type.Cue

        ShapePath {
            startX: endMarker.x
            startY: 0
            strokeColor: root.renderingColor
            strokeWidth: 1

            PathLine {
                id: endMarker

                property bool hovered: false

                x: {
                    const totalSamples = trackSamplesControl.value;
                    return (totalSamples > 0) ? root.width * (root.endPosition / totalSamples) : 0;
                }
                y: root.height
            }
        }
    }
    Rectangle {
        id: fill

        readonly property var lowerBound: Math.min(marker.x, endMarker.x)
        readonly property var upperBound: Math.max(marker.x, endMarker.x)

        color: root.type != MixxxControls.Hotcue.Type.Jump ? Qt.alpha(root.renderingColor, 0.3) : Qt.alpha('black', 0.6)
        height: parent.height
        visible: shapeEnd.visible
        width: upperBound - x
        x: lowerBound
    }
    MouseArea {
        id: mouse

        anchors.fill: fill.visible ? fill : label
        hoverEnabled: true
    }
}
