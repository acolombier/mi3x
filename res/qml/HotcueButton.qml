import "." as Skin
import QtQuick 2.12
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Controls 2

Item {
    id: root

    required property var currentTrack
    required property string group
    required property int hotcueNumber
    required property var label

    /// String mirror of the (possibly unset) label, for UI tests
    readonly property string labelText: label === undefined || label === null ? "" : String(label)

    Skin.Hotcue {
        id: hotcue

        activate: activator.pressed
        group: root.group
        hotcueNumber: root.hotcueNumber

        onIsSetChanged: {
            if (!isSet)
                popup.close();
        }
    }
    Skin.HotcuePopup {
        id: popup

        currentTrack: root.currentTrack
        hotcue: hotcue
    }
    Rectangle {
        id: backgroundImage

        anchors.fill: parent
        color: hotcue.isSet ? hotcue.color : '#2B2B2B'

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: (eventPoint, button) => popup.openFrom(root)
            onLongPressed: () => popup.openFrom(root)
        }

        TapHandler {
            id: activator
            acceptedButtons: Qt.LeftButton
        }
    }
    DropShadow {
        id: effect1

        anchors.fill: backgroundImage
        color: "#80000000"
        horizontalOffset: 0
        radius: 1.0
        source: backgroundImage
        verticalOffset: 0
    }
    InnerShadow {
        id: effect2

        anchors.fill: parent
        color: "#353535"
        horizontalOffset: 1
        radius: 12
        samples: 24
        source: effect1
        spread: 0.2
        verticalOffset: 1
    }
    InnerShadow {
        anchors.fill: parent
        color: "#353535"
        horizontalOffset: -1
        radius: 12
        samples: 24
        source: effect2
        spread: 0.2
        verticalOffset: -1
    }
    ColumnLayout {
        anchors.centerIn: backgroundImage
        spacing: 0

        Label {
            Layout.alignment: Qt.AlignHCenter
            color: "#626262"
            font.pixelSize: 14
            font.weight: Font.Bold
            text: `${index + 1}`
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            color: "#626262"
            font.pixelSize: 12
            objectName: "hotcueButtonLabel" + root.hotcueNumber
            text: root.label ?? ""
            visible: !!root.label
        }
    }
}
