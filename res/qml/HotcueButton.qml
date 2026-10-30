import "." as Skin
import QtQuick 2.12
import QtQuick.Effects
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
        border.color: 'transparent'
        border.width: 1
        color: hotcue.isSet ? hotcue.color : '#2B2B2B'
        radius: 3

        TapHandler {
            acceptedButtons: Qt.RightButton

            onLongPressed: () => popup.openFrom(root)
            onTapped: (eventPoint, button) => popup.openFrom(root)
        }
        TapHandler {
            id: activator

            acceptedButtons: Qt.LeftButton
        }
        Skin.InnerShadowMask {
            border.color: Qt.darker(hotcue.isSet ? hotcue.color : '#2B2B2B', 2)
            border.width: 1
            layer.enabled: true
            radius: parent.radius
            rimColor: border.color
            size: 6
            visible: hotcue.activate || hotcue.isActive

            layer.effect: OpacityMask {
                maskSource: backgroundImage
            }
        }
    }
    MultiEffect {
        anchors.fill: backgroundImage
        autoPaddingEnabled: true
        blurMultiplier: 0.14
        shadowBlur: hotcue.activate ? 0.84 : 0.64
        shadowColor: Qt.lighter(hotcue.isSet ? hotcue.color : '#2B2B2B', 1.5)
        shadowEnabled: true
        source: backgroundImage
    }
    ColumnLayout {
        anchors.centerIn: backgroundImage
        spacing: 0

        Label {
            Layout.alignment: Qt.AlignHCenter
            color: "#626262"
            font.pixelSize: 14
            font.weight: Font.Bold
            text: root.hotcueNumber
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
