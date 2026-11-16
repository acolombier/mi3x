import QtQuick 2.12

Behavior {
    id: root

    property int duration: 150

    // Starting with QtQuick 2.15, we can use targetProperty.object here
    property Item fadeTarget

    SequentialAnimation {
        // If the opacity is 1, animate it down to 0
        NumberAnimation {
            duration: root.duration
            easing.type: Easing.InQuad
            from: 1
            property: "opacity"
            target: root.fadeTarget
            to: 0
        }

        // Actually change the property value (i.e. "visible")
        PropertyAction {
        }

        // If the opacity is 0, animate it up to 1
        NumberAnimation {
            duration: root.duration
            easing.type: Easing.OutQuad
            from: 0
            property: "opacity"
            target: root.fadeTarget
            to: 1
        }
    }
}
