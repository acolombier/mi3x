import QtQuick
import Qt5Compat.GraphicalEffects

import ".." as Skin
import "../Theme"

Rectangle {
    id: root

    property real flashOpacity: 0.2
    required property var target

    border.color: 'transparent'
    border.width: 1
    color: Qt.alpha(Theme.white, 0.4)
    enabled: animation.running
    opacity: 0
    radius: 6

    Behavior on opacity {
        NumberAnimation {
            duration: 500
            easing.type: Easing.InOutQuad
        }
    }

    Skin.InnerShadowMask {
        anchors.fill: parent
        border.color: Theme.accentColor
        border.width: 1
        layer.enabled: true
        rimColor: Theme.accentColor
        size: Math.max(20, root.target.width * 0.10)

        layer.effect: OpacityMask {
            maskSource: root
        }
    }
    SequentialAnimation {
        id: animation

        loops: 2

        NumberAnimation {
            duration: 500
            easing.type: Easing.Linear
            property: "opacity"
            target: root
            to: root.flashOpacity
        }
        NumberAnimation {
            duration: 500
            easing.type: Easing.InOutQuad
            property: "opacity"
            target: root
            to: 0
        }
        PauseAnimation {
            duration: 200
        }
        NumberAnimation {
            duration: 500
            easing.type: Easing.Linear
            property: "opacity"
            target: root
            to: root.flashOpacity
        }
        NumberAnimation {
            duration: 500
            easing.type: Easing.InOutQuad
            property: "opacity"
            target: root
            to: 0
        }
        PauseAnimation {
            duration: 1000
        }
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        onEntered: {
            animation.stop();
            root.opacity = 0;
        }
    }
    Connections {
        function onActivated() {
            animation.start();
        }

        target: root.target
    }
}
