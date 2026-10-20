import ".." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick 2
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls 2.12
import "../Theme"

Rectangle {
    id: root

    property color buttonColor: trackLoadedControl.value > 0 ? Theme.buttonActiveColor : Theme.buttonDisableColor
    required property string group

    color: Theme.deckLoopBackgroundColor

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        color: Theme.deckLoopLabelColor
        text: "Loop"
    }
    Mixxx.ControlProxy {
        id: trackLoadedControl

        group: root.group
        key: "track_loaded"
    }
    Mixxx.ControlProxy {
        id: loopEnabled

        group: root.group
        key: "loop_enabled"
    }
    Mixxx.ControlProxy {
        id: beatloopSize

        group: root.group
        key: "beatloop_size"
    }
    Mixxx.ControlProxy {
        id: beatloopActivate

        group: root.group
        key: "beatloop_activate"
    }
    Mixxx.ControlProxy {
        id: loopHalve

        group: root.group
        key: "loop_halve"
    }
    Mixxx.ControlProxy {
        id: loopDouble

        group: root.group
        key: "loop_double"
    }
    RowLayout {
        anchors {
            left: parent.left
            leftMargin: 6
            right: parent.right
            rightMargin: 6
            top: parent.top
            topMargin: 22
        }
        LoopPointButton {
            buttonColor: root.buttonColor
            buttonName: "loopIn"
            group: root.group
            isEndAnchor: false
            key: "loop_in"
            label: "In"
        }
        LoopPointButton {
            buttonColor: root.buttonColor
            buttonName: "loopOut"
            group: root.group
            isEndAnchor: true
            key: "loop_out"
            label: "Out"
        }
        Skin.ControlButton {
            id: loopRecallButton

            Layout.fillWidth: true
            Layout.minimumWidth: 40
            activeColor: root.buttonColor
            group: root.group
            implicitHeight: 26
            key: loopEnabled.value ? "loop_enabled" : "reloop_toggle"
            normalColor: root.buttonColor
            objectName: "reloopToggle"
            text: loopEnabled.value ? "exit" : "Recall"
            toggleable: loopEnabled.value
        }
    }
    RowLayout {
        spacing: 0

        anchors {
            bottom: parent.bottom
            bottomMargin: 6
            left: parent.left
            leftMargin: 6
            right: parent.right
            rightMargin: 6
        }
        Skin.Button {
            id: loopSizeHalfButton

            activeColor: root.buttonColor
            implicitHeight: 28
            implicitWidth: 22
            objectName: "loopHalve"

            contentItem: Item {
                anchors.fill: parent

                Shape {
                    property int multiSamplingLevel: Mixxx.Config.multiSamplingLevel

                    anchors.centerIn: parent
                    antialiasing: true
                    height: 10
                    layer.enabled: multiSamplingLevel > 1
                    layer.samples: multiSamplingLevel
                    width: 12

                    ShapePath {
                        fillColor: root.buttonColor
                        startX: 0
                        startY: 5
                        strokeColor: 'transparent'

                        PathLine {
                            x: 12
                            y: 0
                        }
                        PathLine {
                            x: 12
                            y: 10
                        }
                        PathLine {
                            x: 0
                            y: 5
                        }
                    }
                }
            }

            MouseArea {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                anchors.fill: parent

                onPressed: mouse => {
                    if (loopEnabled.value ^ mouse.button == Qt.RightButton) {
                        loopHalve.trigger();
                    }
                }
                onReleased: mouse => {
                    if (loopEnabled.value ^ mouse.button == Qt.RightButton) {
                        return;
                    }
                    scroll.adjustSelectedIndex(-1);
                }
            }
            DragHandler {
                target: null

                onActiveChanged: {
                    let scrollStartingAt = scroll.contentX;
                    scroll.contentX = Qt.binding(() => Math.min(scroll.contentWidth - scroll.width, Math.max(0, scrollStartingAt - translation.x)));
                }
            }
        }
        Item {
            id: scrollShell

            Layout.fillWidth: true
            implicitHeight: 28

            Flickable {
                id: scroll

                readonly property real buttonWidth: 33
                readonly property real itemStep: buttonWidth + sizeRow.spacing
                property int selectedIndex: scroll.values.indexOf(beatloopSize.value)
                property list<double> values: {
                    let values = [1 / 32];
                    while (values[values.length - 1] < 512) {
                        values.push(values[values.length - 1] * 2);
                    }
                    return values;
                }

                function adjustSelectedIndex(delta) {
                    scroll.selectedIndex = Math.min(Math.max(0, scroll.selectedIndex + delta), loopSizeRepeater.count - 1);
                }

                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                contentWidth: sizeRow.implicitWidth
                contentX: {
                    let focusedItem = loopSizeRepeater.itemAt(scroll.selectedIndex);
                    return Math.min(contentWidth - width, Math.max(0, focusedItem.x + focusedItem.width / 2 - width / 2));
                }
                flickableDirection: Flickable.HorizontalFlick

                Behavior on contentX {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.OutCubic
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                    onWheel: event => {
                        if (event.angleDelta.y < 0) {
                            scroll.adjustSelectedIndex(-1);
                        } else if (event.angleDelta.y > 0) {
                            scroll.adjustSelectedIndex(1);
                        }
                    }
                }
                Row {
                    id: sizeRow

                    spacing: 6

                    Repeater {
                        id: loopSizeRepeater

                        property list<double> values: {
                            let values = [1 / 32];
                            while (values[values.length - 1] < 512) {
                                values.push(values[values.length - 1] * 2);
                            }
                            return values;
                        }

                        model: values

                        delegate: Skin.Button {
                            property double currentSize: modelData
                            required property int index
                            required property var modelData

                            activeColor: root.buttonColor
                            highlight: currentSize == beatloopSize.value && trackLoadedControl.value > 0
                            implicitHeight: 28
                            implicitWidth: 33
                            text: currentSize < 1 ? `1/${1 / currentSize}` : currentSize

                            background: Rectangle {
                                id: backgroundImage

                                anchors.fill: parent
                                color: loopEnabled.value && parent.highlight ? '#2D4EA1' : Qt.alpha('#2B2B2B', currentSize == beatloopSize.value ? 1 : 0.7)
                                radius: 2

                                border {
                                    color: '#1C1C1C'
                                    width: 1
                                }
                            }

                            onPressed: {
                                if (loopEnabled.value) {
                                    beatloopSize.value = currentSize;
                                } else {
                                    sizedBeatloopActivate.trigger();
                                }
                            }

                            Mixxx.ControlProxy {
                                id: sizedBeatloopActivate

                                group: root.group
                                key: `beatloop_${currentSize}_activate`
                            }
                            Mixxx.ControlProxy {
                                id: sizedBeatlooprollActivate

                                group: root.group
                                key: `beatlooproll_${currentSize}_activate`
                                value: rightClick.pressed
                            }
                            MouseArea {
                                id: rightClick

                                acceptedButtons: Qt.RightButton
                                anchors.fill: parent

                                onPressed: {}
                            }
                        }
                    }
                }
            }
            Rectangle {
                id: fadeLeft

                visible: scroll.contentWidth > scroll.width && scroll.contentX > 1
                width: 12

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        color: root.color
                        position: 0
                    }
                    GradientStop {
                        color: 'transparent'
                        position: 1
                    }
                }

                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    top: parent.top
                }
            }
            Rectangle {
                id: fadeRight

                visible: scroll.contentWidth > scroll.width && scroll.contentX < scroll.contentWidth - scroll.width - 1
                width: 12

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        color: root.color
                        position: 1
                    }
                    GradientStop {
                        color: 'transparent'
                        position: 0
                    }
                }

                anchors {
                    bottom: parent.bottom
                    right: parent.right
                    top: parent.top
                }
            }
        }
        Skin.Button {
            id: loopSizeDoubleButton

            activeColor: root.buttonColor
            implicitHeight: 28
            implicitWidth: 22
            objectName: "loopDouble"

            contentItem: Item {
                anchors.fill: parent

                Shape {
                    property int multiSamplingLevel: Mixxx.Config.multiSamplingLevel

                    anchors.centerIn: parent
                    antialiasing: true
                    height: 10
                    layer.enabled: multiSamplingLevel > 1
                    layer.samples: multiSamplingLevel
                    width: 12

                    ShapePath {
                        capStyle: ShapePath.RoundCap
                        fillColor: root.buttonColor
                        fillRule: ShapePath.WindingFill
                        startX: 0
                        startY: 0
                        strokeColor: 'transparent'

                        PathLine {
                            x: 12
                            y: 5
                        }
                        PathLine {
                            x: 0
                            y: 10
                        }
                        PathLine {
                            x: 0
                            y: 0
                        }
                    }
                }
            }

            MouseArea {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                anchors.fill: parent

                onPressed: mouse => {
                    if (loopEnabled.value ^ mouse.button == Qt.RightButton) {
                        loopDouble.trigger();
                        scroll.selectedIndex = scroll.values.indexOf(beatloopSize.value);
                    }
                }
                onReleased: mouse => {
                    if (loopEnabled.value ^ mouse.button == Qt.RightButton) {
                        return;
                    }
                    scroll.adjustSelectedIndex(1);
                }
            }
            DragHandler {
                target: null

                onActiveChanged: {
                    let scrollStartingAt = scroll.contentX;
                    scroll.contentX = Qt.binding(() => Math.min(scroll.contentWidth - scroll.width, Math.max(0, scrollStartingAt - translation.x)));
                }
            }
        }
    }

    component LoopPointButton: Item {
        id: loopPointButton

        readonly property bool anchored: anchorControl.value == (isEndAnchor ? 1 : 0)
        required property color buttonColor
        required property string buttonName
        required property string group
        required property bool isEndAnchor
        required property string key
        required property string label

        function toggleAnchor() {
            anchorControl.value = anchorControl.value == 0 ? 1 : 0;
        }

        Layout.fillWidth: true
        Layout.minimumWidth: 28
        implicitHeight: 26

        Mixxx.ControlProxy {
            id: anchorControl

            group: loopPointButton.group
            key: "loop_anchor"
        }
        Skin.ControlButton {
            id: controlButton

            activeColor: loopPointButton.buttonColor
            anchors.fill: parent
            group: loopPointButton.group
            key: loopPointButton.key
            normalColor: loopPointButton.buttonColor
            objectName: loopPointButton.buttonName
            text: loopPointButton.label

            onPressAndHold: toggleAnchor()
        }
        MouseArea {
            acceptedButtons: Qt.RightButton
            anchors.fill: parent

            onPressed: toggleAnchor()
        }
        Rectangle {
            id: anchorUnderline

            color: loopPointButton.buttonColor
            height: 2
            opacity: loopPointButton.anchored ? 1 : 0
            width: parent.width - 8

            Behavior on opacity {
                NumberAnimation {
                    duration: 100
                }
            }

            anchors {
                bottom: parent.bottom
                bottomMargin: 2
                horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
