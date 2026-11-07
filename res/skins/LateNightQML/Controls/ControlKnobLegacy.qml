// Reference snapshot of res/qml/ControlKnob.qml taken before the
// signal-parameter and library-drag fixes. Kept dormant for LateNightQML
// evolution; not imported anywhere.
import "../../../qml" as Skin
import Mixxx 1.0 as Mixxx
import QtQuick 2.12

Skin.Knob {
    id: root

    property alias group: control.group
    property alias key: control.key

    value: control.parameter
    onTurned: control.parameter = value

    Mixxx.ControlProxy {
        id: control
    }

    TapHandler {
        onDoubleTapped: control.reset()
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: control.reset()
    }
}
