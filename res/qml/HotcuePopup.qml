import Mixxx 1.0 as Mixxx
import Mixxx 1.0 as MixxxWidgets
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts
import "Theme"

Popup {
    id: root

    readonly property real cuePosition: hotcue.position
    readonly property list<var> cueTypes: [
        {
            "type": hotcue.typeHotCue,
            "name": "CUE"
        },
        {
            "type": hotcue.typeLoop,
            "name": "LOOP"
        },
        {
            "type": hotcue.typeJump,
            "name": "JUMP"
        }
    ]
    readonly property var currentCue: {
        if (!currentTrack)
            return null;
        // Referenced to trigger re-evaluation on cue data changes
        currentTrack.hotcuesModel.revision;
        return currentTrack.hotcuesModel.getByHotcueNumber(hotcue.hotcueNumber);
    }
    required property var currentTrack
    required property Hotcue hotcue
    readonly property real sampleRate: currentTrack ? currentTrack.sampleRate : 0
    readonly property real trackSamples: trackSamplesControl.value
    readonly property int typeIndex: {
        for (var i = 0; i < cueTypes.length; i++) {
            if (cueTypes[i].type === hotcue.type)
                return i;
        }
        return 0;
    }
    readonly property real windowSamples: windowSeconds * sampleRate
    readonly property real windowSeconds: 8

    function convertTo(type) {
        if (!currentTrack || type === hotcue.type)
            return;
        currentTrack.hotcuesModel.convertTypeByHotcueNumber(hotcue.hotcueNumber, type, hotcue.group);
    }
    function openFrom(button) {
        if (!hotcue.isSet)
            return;
        parent = button.Overlay.overlay;
        const buttonTopLeft = button.mapToItem(null, 0, 0);
        const windowWidth = button.Window.window ? button.Window.window.width : 0;
        x = Math.max(6, Math.min(buttonTopLeft.x + button.width / 2 - implicitWidth / 2, windowWidth - implicitWidth - 6));
        y = buttonTopLeft.y - implicitHeight - 10;
        labelField.text = root.currentCue?.label ?? "";
        labelField.pendingLabel = "";
        open();
    }

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    contentHeight: contentLayout.implicitHeight
    contentWidth: contentLayout.implicitWidth
    dim: false
    focus: true
    modal: true
    padding: 4

    background: Rectangle {
        color: Theme.hotcuePopupBackgroundColor
        radius: 6
    }
    contentItem: ColumnLayout {
        id: contentLayout

        spacing: 4

        MixxxWidgets.WaveformDisplay {
            id: waveformPreview

            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Layout.preferredWidth: 400
            backgroundColor: Theme.hotcuePopupBackgroundColor
            clip: true
            position: {
                if (root.trackSamples <= 0 || root.cuePosition < 0)
                    return 0;

                return root.cuePosition / root.trackSamples;
            }
            track: root.currentTrack
            zoom: waveformPreview.width > 0 && root.sampleRate > 0 ? root.windowSamples / waveformPreview.width : 882

            data: [
                Rectangle {
                    id: cueMarker

                    anchors.bottom: parent.bottom
                    anchors.top: parent.top
                    color: Theme.hotcuePopupCueMarkerColor
                    visible: root.hotcue.isSet
                    width: 2
                    x: parent.width / 2 - width / 2
                },
                Canvas {
                    id: cueMarkerNotch

                    anchors.margins: 0
                    anchors.top: parent.top
                    height: 8
                    visible: cueMarker.visible
                    width: 12
                    x: cueMarker.x + cueMarker.width / 2 - width / 2

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = Theme.hotcuePopupCueMarkerColor;
                        ctx.beginPath();
                        ctx.moveTo(0, 0);
                        ctx.lineTo(width, 0);
                        ctx.lineTo(width / 2, height);
                        ctx.closePath();
                        ctx.fill();
                    }
                    onWidthChanged: requestPaint()
                },
                Canvas {
                    id: gridOverlay

                    anchors.fill: parent

                    Component.onCompleted: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = Theme.hotcuePopupGridColor;
                        ctx.globalAlpha = 0.15;
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        for (let i = 1; i * 24 < width; i++) {
                            ctx.moveTo(i * 24 + 0.5, 0);
                            ctx.lineTo(i * 24 + 0.5, height);
                        }
                        ctx.stroke();
                    }
                    onWidthChanged: requestPaint()
                }
            ]
            renderers: [
                MixxxWidgets.WaveformRendererFiltered {
                    axesColor: "transparent"
                    gainAll: 1.0
                    gainHigh: 1.0
                    gainLow: 1.0
                    gainMid: 1.0
                    highColor: "#D5C2A2"
                    lowColor: "#2154D7"
                    midColor: "#97632D"
                }
            ]
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Grid {
                id: colorGrid

                columns: 9
                spacing: 2

                Repeater {
                    model: Mixxx.Config.hotcueColorPalette

                    Rectangle {
                        id: swatch

                        readonly property bool checked: {
                            const currentColor = root.hotcue.color;
                            if (!currentColor)
                                return false;

                            return Qt.color(currentColor).toString() === Qt.color(swatch.modelData).toString();
                        }
                        required property color modelData

                        border.color: Theme.hotcuePopupTextColor
                        border.width: checked ? 2 : 0
                        color: swatch.modelData
                        height: 24
                        width: 24

                        MouseArea {
                            anchors.fill: parent

                            onClicked: {
                                root.hotcue.setColor(swatch.modelData);
                                root.close();
                            }
                        }
                    }
                }
            }
            Item {
                id: typeSelector

                Layout.alignment: Qt.AlignRight
                implicitHeight: 42
                implicitWidth: typeArrowLeft.width + typeLabel.width + typeArrowRight.width

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    TypeCycleButton {
                        id: typeArrowLeft

                        glyph: "\u25C0"

                        onTypeCycled: {
                            const newIndex = (root.typeIndex + root.cueTypes.length - 1) % root.cueTypes.length;
                            root.convertTo(root.cueTypes[newIndex].type);
                        }
                    }
                    Label {
                        id: typeLabel

                        Layout.preferredHeight: 42
                        Layout.preferredWidth: 64
                        color: Theme.hotcuePopupTextColor
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        text: root.cueTypes[root.typeIndex].name
                        verticalAlignment: Text.AlignVCenter
                    }
                    TypeCycleButton {
                        id: typeArrowRight

                        glyph: "\u25B6"

                        onTypeCycled: {
                            const newIndex = (root.typeIndex + 1) % root.cueTypes.length;
                            root.convertTo(root.cueTypes[newIndex].type);
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            TextField {
                id: labelField

                property string pendingLabel: ""

                function commit() {
                    if (pendingLabel === "") {
                        return;
                    }
                    if (root.currentTrack) {
                        root.currentTrack.hotcuesModel.setLabelByHotcueNumber(root.hotcue.hotcueNumber, pendingLabel);
                    }
                    pendingLabel = "";
                }
                function reset() {
                    text = "";
                    pendingLabel = "";
                }

                Layout.fillWidth: true

                // Shows the current label until the user starts editing;
                // then the placeholder asks for confirmation and
                // Enter (or clicking away inside the popup) commits
                color: "#111111"
                placeholderText: pendingLabel !== "" ? qsTr("Click to confirm") : (root.currentCue?.label ?? qsTr("Label..."))
                selectedTextColor: "#000000"
                selectionColor: Theme.hotcuePopupInputSelectionBackgroundColor
                text: ""

                background: Rectangle {
                    anchors.fill: parent
                    border.color: Theme.hotcuePopupInputBorderColorLeft
                    border.width: 1
                    color: Theme.hotcuePopupInputBackgroundColor
                    radius: 0
                }

                onAccepted: function () {
                    commit();
                }
                onActiveFocusChanged: {
                    if (!activeFocus && pendingLabel !== "") {
                        commit();
                    }
                }
                onTextEdited: {
                    labelField.pendingLabel = labelField.text;
                }
            }
            AbstractButton {
                id: deleteButton

                Layout.preferredHeight: 24
                Layout.preferredWidth: 24

                background: Rectangle {
                    color: deleteButton.pressed ? Theme.hotcuePopupDeletePressedColor : deleteButton.hovered ? Theme.hotcuePopupDeleteHoverColor : "transparent"
                    radius: 4
                }
                contentItem: Canvas {
                    id: deleteIcon

                    anchors.fill: parent
                    anchors.margins: 3

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = "#dc4141";
                        ctx.fillStyle = "#dc4141";
                        ctx.lineWidth = 2;
                        const w = width;
                        const h = height;
                        // lid
                        ctx.beginPath();
                        ctx.moveTo(0, 3);
                        ctx.lineTo(w, 3);
                        ctx.stroke();
                        // handle
                        ctx.beginPath();
                        ctx.moveTo(w / 2 - 3, 3);
                        ctx.lineTo(w / 2 - 3, 0);
                        ctx.lineTo(w / 2 + 3, 0);
                        ctx.lineTo(w / 2 + 3, 3);
                        ctx.stroke();
                        // body
                        ctx.beginPath();
                        ctx.moveTo(2, 5);
                        ctx.lineTo(2, h);
                        ctx.lineTo(w - 2, h);
                        ctx.lineTo(w - 2, 5);
                        ctx.closePath();
                        ctx.stroke();
                        // grooves
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        ctx.moveTo(w * 0.35, 7);
                        ctx.lineTo(w * 0.35, h - 2);
                        ctx.moveTo(w * 0.5, 7);
                        ctx.lineTo(w * 0.5, h - 2);
                        ctx.moveTo(w * 0.65, 7);
                        ctx.lineTo(w * 0.65, h - 2);
                        ctx.stroke();
                    }

                    Connections {
                        function onHoveredChanged() {
                            deleteIcon.requestPaint();
                        }

                        target: deleteButton
                    }
                }

                onPressed: root.hotcue.clear = 1
                onReleased: root.hotcue.clear = 0
            }
        }
    }
    enter: Transition {
        NumberAnimation {
            duration: 100
            from: 0
            properties: "opacity"
            to: 1
        }
    }
    exit: Transition {
        NumberAnimation {
            duration: 100
            from: 1
            properties: "opacity"
            to: 0
        }
    }

    Mixxx.ControlProxy {
        id: trackSamplesControl

        group: root.hotcue.group
        key: "track_samples"
    }

    component TypeCycleButton: Rectangle {
        id: typeCycleToggleButton

        property string glyph

        signal typeCycled

        color: typeCycleMouseButton.pressed ? Theme.hotcuePopupTypePressedColor : "transparent"
        implicitHeight: 42
        implicitWidth: 24

        Label {
            anchors.centerIn: parent
            color: Theme.hotcuePopupTextColor
            font.pixelSize: 14
            text: typeCycleToggleButton.glyph
        }
        MouseArea {
            id: typeCycleMouseButton

            anchors.fill: parent

            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton)
                    typeCycleToggleButton.typeCycled();
            }
        }
    }
}
