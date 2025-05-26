import QtQuick
import QtQuick.Controls 2.15
import QtQuick.Effects
import "Theme"

FocusScope {
    id: root

    property alias background: backgroundInput
    property alias input: inputField

    Rectangle {
        id: backgroundInput

        anchors.fill: parent
        color: '#232323'
        radius: 4

        border {
            color: '#353535'
            width: 1
        }
    }
    MultiEffect {
        anchors.fill: parent
        shadowBlur: 0.15
        shadowColor: "#000000"
        shadowEnabled: true
        source: backgroundInput
    }
    TextInput {
        id: inputField

        anchors.fill: parent
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.margins: 7
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: acceptableInput ? "#FFFFFF" : "#7D3B3B"
        focus: true
        horizontalAlignment: TextInput.AlignLeft
    }
}
