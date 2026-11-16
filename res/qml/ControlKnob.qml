import "." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick 2.12

Skin.Knob {
    id: root

    property alias controlProxy: control
    property alias group: control.group
    property alias key: control.key

    value: control.parameter

    onTurned: value => {
        control.parameter = value;
    }

    Mixxx.ControlProxy {
        id: control

    }
    TapHandler {
        enabled: root.inputEnabled

        onDoubleTapped: control.reset()
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        enabled: root.inputEnabled

        onPressedChanged: {
            if (pressed) {
                control.reset();
            }
        }
    }
}
