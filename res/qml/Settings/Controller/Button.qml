import QtQuick
import "."
import Mixxx 1.0 as Mixxx

Base {
    id: root

    property bool pressed: false
    property bool round: false

    height: 20
    type: Mixxx.ControllerElement.Type.Button
    width: 20

    // onModifiersChanged: {
    //     if (root.modifiers.length && root.modifiers[0].valueCount) {
    //         root.pressed = Qt.binding(function(){ return root.values[0]})
    //     }
    // }

    Rectangle {
        anchors.fill: parent
        color: root.pressed ? "red" : "#CCCCCC"
        radius: root.round ? width : 4

        border {
            color: "black"
            width: 1
        }
    }
}
