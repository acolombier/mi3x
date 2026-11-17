import "." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Controls
import "Theme"

Item {
    id: root

    required property int effectNumber
    property bool expanded: false
    readonly property string group: slot.group
    property real maxSelectorWidth: 300
    property Mixxx.EffectSlotProxy slot: Mixxx.EffectsManager.getEffectSlot(unitNumber, effectNumber)
    required property int unitNumber

    height: 35

    Item {
        id: selector

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.top: parent.top
        width: Math.min(root.width, root.maxSelectorWidth)

        Skin.ControlButton {
            id: effectEnableButton

            activeColor: Theme.effectColor
            anchors.left: parent.left
            anchors.margins: 5
            anchors.verticalCenter: parent.verticalCenter
            group: root.group
            key: "enabled"
            text: "ON"
            toggleable: true
            width: 40
        }
        Skin.ComboBox {
            id: effectSelector

            anchors.left: effectEnableButton.right
            anchors.margins: 5
            anchors.right: effectMetaKnob.left
            anchors.verticalCenter: parent.verticalCenter
            currentIndex: {
                const rowCount = effectSelector.model.rowCount();
                for (let i = 0; i < rowCount; i++) {
                    if (effectSelector.model.get(i).effectId === root.slot.effectId) {
                        return i;
                    }
                }
                return -1;
            }
            model: Mixxx.EffectsManager.visibleEffectsModel
            textRole: "display"

            onActivated: index => {
                const effectId = model.get(index).effectId;
                if (root.slot.effectId != effectId)
                    root.slot.effectId = effectId;
            }
        }
        Skin.ControlMiniKnob {
            id: effectMetaKnob

            anchors.bottom: parent.bottom
            anchors.margins: 5
            anchors.right: parent.right
            anchors.top: parent.top
            arcStart: Knob.ArcStart.Minimum
            color: Theme.effectColor
            group: root.group
            key: "meta"
            width: 30
        }
    }
    FocusScope {
        id: focusScope

        anchors.bottom: parent.bottom
        anchors.left: selector.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.top: parent.top

        ListView {
            id: parametersView

            anchors.fill: parent
            model: root.slot.parametersModel
            orientation: ListView.Horizontal
            // clip: true
            spacing: 5
            visible: root.expanded

            ScrollBar.horizontal: ScrollBar {
                // Don't obstruct the component
                anchors.top: parent.bottom
                policy: parametersView.contentWidth > parametersView.width && (handler.hovered || focusScope.activeFocus) ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            }
            delegate: Item {
                id: parameter

                required property string controlKey
                required property int index
                property bool isButton: type == 1
                property bool isKnob: type == 0
                // TODO: Use null coalescing when we switch to Qt >= 5.15
                property string label: shortName ?? name
                required property string name
                property int number: index + 1
                required property string shortName
                required property int type

                height: root.height
                width: 50

                EmbeddedText {
                    anchors.fill: parent
                    font.bold: false
                    text: parameter.label
                    verticalAlignment: Text.AlignBottom
                }
                Skin.ControlMiniKnob {
                    id: parameterKnob

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    arcStart: 0
                    color: Theme.effectColor
                    group: root.group
                    height: width
                    key: parameter.controlKey
                    visible: parameter.isKnob
                    width: 22

                    Mixxx.ControlProxy {
                        id: parameterLoadedControl

                        property bool loaded: value != 0

                        group: root.group
                        key: parameter.controlKey + "_loaded"
                    }
                }
                Skin.ControlButton {
                    id: buttonParameterButton

                    activeColor: Theme.effectColor
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    group: root.group
                    height: 22
                    key: parameter.controlKey
                    text: "ON"
                    toggleable: true
                    visible: parameter.isButton
                    width: parent.width

                    Mixxx.ControlProxy {
                        id: buttonParameterLoadedControl

                        property bool loaded: value != 0

                        group: root.group
                        key: parameter.controlKey + "_loaded"
                    }
                }
            }
            Skin.FadeBehavior on opacity {
                fadeTarget: parametersView
            }
            populate: Transition {
                NumberAnimation {
                    duration: 200
                    from: 0
                    property: "opacity"
                    to: 1
                }
                NumberAnimation {
                    duration: 200
                    from: 0
                    property: "scale"
                    to: 1
                }
            }

            HoverHandler {
                id: handler

            }
        }
    }
}
