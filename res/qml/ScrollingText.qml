import Mixxx 1.0 as Mixxx
import QtQuick 2.12

Item {
    id: root

    property color color: 'white'
    property alias text: detailText
    property var wrap: Text.NoWrap

    clip: true
    implicitHeight: detailText.implicitHeight

    onWidthChanged: {
        if (tickerAnimation.running)
            tickerAnimation.restart();
    }

    Text {
        id: detailText

        readonly property var maxScrollingOffset: Math.min(0, root.width - detailText.width)

        text: root.text
        width: root.wrap != Text.NoWrap ? parent.width : undefined
        wrapMode: root.wrap

        onWidthChanged: {
            if (tickerAnimation.running)
                tickerAnimation.restart();
        }

        SequentialAnimation {
            id: tickerAnimation

            loops: Animation.Infinite
            running: detailText.width > detailText.parent.width && root.wrap == Text.NoWrap

            // 1. Let the beginning be read
            PauseAnimation {
                duration: 1000
            }

            // 2. Scroll slowly to reveal the end
            NumberAnimation {
                duration: Math.max(2500, (detailText.width - root.width) * 25)
                easing.type: Easing.Linear
                property: "x"
                target: detailText
                to: detailText.maxScrollingOffset
            }

            // 3. Keep the end visible
            PauseAnimation {
                duration: 1000
            }

            // 4. Fade out
            NumberAnimation {
                duration: 350
                easing.type: Easing.InOutQuad
                property: "opacity"
                target: detailText
                to: 0
            }

            // 5. Reset position and opacity
            PropertyAction {
                property: "x"
                target: detailText
                value: 0
            }
            NumberAnimation {
                duration: 250
                easing.type: Easing.InOutQuad
                property: "opacity"
                target: detailText
                to: 1
            }
        }
    }
    Rectangle {
        id: leftGradient

        color: 'transparent'
        opacity: detailText.x == 0 ? 0 : 1
        width: 10

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                color: root.color
                position: 0
            }
            GradientStop {
                color: 'transparent'
                position: 1
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 500
            }
        }

        anchors {
            bottom: parent.bottom
            left: parent.left
            top: parent.top
        }
    }
    Rectangle {
        id: rightGradient

        color: 'transparent'
        opacity: detailText.x == detailText.maxScrollingOffset ? 0 : 1
        width: 10

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                color: root.color
                position: 1
            }
            GradientStop {
                color: 'transparent'
                position: 0
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 500
            }
        }

        anchors {
            bottom: parent.bottom
            right: parent.right
            top: parent.top
        }
    }
}
