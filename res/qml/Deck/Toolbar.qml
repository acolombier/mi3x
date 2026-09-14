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
        implicitHeight: 22
        text: "Beatgrid"
        visible: root.width > 165
        onPressed: {
            popup.open()
        }
    }
    Popup {
        id: popup

        closePolicy: Popup.CloseOnPressOutside
        padding: 0
        width: 190
        height: 24*3+40
        x: beatgridButton.x + beatgridButton.width / 2 - popup.width / 2
        y: -height-10

        background: Item {
        }
        contentItem: Item {
            Item {
                id: contentPopup

                anchors.fill: parent

                layer.effect: MultiEffect {
                    autoPaddingEnabled: true
                    shadowEnabled: true
                    shadowColor: "#B0000000"
                    shadowBlur: 0.24
                    blurMultiplier: 0.24
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
                    color: '#2B2B2B'
                    border.width: 0

                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: 7
                        columns: 2
                        Text {
                            color: '#626262'
                            font.pixelSize: 10
                            font.weight: Font.Normal
                            text: qsTr("SHIFT GRID")
                        }
                        RowLayout {
                            implicitWidth: 100
                            implicitHeight: 24
                            spacing: 0

                            SettingComponents.Slider {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                                height: 24
                                decimals: 1
                                markers: []
                                max: 1
                                min: 0
                                value: 0.5
                                wheelStep: 0.02
                                showTextInput: false
                                margins: 1

                                property var oldValue: -1

                                onValueChanged: {
                                    if (oldValue >= 0) {
                                        if (oldValue > value) {
                                            beatsTranslateEarlierCO.trigger()
                                        } else {
                                            beatsTranslateLaterCO.trigger()
                                        }
                                    }
                                    oldValue = value
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
                                        fillColor: root.buttonColor
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
                                        fillColor: root.buttonColor
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
                                        fillColor: root.buttonColor
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
                                        fillColor: root.buttonColor
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
                                        fillColor: '#D9D9D9'
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
                            Layout.alignment: Qt.AlignRight
                            max: 32
                            min: 2
                            precision: 0
                            realValue: 4
                            implicitWidth: 100
                        }
                        Text {
                            color: '#626262'
                            font.pixelSize: 10
                            font.weight: Font.Normal
                            text: qsTr("CURRENT BPM")
                        }
                        SettingComponents.SpinBox {
                            Layout.alignment: Qt.AlignRight
                            max: 1000
                            min: 0
                            precision: 2
                            realValue: 126
                            implicitWidth: 100
                        }
                    }
                }
            }
        }
    }
    Skin.Button {
        id: keylockButton

        anchors.right: ejectButton.left
        anchors.rightMargin: 5
        implicitHeight: 22
        text: "Keylock"
        visible: root.width > 165
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
