import QtQuick 2.12
import QtQuick.Shapes

Item {
    id: root

    property color primaryColor: '#cf505b'
    property color secondaryColor: '#c20e23'

    Shape {
        anchors.centerIn: parent
        height: 24
        layer.enabled: true
        layer.samples: 16
        width: 24

        // Top handle
        ShapePath {
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            joinStyle: ShapePath.BevelJoin
            startX: 9
            startY: 3
            strokeColor: root.secondaryColor
            strokeWidth: 2

            PathLine {
                x: 15
                y: 3
            }
        }

        // Main bin body
        ShapePath {
            fillColor: root.primaryColor
            startX: 6
            startY: 8
            strokeColor: "transparent"

            PathLine {
                x: 6
                y: 19
            }
            PathArc {
                direction: PathArc.Counterclockwise
                radiusX: 3
                radiusY: 3
                x: 9
                y: 22
            }
            PathLine {
                x: 15
                y: 22
            }
            PathArc {
                direction: PathArc.Counterclockwise
                x: 18
                y: 19
            }
            PathLine {
                x: 18
                y: 8
            }
        }

        // Lid
        ShapePath {
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            joinStyle: ShapePath.BevelJoin
            startX: 4
            startY: 8
            strokeColor: root.secondaryColor
            strokeWidth: 3

            PathLine {
                x: 20
                y: 8
            }
        }

        // Left white slot
        ShapePath {
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            joinStyle: ShapePath.BevelJoin
            startX: 10
            startY: 12
            strokeColor: "#F4F1F1"
            strokeWidth: 2

            PathLine {
                x: 10
                y: 16
            }
        }
        // Right white slot
        ShapePath {
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            joinStyle: ShapePath.BevelJoin
            startX: 14
            startY: 12
            strokeColor: "#F4F1F1"
            strokeWidth: 2

            PathLine {
                x: 14
                y: 16
            }
        }
    }
}
