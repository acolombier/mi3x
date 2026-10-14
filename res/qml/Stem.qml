import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Shapes
import "Theme"
import "." as Skin

Item {
    id: stem

    required property color color

    // Whether the stem item should render as compact, single line item
    property bool compact: false
    readonly property string fxGroup: `[QuickEffectRack1_${group}]`
    required property string group
    required property int index
    required property string label

    Rectangle {
        id: backgroundColor

        anchors.fill: parent
        color: stem.color
        opacity: stemMute.value ? 0.25 : 0.75
        radius: 1
    }
    Item {
        id: stemButton

        height: stem.compact ? undefined : parent.height / 3 * 2

        // width: parent.width / 3 * 2

        anchors {
            bottom: stem.compact ? parent.bottom : stemFxSelector.top
            left: stem.compact ? compactVolumeKnob.right : parent.left
            right: stem.compact ? stemFxSelector.left : stemVolume.left
            top: parent.top
        }
        Rectangle {
            // Used as a shadow overlay around the controls
            id: contentStemButton

            anchors.fill: parent
            color: stem.color
            opacity: stemMute.value ? 0.25 : 1.0
            radius: 1

            border {
                color: '#1C1C1C'
                width: 1
            }
        }
        Item {
            anchors.fill: parent
            anchors.leftMargin: stem.compact ? 6 : undefined
            anchors.margins: stem.compact ? -1 : 6
            clip: true

            Label {
                id: stemLabel

                readonly property bool rotated: fontMetrics.advanceWidth > parent.width && parent.height >= parent.width

                anchors.centerIn: parent
                color: Theme.white
                elide: Text.ElideRight
                font.weight: Font.DemiBold
                horizontalAlignment: rotated || stem.compact ? Text.AlignLeft : Text.AlignHCenter
                text: stem.label
                width: rotated ? parent.height : parent.width

                transform: Rotation {
                    angle: stemLabel.rotated && !stem.compact ? 90 : 0
                    origin.x: stemLabel.width / 2
                    origin.y: stemLabel.height / 2
                }

                TextMetrics {
                    id: fontMetrics

                    font: stemLabel.font
                    text: stem.label
                }
            }
        }
        Mixxx.ControlProxy {
            id: stemMute

            group: stem.group
            key: "mute"
        }
        TapHandler {
            onTapped: stemMute.value = !stemMute.value
        }
    }
    Skin.ComboBox {
        id: stemFxSelector

        clip: true
        currentIndex: fxSelect.value == -1 ? 0 : fxSelect.value
        font.pixelSize: 10
        height: 20
        indicator.visible: false
        model: Mixxx.EffectsManager.quickChainPresetModel
        popupMaxItem: 8
        popupWidth: 100
        spacing: 2
        textRole: "display"
        width: !anchors.left ? 60 : undefined

        onActivated: index => {
            fxSelect.value = index;
        }

        anchors {
            bottom: parent.bottom
            left: stem.compact ? undefined : parent.left
            right: stemFxKnob.left
        }
        Mixxx.ControlProxy {
            id: fxSelect

            group: stem.fxGroup
            key: "loaded_chain_preset"
        }
    }
    Item {
        id: stemVolume

        visible: !stem.content
        width: stemFxSelector.height

        anchors {
            bottom: stemFxKnob.top
            bottomMargin: 3
            // left: stemButton.right
            right: parent.right
            top: parent.top
        }

        // Skin.VuMeter {
        //     x: 15
        //     y: (parent.height - height) / 2
        //     width: 4
        //     height: parent.height - 40
        //     group: stem.group
        //     key: "vu_meter_left"
        // }

        // Skin.VuMeter {
        //     x: parent.width - width - 15
        //     y: (parent.height - height) / 2
        //     width: 4
        //     height: parent.height - 40
        //     group: stem.group
        //     key: "vu_meter_right"
        // }

        Skin.ControlFader {
            id: volumeSlider

            anchors.bottomMargin: 5
            anchors.fill: parent
            barColor: Theme.volumeSliderBarColor
            barMargin: 2
            bg: Theme.imgVolumeSliderBackground
            group: stem.group
            // implicitWidth: 10
            key: "volume"
            visible: !stem.compact

            handleImage {
                width: parent.width - 4
            }
        }
    }
    Item {
        id: stemFxKnob

        height: stemFxSelector.height
        width: stemFxSelector.height

        anchors {
            bottom: parent.bottom
            right: parent.right
        }
        Skin.QuickFxKnob {
            anchors.centerIn: parent
            group: stem.fxGroup
            height: width
            width: Math.min(parent.width, parent.height)

            knob {
                arcStyle: ShapePath.DashLine
                arcStylePattern: [2, 2]
                color: Theme.eqFxColor
                height: width
                width: width
            }
        }
    }
    Skin.ControlKnob {
        id: compactVolumeKnob

        color: Theme.eqMidColor
        group: stem.group
        key: "volume"
        visible: stem.compact
        width: height

        anchors {
            bottom: parent.bottom
            left: parent.left
            top: parent.top
        }
    }
}
