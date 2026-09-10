import Mixxx 1.0 as Mixxx
import QtQuick.Shapes
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import QtQuick 2.12
import ".." as Skin
import "../Settings" as SettingComponents
import "../Theme"

Item {
    id: root

    property color buttonColor: trackLoadedControl.value > 0 ? Theme.buttonActiveColor : Theme.buttonDisableColor
    required property string group
    readonly property var toolbarPlayer: Mixxx.PlayerManager.getPlayer(group)

    Mixxx.ControlProxy {
        id: trackLoadedControl

        group: root.group
        key: "track_loaded"
    }
    Skin.ControlButton {
        id: reverseButton

        activeColor: Theme.deckActiveColor
        group: root.group
        implicitHeight: 22
        implicitWidth: 22
        key: "reverse"

        contentItem: Shape {
            property int multiSamplingLevel: Mixxx.Config.multiSamplingLevel

            anchors.fill: parent
            antialiasing: true
            layer.enabled: multiSamplingLevel > 1
            layer.samples: multiSamplingLevel

            ShapePath {
                fillColor: root.buttonColor
                startX: 5
                startY: 11
                strokeColor: 'transparent'

                PathLine {
                    x: 20
                    y: 4
                }
                PathLine {
                    x: 20
                    y: 18
                }
                PathLine {
                    x: 5
                    y: 11
                }
            }
        }
    }
    Skin.Button {
        id: beatgridButton

        anchors.right: keylockButton.left
        anchors.rightMargin: 5
        enabled: trackLoadedControl.value == 1
        implicitHeight: 22
        text: "Beatgrid"
        visible: root.width > 165

        onPressed: {
            popup.open();
        }
    }
    Popup {
        id: popup

        closePolicy: Popup.CloseOnPressOutside
        focus: true
        height: beatgridLayout.implicitHeight + 20
        padding: 0
        width: 190
        x: beatgridButton.x + beatgridButton.width / 2 - popup.width / 2
        y: -height - 10

        background: Item {
        }
        contentItem: Item {
            objectName: "beatgridPopupContent" + (group ? group.slice(1, -1) : "")

            Item {
                id: contentPopup

                anchors.fill: parent

                layer.effect: MultiEffect {
                    autoPaddingEnabled: true
                    blurMultiplier: 0.24
                    shadowBlur: 0.24
                    shadowColor: "#B0000000"
                    shadowEnabled: true
                }

                Shape {
                    property int multiSamplingLevel: Mixxx.Config.multiSamplingLevel

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    antialiasing: true
                    height: width
                    layer.enabled: multiSamplingLevel > 1
                    layer.samples: multiSamplingLevel
                    width: 20

                    ShapePath {
                        capStyle: ShapePath.RoundCap
                        fillColor: '#2B2B2B'
                        fillRule: ShapePath.WindingFill
                        startX: 10
                        startY: 10
                        strokeColor: Theme.deckBackgroundColor
                        strokeWidth: 0

                        PathLine {
                            x: 20
                            y: 0
                        }
                        PathLine {
                            x: 0
                            y: 0
                        }
                        PathLine {
                            x: 10
                            y: 10
                        }
                    }
                }
                Skin.EmbeddedBackground {
                    anchors.fill: parent
                    anchors.topMargin: 10
                    border.width: 0
                    color: '#2B2B2B'

                    GridLayout {
                        id: beatgridLayout

                        columns: 2
                        width: parent.width - 2 * x
                        x: 7

                        Text {
                            color: '#626262'
                            font.pixelSize: 10
                            font.weight: Font.Normal
                            text: qsTr("SHIFT GRID")
                        }
                        RowLayout {
                            implicitHeight: 24
                            implicitWidth: 100
                            spacing: 0

                            SettingComponents.Slider {
                                id: shiftSlider

                                property var oldValue: 0.5
                                property real pendingShift: 0

                                function firstBeatFrame() {
                                    if (toolbarPlayer === null || !toolbarPlayer.isLoaded) {
                                        return -1;
                                    }
                                    const beatsModel = toolbarPlayer.currentTrack.beatsModel;
                                    if (beatsModel === null || beatsModel.rowCount() <= 0) {
                                        return -1;
                                    }
                                    return beatsModel.get(0).framePosition;
                                }

                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                                decimals: 1
                                enabled: !lockButton.highlight
                                height: 24
                                margins: 1
                                markers: []
                                max: 1
                                min: 0
                                showTextInput: false
                                value: 0.5
                                wheelStep: 0.02

                                onValueChanged: {
                                    if (!popup.opened) {
                                        oldValue = value;
                                        return;
                                    }
                                    pendingShift += (oldValue - value) * 100;
                                    while (Math.abs(pendingShift) >= 1) {
                                        if (pendingShift > 0) {
                                            beatsTranslateEarlierCO.trigger();
                                            pendingShift -= 1;
                                        } else {
                                            beatsTranslateLaterCO.trigger();
                                            pendingShift += 1;
                                        }
                                    }
                                    oldValue = value;
                                }

                                Mixxx.ControlProxy {
                                    id: beatsTranslateEarlierCO

                                    group: root.group
                                    key: "beats_translate_earlier"
                                }
                                Mixxx.ControlProxy {
                                    id: beatsTranslateLaterCO

                                    group: root.group
                                    key: "beats_translate_later"
                                }
                            }
                            Skin.ControlButton {
                                id: curposButton

                                enabled: !lockButton.highlight
                                group: root.group
                                implicitHeight: 24
                                implicitWidth: 24
                                key: "beats_translate_curpos"

                                contentItem: Shape {
                                    property int multiSamplingLevel: Mixxx.Config.multiSamplingLevel

                                    anchors.fill: parent
                                    antialiasing: true
                                    layer.enabled: multiSamplingLevel > 1
                                    layer.samples: multiSamplingLevel

                                    ShapePath {
                                        fillColor: curposButton.enabled ? root.buttonColor : Theme.lightGray
                                        startX: 5
                                        startY: 7
                                        strokeColor: 'transparent'

                                        PathLine {
                                            x: 5
                                            y: 17
                                        }
                                        PathLine {
                                            x: 6
                                            y: 17
                                        }
                                        PathLine {
                                            x: 6
                                            y: 7
                                        }
                                    }
                                    ShapePath {
                                        fillColor: curposButton.enabled ? root.buttonColor : Theme.lightGray
                                        startX: 9
                                        startY: 7
                                        strokeColor: 'transparent'

                                        PathLine {
                                            x: 9
                                            y: 17
                                        }
                                        PathLine {
                                            x: 10
                                            y: 17
                                        }
                                        PathLine {
                                            x: 10
                                            y: 7
                                        }
                                    }
                                    ShapePath {
                                        fillColor: curposButton.enabled ? root.buttonColor : Theme.lightGray
                                        startX: 13
                                        startY: 7
                                        strokeColor: 'transparent'

                                        PathLine {
                                            x: 13
                                            y: 17
                                        }
                                        PathLine {
                                            x: 14
                                            y: 17
                                        }
                                        PathLine {
                                            x: 14
                                            y: 7
                                        }
                                    }
                                    ShapePath {
                                        fillColor: curposButton.enabled ? root.buttonColor : Theme.lightGray
                                        startX: 17
                                        startY: 7
                                        strokeColor: 'transparent'

                                        PathLine {
                                            x: 17
                                            y: 17
                                        }
                                        PathLine {
                                            x: 18
                                            y: 17
                                        }
                                        PathLine {
                                            x: 18
                                            y: 7
                                        }
                                    }
                                    ShapePath {
                                        fillColor: curposButton.enabled ? '#D9D9D9' : Theme.lightGray
                                        startX: 5
                                        startY: 4

                                        PathLine {
                                            x: 12
                                            y: 4
                                        }
                                        PathLine {
                                            x: 9
                                            y: 7
                                        }
                                        PathLine {
                                            x: 9
                                            y: 17
                                        }
                                        PathLine {
                                            x: 8
                                            y: 17
                                        }
                                        PathLine {
                                            x: 8
                                            y: 8
                                        }
                                    }
                                }
                            }
                        }
                        Text {
                            color: '#626262'
                            font.pixelSize: 10
                            font.weight: Font.Normal
                            text: qsTr("BAR SIZE")
                        }
                        SettingComponents.SpinBox {
                            id: barSizeSpinBox

                            Layout.alignment: Qt.AlignRight
                            // TODO unsupported for now
                            enabled: false
                            implicitWidth: 100
                            max: 32
                            min: 2
                            precision: 0
                            realValue: 4
                            value: 4
                        }
                        Text {
                            color: '#626262'
                            font.pixelSize: 10
                            font.weight: Font.Normal
                            text: qsTr("CURRENT BPM")
                        }
                        SettingComponents.SpinBox {
                            id: currentBpmSpinBox

                            Layout.alignment: Qt.AlignRight
                            enabled: !lockButton.highlight
                            implicitWidth: 100
                            max: 1000
                            min: 0
                            precision: 2

                            Component.onCompleted: {
                                value = Qt.binding(() => decimalToInt(toolbarPlayer.currentTrack ? toolbarPlayer.currentTrack.bpm : 0));
                            }
                            onRealValueChanged: {
                                toolbarPlayer.currentTrack.bpm = realValue;
                            }

                            Timer {
                                interval: 1000
                                repeat: true
                                running: currentBpmSpinBox.down.pressed || currentBpmSpinBox.up.pressed

                                onRunningChanged: {
                                    if (running)
                                        return;
                                    currentBpmSpinBox.step = 1 / currentBpmSpinBox.decimalFactor;
                                }
                                onTriggered: {
                                    currentBpmSpinBox.step = Math.min(1, 5 * currentBpmSpinBox.step);
                                }
                            }
                        }
                        RowLayout {
                            Layout.columnSpan: 2
                            Layout.fillHeight: true

                            Skin.ControlButton {
                                id: halfButton

                                Layout.fillWidth: true
                                activeColor: Theme.deckActiveColor
                                group: root.group
                                implicitHeight: 22
                                key: "beats_set_halve"
                                text: "half"
                            }
                            Skin.ControlButton {
                                id: doubleButton

                                Layout.fillWidth: true
                                activeColor: Theme.deckActiveColor
                                group: root.group
                                implicitHeight: 22
                                key: "beats_set_double"
                                text: "double"
                            }
                            Skin.ControlButton {
                                id: lockButton

                                Layout.fillWidth: true
                                activeColor: Theme.deckActiveColor
                                group: root.group
                                implicitHeight: 22
                                key: "bpmlock"
                                text: "lock"
                                toggleable: true
                            }
                        }
                    }
                }
            }
        }

        onClosed: {
            shiftSlider.setValue(0.5);
            // currentBpmSpinBox.realValue = toolbarPlayer?.currentTrack.bpm
        }
    }
    Skin.ControlButton {
        id: quantizeButton

        activeColor: Theme.deckActiveColor
        anchors.right: ejectButton.left
        anchors.rightMargin: 5
        implicitHeight: 22
        implicitWidth: 22
        key: "quantize"
        toggleable: true

        contentItem: Item {
            anchors.fill: parent

            Shape {
                property int multiSamplingLevel: Mixxx.Config.multiSamplingLevel

                antialiasing: true
                height: 17
                layer.enabled: multiSamplingLevel > 1
                layer.samples: multiSamplingLevel
                width: 15

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    topMargin: 2
                }

                // Body
                ShapePath {
                    fillColor: root.buttonColor
                    startX: 2
                    startY: 10
                    strokeColor: "transparent"

                    PathLine {
                        x: 13.5
                        y: 10
                    }
                    PathLine {
                        x: 13.5
                        y: 16
                    }
                    PathLine {
                        x: 2
                        y: 16
                    }
                    PathLine {
                        x: 2
                        y: 10
                    }
                }

                // Shackle
                ShapePath {
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    joinStyle: ShapePath.RoundJoin
                    startX: 4
                    startY: quantizeButton.highlight ? 11 : 7
                    strokeColor: root.buttonColor
                    strokeWidth: 2

                    PathLine {
                        x: 4
                        y: 5
                    }
                    PathCubic {
                        control1X: 4
                        control1Y: 1.5
                        control2X: 11
                        control2Y: 1.5
                        x: 12
                        y: 5
                    }
                    PathLine {
                        x: 12
                        y: 11
                    }
                }
            }
        }
    }
    Skin.ControlButton {
        id: ejectButton

        activeColor: Theme.deckActiveColor
        anchors.right: parent.right
        group: root.group
        implicitHeight: 22
        implicitWidth: 22
        key: "eject"

        contentItem: Item {
            anchors.fill: parent

            Shape {
                property int multiSamplingLevel: Mixxx.Config.multiSamplingLevel

                antialiasing: true
                height: 10
                layer.enabled: multiSamplingLevel > 1
                layer.samples: multiSamplingLevel
                width: 15

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    topMargin: 5
                }
                ShapePath {
                    fillColor: root.buttonColor
                    startX: 7.5
                    startY: 0
                    strokeColor: 'transparent'

                    PathLine {
                        x: 15
                        y: 10
                    }
                    PathLine {
                        x: 0
                        y: 10
                    }
                    PathLine {
                        x: 7.5
                        y: 0
                    }
                }
            }
            Rectangle {
                color: root.buttonColor
                height: 2
                width: 15

                anchors {
                    bottom: parent.bottom
                    bottomMargin: 3
                    horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
