import ".." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls 2.12
import "../Theme"

Item {
    id: root

    required property var currentTrack
    required property string group

    Mixxx.ControlProxy {
        id: stemCountControl

        group: root.group
        key: "stem_count"
    }
    Mixxx.ControlProxy {
        id: trackLoadedControl

        group: root.group
        key: "track_loaded"
    }
    Rectangle {
        color: '#0E0E0E'

        states: [
            State {
                name: "inactive"
                when: trackLoadedControl.value == 0

                PropertyChanges {
                    checked: false
                    opacity: 0.75
                    target: hotcueTabButton
                }
                PropertyChanges {
                    checked: false
                    opacity: 0.75
                    target: stemTabButton
                }
                PropertyChanges {
                    target: stemTab
                    visible: false
                }
                PropertyChanges {
                    target: hotcueTab
                    visible: false
                }
            },
            State {
                name: "hotcue"
                when: hotcueTabButton.checked || stemCountControl.value == 0

                PropertyChanges {
                    target: hotcueTab
                    visible: true
                }
                PropertyChanges {
                    target: stemTab
                    visible: false
                }
            },
            State {
                name: "stem"
                when: stemTabButton.checked && stemCountControl.value != 0

                PropertyChanges {
                    target: stemTab
                    visible: true
                }
                PropertyChanges {
                    target: hotcueTab
                    visible: false
                }
            }
        ]

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: stemCountControl.value > 0 ? tabs.left : parent.right
            rightMargin: stemCountControl.value > 0 ? 6 : 0
            top: parent.top
        }
        Item {
            id: hotcueTab

            anchors.fill: parent
            visible: false

            Skin.FadeBehavior on visible {
                fadeTarget: hotcueTab
            }

            GridLayout {
                anchors.bottomMargin: 8
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 8
                columnSpacing: 6
                rowSpacing: 6

                Repeater {
                    model: 8

                    Item {
                        required property int index

                        Layout.column: index % 4
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.row: parseInt(index / 4)
                        objectName: "hotcue_" + (index + 1)

                        Skin.Hotcue {
                            id: hotcue

                            readonly property var label: isSet ? root.currentTrack.hotcuesModel.get(index).label : null

                            activate: activator.pressedButtons == Qt.LeftButton
                            // onIsSetChanged: {
                            //     if (!isSet)
                            //         popup.close();
                            // }
                            group: root.group
                            hotcueNumber: index + 1
                        }
                        Rectangle {
                            id: backgroundImage

                            anchors.fill: parent
                            color: hotcue.isSet ? hotcue.color : '#2B2B2B'
                            radius: 1

                            border {
                                color: '#1C1C1C'
                                width: 1
                            }
                            MouseArea {
                                id: activator

                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                anchors.fill: parent
                            }
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
                                text: hotcue.label ?? ""
                                visible: hotcue.label
                            }
                        }
                    }
                }
            }
        }
        Item {
            id: stemTab

            anchors.fill: parent
            visible: false

            Skin.FadeBehavior on visible {
                fadeTarget: stemTab
            }

            GridLayout {
                anchors.bottomMargin: 6
                anchors.fill: parent
                anchors.leftMargin: 9
                anchors.rightMargin: 9
                anchors.topMargin: 6
                columnSpacing: 9
                columns: width < 250 ? 1 : root.currentTrack.stemsModel.rowCount()

                Repeater {
                    model: root.currentTrack.stemsModel

                    Skin.Stem {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        compact: parent.columns == 1
                        group: `${root.group.substr(0, root.group.length - 1)}_Stem${index + 1}]`
                    }
                }
            }
        }
    }
    ColumnLayout {
        id: tabs

        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.top: parent.top
        spacing: 10
        width: stemCountControl.value > 0 ? 36 : 0

        Behavior on width {
            SpringAnimation {
                damping: 0.2
                duration: 500
                spring: 2
            }
        }

        Skin.Button {
            id: hotcueTabButton

            Layout.fillWidth: true
            Layout.margins: 0
            activeColor: Theme.deckActiveColor
            checked: true
            implicitHeight: 30

            contentItem: Shape {
                property int multiSamplingLevel: Mixxx.Config.multiSamplingLevel

                anchors.fill: parent
                antialiasing: true
                layer.enabled: multiSamplingLevel > 1
                layer.samples: multiSamplingLevel

                ShapePath {
                    fillColor: '#D9D9D9'
                    startX: 10
                    startY: 4

                    PathLine {
                        x: 26
                        y: 4
                    }
                    PathLine {
                        x: 19.5
                        y: 10
                    }
                    PathLine {
                        x: 19.5
                        y: 24
                    }
                    PathLine {
                        x: 16.5
                        y: 24
                    }
                    PathLine {
                        x: 16.5
                        y: 10
                    }
                    PathLine {
                        x: 10
                        y: 4
                    }
                }
            }

            onClicked: {
                stemTabButton.checked = false;
                hotcueTabButton.checked = trackLoadedControl.value == 1;
            }
        }
        Skin.Button {
            id: stemTabButton

            Layout.fillWidth: true
            Layout.margins: 0
            activeColor: Theme.deckActiveColor
            implicitHeight: 30

            contentItem: Item {
                Rectangle {
                    color: '#D9D9D9'
                    height: 1

                    anchors {
                        left: parent.left
                        leftMargin: 5
                        right: parent.right
                        rightMargin: 5
                        top: parent.top
                        topMargin: 6
                    }
                }
                Rectangle {
                    color: '#D9D9D9'
                    height: 1

                    anchors {
                        left: parent.left
                        leftMargin: 5
                        right: parent.right
                        rightMargin: 14
                        top: parent.top
                        topMargin: 12
                    }
                }
                Rectangle {
                    color: '#D9D9D9'
                    height: 1

                    anchors {
                        bottom: parent.bottom
                        bottomMargin: 12
                        left: parent.left
                        leftMargin: 5
                        right: parent.right
                        rightMargin: 22
                    }
                }
                Rectangle {
                    color: '#D9D9D9'
                    height: 1

                    anchors {
                        bottom: parent.bottom
                        bottomMargin: 13
                        left: parent.left
                        leftMargin: 22
                        right: parent.right
                        rightMargin: 5
                    }
                }
                Rectangle {
                    color: '#D9D9D9'
                    height: 1

                    anchors {
                        bottom: parent.bottom
                        bottomMargin: 6
                        left: parent.left
                        leftMargin: 5
                        right: parent.right
                        rightMargin: 26
                    }
                }
                Rectangle {
                    color: '#D9D9D9'
                    height: 1

                    anchors {
                        bottom: parent.bottom
                        bottomMargin: 6
                        left: parent.left
                        leftMargin: 14
                        right: parent.right
                        rightMargin: 15
                    }
                }
                Rectangle {
                    color: '#D9D9D9'
                    height: 1

                    anchors {
                        bottom: parent.bottom
                        bottomMargin: 6
                        left: parent.left
                        leftMargin: 26
                        right: parent.right
                        rightMargin: 5
                    }
                }
            }

            onClicked: {
                stemTabButton.checked = trackLoadedControl.value == 1 && stemCountControl.value != 0;
                hotcueTabButton.checked = !stemTabButton.checked;
            }
        }
    }
}
