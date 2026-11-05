import QtQuick
import "."
import Mixxx 1.0 as Mixxx

Base {
    id: root

    property real value: 0.5

    height: 20
    type: Mixxx.ControllerElement.Type.Knob
    width: 20

    transform: Rotation {
        angle: root.value * 270 - 135
        origin.x: root.width / 2
        origin.y: root.height / 2
    }

    // onModifiersChanged: {
    //     if (root.modifiers.length && root.modifiers[0].valueCount > 4) {
    //         root.value = Qt.binding(function(){ return root.values[0] / root.modifiers[0].valueCount;})
    //     }
    // }

    Rectangle {
        anchors.fill: parent
        color: "#CCCCCC"
        radius: parent.width

        border {
            color: "#000000"
            width: 1
        }
        Rectangle {
            color: "#000000"
            height: 10
            radius: 2
            width: 1

            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
            }
        }
    }
}
