import QtQuick

Rectangle {
    id: waveformMask

    property color rimColor: "#000000"
    property real size: 10

    anchors.fill: parent
    color: 'transparent'

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: waveformMask.size

        gradient: Gradient {
            orientation: Gradient.Vertical

            GradientStop {
                color: waveformMask.rimColor
                position: 0
            }
            GradientStop {
                color: "transparent"
                position: 1
            }
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: waveformMask.size

        gradient: Gradient {
            orientation: Gradient.Vertical

            GradientStop {
                color: "transparent"
                position: 0
            }
            GradientStop {
                color: waveformMask.rimColor
                position: 1
            }
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.top: parent.top
        width: waveformMask.size

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                color: waveformMask.rimColor
                position: 0
            }
            GradientStop {
                color: "transparent"
                position: 1
            }
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.top: parent.top
        width: waveformMask.size

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                color: "transparent"
                position: 0
            }
            GradientStop {
                color: waveformMask.rimColor
                position: 1
            }
        }
    }
}
