import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import "Theme"

Item {
    id: root

    property alias activate: hotcueActivateControl.value
    property alias clear: hotcueClearControl.value
    readonly property color color: {
        if (hotcueColorControl.value < 0)
            return Theme.deckActiveColor;

        return "#" + hotcueColorControl.value.toString(16).padStart(6, "0");
    }
    /// Engine sample end position of the hotcue (-1 if unset)
    readonly property real endPosition: hotcueEndPositionControl.value
    required property string group
    required property int hotcueNumber
    readonly property bool isSet: hotcueStatusControl.value != 0
    /// Engine sample position of the hotcue (-1 if unset)
    readonly property real position: hotcuePositionControl.value
    /// Type of the hotcue (mixxx::CueType: 1 = hotcue, 4 = loop, 5 = jump)
    readonly property int type: hotcueTypeControl.value

    // mixxx::CueType enum values
    readonly property int typeHotCue: 1
    readonly property int typeJump: 5
    readonly property int typeLoop: 4

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
