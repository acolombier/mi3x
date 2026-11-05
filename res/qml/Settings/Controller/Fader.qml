import QtQuick
import "."
import Mixxx 1.0 as Mixxx

Base {
    id: root

    property bool horizontal: false
    property real value: 0.5

    height: root.attached ? 20 : 40
    resizeable: true
    type: Mixxx.ControllerElement.Type.Fader
    width: 20

    transform: Rotation {
        angle: root.properties.Vertical ? 90 : 0
        origin.x: width / 2
        origin.y: height / 2
    }

    // onModifiersChanged: {
    //     if (root.modifiers.length && root.modifiers[0].valueCount > 4) {
    //         root.value = Qt.binding(function(){ return root.values[0] / root.modifiers[0].valueCount; })
    //     }
    // }

    Rectangle {
        color: "#000000"
        height: parent.height
        radius: 2
        width: 1

        anchors {
            centerIn: parent
        }
        Rectangle {
            color: "#CCCCCC"
            height: 5
            radius: 5
            width: 20

            anchors {
                bottom: parent.bottom
                bottomMargin: (parent.height - height) * root.value
                horizontalCenter: parent.horizontalCenter
            }
            border {
                color: "#000000"
                width: 1
            }
        }
    }
}
