import "." as Skin
import QtQuick 2

Skin.Button {
    id: root

    required property string group
    required property string key
    property string rightKey
    property bool toggleable: false

    function toggle() {
        controlBehavior.toggleControl();
    }

    highlight: controlBehavior.isActive

    ControlProxyButtonBehavior {
        id: controlBehavior

        anchors.fill: parent
        group: root.group
        handlePointerInput: true
        key: root.key
        rightClickKey: root.rightKey
        toggleable: root.toggleable
    }
}
