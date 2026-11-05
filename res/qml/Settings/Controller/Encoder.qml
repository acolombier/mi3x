import QtQuick
import "."
import Mixxx 1.0 as Mixxx

Base {
    id: root

    property bool pressed: false
    property bool touched: false
    property real value: 0

    height: 20
    type: Mixxx.ControllerElement.Type.Encoder
    width: 20

    transform: Rotation {
        angle: root.value * 360
        origin.x: root.width / 2
        origin.y: root.height / 2
    }

    onValueChanged: {
        console.log(root.value);
    }

    // onModifiersChanged: {
    //     if (!root.modifiers.length){
    //         return;
    //     }
    //     let maxValue = root.modifiers.reduce(
    //         (accumulator, currentValue) => Math.max(accumulator, currentValue.valueCount),
    //         0,
    //     );

    //     let valueIdx = -1;
    //     if (maxValue > 3) {
    //         for (let i = 0; i < root.modifiers.length; i++){
    //             if (root.modifiers[i].valueCount != maxValue) continue;
    //             root.value = Qt.binding(function(){ return root.values[i] / root.modifiers[i].valueCount;})
    //             valueIdx = i;
    //             break
    //         }
    //     }
    //     let attachedPressed = false;
    //     let attachedTouched = false;
    //     if (root.modifiers.length > 1 || valueIdx == -1){
    //         for (let i = 0; i < root.modifiers.length && (!attachedTouched || !attachedPressed); i++){
    //             if (i == valueIdx) continue;

    //             if (!attachedPressed){
    //                 root.pressed = Qt.binding(function(){ return root.values[i] & 0x1;})
    //                 attachedPressed = true
    //                 if (root.modifiers[i].valueCount > 2 && !attachedTouched){
    //                     root.touched = Qt.binding(function(){ return root.values[i] & 0x2;})
    //                     attachedTouched = true
    //                 }
    //             } else {
    //                 root.touched = Qt.binding(function(){ return root.values[i];})
    //                 attachedTouched = true
    //             }
    //         }
    //     }

    //     // for (let modifier in modifiers) {
    //     // if (root.modifiers.length && root.modifiers[0].valueCount > 4) {
    //     //     root.value = Qt.binding(function(){ return root.values[0] / root.modifiers[0].valueCount;})
    //     // }
    // }

    Rectangle {
        anchors.fill: parent
        color: root.pressed ? "red" : "#CCCCCC"
        radius: parent.width

        border {
            color: root.touched ? "green" : "black"
            width: 1
        }
        Rectangle {
            color: "black"
            height: 10
            radius: 2
            width: 2

            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                topMargin: parent.height / 4
            }
        }
    }
}
