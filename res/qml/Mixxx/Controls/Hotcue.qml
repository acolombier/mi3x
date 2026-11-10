import Mixxx 1.0 as Mixxx
import QtQuick 2.12

Item {
    id: root

    // mixxx::CueType enum values
    enum Type {
        Cue = 1,
        Jump = 5,
        Loop = 4
    }

    property alias activate: hotcueActivateControl.value
    property alias clear: hotcueClearControl.value
    readonly property color color: {
        if (hotcueColorControl.value < 0)
            return null;

        return "#" + hotcueColorControl.value.toString(16).padStart(6, "0");
    }
    property alias colorRaw: hotcueColorControl.value
    property alias endPosition: hotcueEndPositionControl.value
    /// Engine sample end position of the hotcue (-1 if unset)
    required property string group
    required property int hotcueNumber
    readonly property bool isActive: hotcueStatusControl.value == 2
    readonly property bool isSet: hotcueStatusControl.value != 0
    property alias position: hotcuePositionControl.value
    property alias status: hotcueStatusControl.value
    property alias type: hotcueTypeControl.value

    /// Engine sample position of the hotcue (-1 if unset)

    function setColor(newColor) {
        hotcueColorControl.value = (parseInt(newColor.r * 255) << 16) | (parseInt(newColor.g * 255) << 8) | parseInt(newColor.b * 255);
    }

    Mixxx.ControlProxy {
        id: hotcueColorControl

        group: root.group
        key: "hotcue_" + root.hotcueNumber + "_color"
    }
    Mixxx.ControlProxy {
        id: hotcueActivateControl

        group: root.group
        key: "hotcue_" + root.hotcueNumber + "_activate"
    }
    Mixxx.ControlProxy {
        id: hotcueStatusControl

        group: root.group
        key: "hotcue_" + root.hotcueNumber + "_status"
    }
    Mixxx.ControlProxy {
        id: hotcueClearControl

        group: root.group
        key: "hotcue_" + root.hotcueNumber + "_clear"
    }
    Mixxx.ControlProxy {
        id: hotcuePositionControl

        group: root.group
        key: "hotcue_" + root.hotcueNumber + "_position"
    }
    Mixxx.ControlProxy {
        id: hotcueEndPositionControl

        group: root.group
        key: "hotcue_" + root.hotcueNumber + "_endposition"
    }
    Mixxx.ControlProxy {
        id: hotcueTypeControl

        group: root.group
        key: "hotcue_" + root.hotcueNumber + "_type"
    }
}
