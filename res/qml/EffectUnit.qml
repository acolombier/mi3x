import "." as Skin
import QtQuick 2.12
import "Theme"

Item {
    id: root

    required property int unitNumber

    implicitHeight: effectContainer.height

    Item {
        id: effectContainer

        anchors.left: parent.left
        anchors.margins: 5
        anchors.right: effectUnitControlsFrame.left
        anchors.top: parent.top
        height: 45

        states: State {
            name: "expanded"
            when: expandButton.checked

            AnchorChanges {
                anchors.left: effectContainer.left
                target: effect1
            }
            AnchorChanges {
                anchors.left: effectContainer.left
                anchors.top: effect1.bottom
                target: effect2
            }
            AnchorChanges {
                anchors.left: effectContainer.left
                anchors.top: effect2.bottom
                target: effect3
            }
            PropertyChanges {
                expanded: true
                target: effect1
                width: parent.width
            }
            PropertyChanges {
                expanded: true
                target: effect2
                width: parent.width
            }
            PropertyChanges {
                expanded: true
                target: effect3
                width: parent.width
            }
            PropertyChanges {
                height: 120
                target: effectContainer
            }
            PropertyChanges {
                target: superKnob
                visible: true
            }
            PropertyChanges {
                target: dryWetKnob
                visible: true
            }
        }
        transitions: Transition {
            AnchorAnimation {
                duration: 150
                targets: [effect1, effect2, effect3]
            }
        }

        Skin.EffectSlot {
            id: effect1

            anchors.left: parent.left
            anchors.top: parent.top
            effectNumber: 1
            expanded: false
            unitNumber: root.unitNumber
            width: parent.width / 3
        }
        Skin.EffectSlot {
            id: effect2

            anchors.left: effect1.right
            anchors.top: parent.top
            effectNumber: 2
            expanded: false
            unitNumber: root.unitNumber
            width: parent.width / 3
        }
        Skin.EffectSlot {
            id: effect3

            anchors.left: effect2.right
            anchors.top: parent.top
            effectNumber: 3
            expanded: false
            unitNumber: root.unitNumber
            width: parent.width / 3
        }
    }
    Rectangle {
        id: effectUnitControlsFrame

        anchors.bottom: parent.bottom
        anchors.margins: 5
        anchors.right: parent.right
        anchors.top: parent.top
        color: Theme.knobBackgroundColor
        radius: 5
        width: effectUnitControls.width

        Column {
            id: effectUnitControls

            anchors.right: parent.right
            anchors.top: parent.top
            padding: 5
            spacing: 10

            add: Transition {
                NumberAnimation {
                    duration: 150
                    from: 0
                    property: "opacity"
                    to: 1
                }
                NumberAnimation {
                    duration: 150
                    from: 0
                    property: "scale"
                    to: 1
                }
            }

            Item {
                height: width
                width: 25

                Skin.Button {
                    id: expandButton

                    activeColor: Theme.effectUnitColor
                    anchors.fill: parent
                    checkable: true
                    text: "▼"
                }
            }
            Skin.ControlKnob {
                id: superKnob

                arcStart: Knob.ArcStart.Minimum
                color: Theme.effectColor
                group: "[EffectRack1_EffectUnit" + root.unitNumber + "]"
                height: 25
                key: "super1"
                visible: false
                width: height

                Skin.FadeBehavior on visible {
                    fadeTarget: superKnob
                }
            }
            Skin.ControlKnob {
                id: dryWetKnob

                arcStart: Knob.ArcStart.Minimum
                color: Theme.effectUnitColor
                group: "[EffectRack1_EffectUnit" + root.unitNumber + "]"
                height: 25
                key: "mix"
                visible: false
                width: height

                Skin.FadeBehavior on visible {
                    fadeTarget: dryWetKnob
                }
            }
        }
    }
}
