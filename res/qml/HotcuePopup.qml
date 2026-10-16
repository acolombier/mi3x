import "." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Shapes
import "Theme"

Popup {
    id: root

    readonly property real cueEndPosition: hotcue.endPosition
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
        return currentTrack.hotcuesModel.getByHotcueNumber(hotcue.hotcueNumber - 1);
    }
    required property var currentTrack
    readonly property bool forwardSpan: cueEndPosition >= cuePosition
    readonly property bool hasSpan: isLoopOrJump && trackSamples > 0 && cuePosition >= 0 && cueEndPosition >= 0 && spanSamples > 0
    required property Hotcue hotcue
    readonly property bool isLoopOrJump: hotcue.type === hotcue.typeLoop || hotcue.type === hotcue.typeJump
    readonly property real sampleRate: currentTrack ? currentTrack.sampleRate : 0
    readonly property real spanCenterPosition: hasSpan ? (spanStart + spanEnd) / 2 : cuePosition
    readonly property real spanEnd: Math.max(cuePosition, cueEndPosition)
    readonly property real spanSamples: spanEnd - spanStart
    readonly property real spanStart: Math.min(cuePosition, cueEndPosition)
    readonly property real trackSamples: trackSamplesControl.value
    readonly property int typeIndex: {
        for (var i = 0; i < cueTypes.length; i++) {
            if (cueTypes[i].type === hotcue.type)
                return i;
        }
        return 0;
    }

    /// Unique id of the popup instance in the scene object tree, used to
    /// disambiguate objectNames for UI tests
    readonly property string uid: hotcue.group + "-" + hotcue.hotcueNumber

    function convertTo(type) {
        console.log("HOTCUEPOPUP convertTo requested", type);
        if (!currentTrack || type === hotcue.type)
            return;
        currentTrack.hotcuesModel.convertTypeByHotcueNumber(hotcue.hotcueNumber - 1, type, hotcue.group);
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
    contentHeight: contentLayout.implicitHeight + 10
    contentWidth: colorAndTypeRow.implicitWidth
    dim: false
    focus: true
    modal: true
    objectName: "hotcuePopup" + root.uid
    padding: 0

    background: Item {
    }
    contentItem: Item {
        id: contentPopup

        // Frames per visual sample of the loaded track's main waveform.
        // Used to convert between cue positions (engine samples) and
        // waveform pixels together with the waveform's zoom value.
        readonly property real audioVisualRatio: waveformPreviewFull.audioVisualRatio

        objectName: "hotcuePopupContent" + root.uid

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
            id: mask

            anchors.fill: parent
            color: '#2B2B2B'
            layer.enabled: true // Required for complex shapes
            layer.smooth: true  // Ensures smooth edges
            radius: 8
            visible: false
        }
        MultiEffect {
            anchors.bottomMargin: 10
            anchors.fill: parent
            autoPaddingEnabled: true
            blurMultiplier: 0.24
            shadowBlur: 0.84
            shadowColor: '#000000'
            shadowEnabled: true
            source: mask
        }
        Item {
            id: contentRect

            anchors.bottomMargin: 10
            anchors.fill: parent
            layer.enabled: true

            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    height: contentRect.height
                    radius: 8
                    visible: false // Mask itself is not drawn
                    width: contentRect.width
                }
            }

            ColumnLayout {
                id: contentLayout

                anchors.fill: parent
                spacing: 0

                Mixxx.ControlProxy {
                    id: zoomControl

                    group: hotcue.group
                    key: "waveform_zoom"
                }
                Item {
                    id: waveformPreview

                    // Span width targeted in the un-split view: 2/3 of the width
                    readonly property real idealZoom: 3 * root.spanSamples / (4 * width * contentPopup.audioVisualRatio)
                    readonly property bool jumpSplitView: splitView && root.hotcue.type === root.hotcue.typeJump
                    readonly property real maxZoomClamp: Math.max(1, Math.min(10, idealZoom))

                    // The renderer centers each waveform window on the given
                    // position (playMarkerPosition = 0.5), and
                    // frames-per-pixel = zoom * audioVisualRatio.
                    // Cue positions and trackSamples are engine samples
                    // (frames * 2), hence the / 2.
                    readonly property real spanWidth: root.spanSamples / 2 / (zoom * contentPopup.audioVisualRatio)
                    // Loop/jump spans that don't fit fully into the window at
                    // the current zoom are shown split into two waveforms with
                    // the span start and end centered on each sub-waveform
                    // (warp effect). This follows the zoom dynamically via
                    // spanWidth.
                    readonly property bool splitView: root.hasSpan && spanWidth > width
                    property real zoom: {
                        if (root.hasSpan) {
                            if (width <= 0 || contentPopup.audioVisualRatio <= 0)
                                return 10;
                            return maxZoomClamp;
                        }
                        return zoomControl.value;
                    }

                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    objectName: "hotcuePopupWaveform"

                    Behavior on zoom {
                        SmoothedAnimation {
                            duration: 100
                            velocity: -1
                        }
                    }

                    Item {
                        anchors {
                            bottom: waveformPreview.jumpSplitView ? parent.verticalCenter : parent.bottom
                            left: parent.left
                            right: waveformPreview.splitView && !waveformPreview.jumpSplitView ? parent.horizontalCenter : parent.right
                            top: parent.top
                        }
                        PreviewWaveformDisplay {
                            id: waveformPreviewFull

                            anchors.fill: parent
                            objectName: "hotcuePopupWaveformFull"
                            position: {
                                if (root.trackSamples <= 0)
                                    return 0;
                                if (waveformPreview.splitView)
                                    return Math.max(0, root.cuePosition) / root.trackSamples;
                                if (root.spanCenterPosition < 0)
                                    return 0;
                                return root.spanCenterPosition / root.trackSamples;
                            }
                            track: root.currentTrack
                            zoom: waveformPreview.zoom
                        }
                    }
                    Item {
                        anchors {
                            bottom: parent.bottom
                            left: waveformPreview.jumpSplitView ? parent.left : parent.horizontalCenter
                            right: parent.right
                            top: waveformPreview.jumpSplitView ? parent.verticalCenter : parent.top
                        }
                        PreviewWaveformDisplay {
                            id: waveformPreviewPartial

                            anchors.fill: parent
                            objectName: "hotcuePopupWaveformPartial"
                            position: {
                                if (root.trackSamples <= 0)
                                    return 0;
                                if (waveformPreview.splitView)
                                    return Math.max(0, root.cueEndPosition) / root.trackSamples;
                                return root.spanCenterPosition / root.trackSamples;
                            }
                            track: root.currentTrack
                            visible: waveformPreview.splitView
                            zoom: waveformPreview.zoom
                        }
                    }
                    Rectangle {
                        id: loopOrJumpRect

                        anchors.bottom: parent.bottom
                        anchors.top: parent.top
                        color: hotcue.type === hotcue.typeJump ? Qt.alpha("grey", 0.6) : Qt.alpha(root.hotcue.color, 0.3)
                        objectName: "hotcuePopupSpanFiller"
                        visible: root.hasSpan && !(waveformPreview.jumpSplitView)
                        width: waveformPreview.splitView ? waveformPreview.width / 2 : waveformPreview.spanWidth
                        x: waveformPreview.splitView ? waveformPreview.width / 4 : parent.width / 2 - width / 2
                    }
                    Rectangle {
                        id: loopWarpSeam

                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        objectName: "hotcuePopupLoopSeam"
                        visible: waveformPreview.splitView && !waveformPreview.jumpSplitView
                        width: 10

                        gradient: Gradient {
                            orientation: Gradient.Horizontal

                            GradientStop {
                                color: "transparent"
                                position: 0
                            }
                            GradientStop {
                                color: "black"
                                position: 0.5
                            }
                            GradientStop {
                                color: "transparent"
                                position: 1
                            }
                        }
                    }
                    Rectangle {
                        id: jumpWarpDivider

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 3
                        objectName: "hotcuePopupJumpDivider"
                        visible: waveformPreview.jumpSplitView

                        gradient: Gradient {
                            orientation: Gradient.Vertical

                            GradientStop {
                                color: "transparent"
                                position: 0
                            }
                            GradientStop {
                                color: "black"
                                position: 0.5
                            }
                            GradientStop {
                                color: "transparent"
                                position: 1
                            }
                        }
                    }
                    // In jump-split mode the content skipped by the jump is
                    // masked with the span filler color: everything after the
                    // start (top half) and everything before the end
                    // (bottom half)
                    Rectangle {
                        color: loopOrJumpRect.color
                        height: waveformPreview.height / 2
                        objectName: "hotcuePopupSkipShadeTop"
                        visible: waveformPreview.jumpSplitView
                        width: waveformPreview.width / 2
                        x: parent.width / 2
                        y: 0
                    }
                    Rectangle {
                        color: loopOrJumpRect.color
                        height: waveformPreview.height / 2
                        objectName: "hotcuePopupSkipShadeBottom"
                        visible: waveformPreview.jumpSplitView
                        width: waveformPreview.width / 2
                        x: 0
                        y: waveformPreview.height / 2
                    }
                    Shape {
                        id: cueMarkerNotch

                        anchors.margins: 0
                        anchors.top: parent.top
                        height: waveformPreview.jumpSplitView ? parent.height / 2 : parent.height
                        layer.enabled: true
                        layer.samples: 16
                        objectName: "hotcuePopupStartNotch"
                        visible: root.hotcue.isSet
                        width: 12
                        x: {
                            if (waveformPreview.jumpSplitView) {
                                // Span start centered within the top half
                                return parent.width / 2 - width / 2;
                            }
                            if (root.hasSpan) {
                                // Span start edge for loop/jump
                                return (root.forwardSpan ? loopOrJumpRect.x : loopOrJumpRect.x + loopOrJumpRect.width) - width / 2;
                            }
                            // On the cue point otherwise
                            return parent.width / 2 - width / 2;
                        }

                        ShapePath {
                            fillColor: root.hotcue.color
                            startX: 6
                            startY: 0

                            PathLine {
                                x: 10
                                y: 0
                            }
                            PathArc {
                                direction: PathArc.Clockwise
                                radiusX: 2
                                radiusY: 2
                                x: 12
                                y: 2
                            }
                            PathLine {
                                x: 6
                                y: 6
                            }
                            PathLine {
                                x: 2
                                y: 2
                            }
                            PathArc {
                                direction: PathArc.Clockwise
                                useLargeArc: true
                                x: 2
                                y: 0
                            }
                            PathLine {
                                x: 6
                                y: 0
                            }
                        }
                        ShapePath {
                            fillColor: "transparent"
                            startX: 7
                            startY: 0
                            strokeColor: root.hotcue.color
                            strokeWidth: 2

                            PathLine {
                                x: 6
                                y: cueMarkerNotch.height
                            }
                        }
                    }
                    Shape {
                        id: cueEndMarkerNotch

                        anchors.bottom: waveformPreview.jumpSplitView ? parent.bottom : undefined
                        anchors.margins: 0
                        anchors.top: waveformPreview.jumpSplitView ? undefined : parent.top
                        height: waveformPreview.jumpSplitView ? parent.height / 2 : parent.height
                        layer.enabled: true
                        layer.samples: 16
                        objectName: "hotcuePopupEndNotch"
                        visible: root.hotcue.isSet && root.hasSpan
                        width: 12
                        x: {
                            if (waveformPreview.jumpSplitView) {
                                // Span end centered within the bottom half
                                return parent.width / 2 - width / 2;
                            }
                            return (root.forwardSpan ? loopOrJumpRect.x + loopOrJumpRect.width : loopOrJumpRect.x) - width / 2;
                        }

                        ShapePath {
                            fillColor: root.hotcue.color
                            startX: 6
                            startY: cueEndMarkerNotch.height
                            strokeWidth: 0

                            PathLine {
                                x: 2
                                y: cueEndMarkerNotch.height
                            }
                            PathArc {
                                direction: PathArc.Clockwise
                                useLargeArc: true
                                x: 2
                                y: cueEndMarkerNotch.height - 2
                            }
                            PathLine {
                                x: 6
                                y: cueEndMarkerNotch.height - 6
                            }
                            PathLine {
                                x: 10
                                y: cueEndMarkerNotch.height - 2
                            }
                            PathArc {
                                direction: PathArc.Clockwise
                                radiusX: 2
                                radiusY: 2
                                x: 10
                                y: cueEndMarkerNotch.height
                            }
                            PathLine {
                                x: 6
                                y: cueEndMarkerNotch.height
                            }
                        }
                        ShapePath {
                            fillColor: "transparent"
                            startX: 6
                            startY: 0
                            strokeColor: root.hotcue.color
                            strokeWidth: 2

                            PathLine {
                                x: 6
                                y: cueEndMarkerNotch.height
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent

                        onWheel: mouse => {
                            const clampedZoom = Math.max(1, Math.min(10, waveformPreview.zoom));
                            if (mouse.angleDelta.y < 0) {
                                waveformPreview.zoom = Math.max(1, clampedZoom - 1);
                            } else if (mouse.angleDelta.y > 0) {
                                waveformPreview.zoom = Math.min(10, clampedZoom + 1);
                            }
                        }
                    }
                    Skin.Button {
                        id: swapArrowButton

                        activeColor: Theme.deckActiveColor
                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        implicitHeight: 36
                        implicitWidth: 20
                        objectName: "hotcuePopupSwapButton"
                        visible: waveformPreview.jumpSplitView

                        contentItem: Item {
                            anchors.fill: parent

                            Shape {
                                anchors.centerIn: parent
                                antialiasing: true
                                height: 24
                                width: 12

                                ShapePath {
                                    fillColor: '#626262'
                                    startX: 2
                                    startY: 7
                                    strokeColor: 'transparent'

                                    PathLine {
                                        x: 6
                                        y: 3
                                    }
                                    PathLine {
                                        x: 10
                                        y: 7
                                    }
                                }
                                ShapePath {
                                    fillColor: '#626262'
                                    startX: 2
                                    startY: 17
                                    strokeColor: 'transparent'

                                    PathLine {
                                        x: 10
                                        y: 17
                                    }
                                    PathLine {
                                        x: 6
                                        y: 21
                                    }
                                }
                            }
                        }

                        onPressed: {
                            root.currentTrack.hotcuesModel.swapPositionsByHotcueNumber(root.hotcue.hotcueNumber - 1);
                        }
                    }
                }
                RowLayout {
                    id: colorAndTypeRow

                    spacing: 1

                    Repeater {
                        id: swatchRepeater

                        model: Mixxx.Config.hotcueColorPalette
                        objectName: "hotcuePopupSwatches"

                        Rectangle {
                            id: swatch

                            readonly property bool checked: {
                                const currentColor = root.hotcue.color;
                                if (!currentColor)
                                    return false;

                                return Qt.color(currentColor).toString() === Qt.color(swatch.modelData).toString();
                            }
                            required property int index
                            required property color modelData

                            border.color: Theme.hotcuePopupTextColor
                            border.width: checked ? 2 : 0
                            color: swatch.modelData
                            height: 24
                            objectName: "hotcuePopupSwatch_" + index
                            radius: 1
                            width: 24

                            Skin.InnerShadowMask {
                                radius: parent.radius
                                rimColor: "#353535"
                                size: 6
                                visible: checked
                            }
                            MouseArea {
                                acceptedButtons: Qt.LeftButton
                                anchors.fill: parent

                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        root.hotcue.setColor(swatch.modelData);
                                    }
                                }
                            }
                        }
                    }
                    Item {
                        id: typeSelector

                        Layout.alignment: Qt.AlignRight
                        implicitHeight: 22
                        implicitWidth: typeArrowLeft.width + typeLabel.width + typeArrowRight.width

                        RowLayout {
                            anchors.fill: parent
                            spacing: 0

                            Skin.Button {
                                id: typeArrowLeft

                                activeColor: Theme.deckActiveColor
                                implicitHeight: 22
                                implicitWidth: 20
                                objectName: "hotcuePopupTypePrev"

                                contentItem: Item {
                                    anchors.fill: parent

                                    Shape {
                                        anchors.centerIn: parent
                                        antialiasing: true
                                        height: 10
                                        width: 12

                                        ShapePath {
                                            fillColor: '#626262'
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

                                onPressed: {
                                    const newIndex = (root.typeIndex + root.cueTypes.length - 1) % root.cueTypes.length;
                                    root.convertTo(root.cueTypes[newIndex].type);
                                }
                            }
                            Skin.Button {
                                id: typeLabel

                                Layout.fillWidth: true
                                Layout.leftMargin: 0
                                Layout.rightMargin: 0
                                implicitHeight: 22
                                objectName: "hotcuePopupTypeLabel"
                                text: root.cueTypes[root.typeIndex].name
                            }
                            Skin.Button {
                                id: typeArrowRight

                                activeColor: Theme.deckActiveColor
                                implicitHeight: 22
                                implicitWidth: 20
                                objectName: "hotcuePopupTypeNext"

                                contentItem: Item {
                                    anchors.fill: parent

                                    Shape {
                                        anchors.centerIn: parent
                                        antialiasing: true
                                        height: 10
                                        width: 12

                                        ShapePath {
                                            capStyle: ShapePath.RoundCap
                                            fillColor: '#626262'
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

                                onPressed: {
                                    const newIndex = (root.typeIndex + 1) % root.cueTypes.length;
                                    root.convertTo(root.cueTypes[newIndex].type);
                                }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    TextField {
                        id: labelField

                        property string pendingLabel: ""

                        function commit() {
                            const label = pendingLabel !== "" ? pendingLabel : text;
                            if (label === "") {
                                return;
                            }
                            if (root.currentTrack) {
                                root.currentTrack.hotcuesModel.setLabelByHotcueNumber(root.hotcue.hotcueNumber - 1, label);
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
                        objectName: "hotcuePopupLabelField"
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
                        objectName: "hotcuePopupDeleteButton"

                        background: Rectangle {
                            color: deleteButton.hovered ? Theme.hotcuePopupDeleteHoverColor : "transparent"
                            radius: 4
                        }
                        contentItem: Item {
                            Shape {
                                height: 24
                                layer.enabled: true
                                layer.samples: 16
                                width: 24

                                // Top handle
                                ShapePath {
                                    capStyle: ShapePath.RoundCap
                                    fillColor: "transparent"
                                    joinStyle: ShapePath.BevelJoin
                                    startX: 9
                                    startY: 3
                                    strokeColor: '#c20e23'
                                    strokeWidth: 2

                                    PathLine {
                                        x: 15
                                        y: 3
                                    }
                                }

                                // Main bin body
                                ShapePath {
                                    fillColor: '#cf505b'
                                    startX: 6
                                    startY: 8
                                    strokeColor: "transparent"

                                    PathLine {
                                        x: 6
                                        y: 19
                                    }
                                    PathArc {
                                        direction: PathArc.Counterclockwise
                                        radiusX: 3
                                        radiusY: 3
                                        x: 9
                                        y: 22
                                    }
                                    PathLine {
                                        x: 15
                                        y: 22
                                    }
                                    PathArc {
                                        direction: PathArc.Counterclockwise
                                        x: 18
                                        y: 19
                                    }
                                    PathLine {
                                        x: 18
                                        y: 8
                                    }
                                }

                                // Lid
                                ShapePath {
                                    capStyle: ShapePath.RoundCap
                                    fillColor: "transparent"
                                    joinStyle: ShapePath.BevelJoin
                                    startX: 4
                                    startY: 8
                                    strokeColor: "#c20e23"
                                    strokeWidth: 3

                                    PathLine {
                                        x: 20
                                        y: 8
                                    }
                                }

                                // Left white slot
                                ShapePath {
                                    capStyle: ShapePath.RoundCap
                                    fillColor: "transparent"
                                    joinStyle: ShapePath.BevelJoin
                                    startX: 10
                                    startY: 12
                                    strokeColor: "#F4F1F1"
                                    strokeWidth: 2

                                    PathLine {
                                        x: 10
                                        y: 16
                                    }
                                }
                                // Right white slot
                                ShapePath {
                                    capStyle: ShapePath.RoundCap
                                    fillColor: "transparent"
                                    joinStyle: ShapePath.BevelJoin
                                    startX: 14
                                    startY: 12
                                    strokeColor: "#F4F1F1"
                                    strokeWidth: 2

                                    PathLine {
                                        x: 14
                                        y: 16
                                    }
                                }
                            }
                        }

                        onPressed: root.hotcue.clear = 1
                        onReleased: root.hotcue.clear = 0
                    }
                }
            }
        }
    }

    Mixxx.ControlProxy {
        id: trackSamplesControl

        group: root.hotcue.group
        key: "track_samples"
    }

    component PreviewWaveformDisplay: Mixxx.WaveformDisplay {
        backgroundColor: Theme.hotcuePopupBackgroundColor
        clip: true

        Behavior on position {
            SmoothedAnimation {
                duration: 500
                velocity: -1
            }
        }

        Mixxx.WaveformRendererFiltered {
            axesColor: "transparent"
            gainAll: 1.0
            gainHigh: 1.0
            gainLow: 1.0
            gainMid: 1.0
            highColor: "#D5C2A2"
            lowColor: "#2154D7"
            midColor: "#97632D"
        }
        Mixxx.WaveformRendererBeat {
            color: Qt.alpha('#cfcfcf', 0.3)
        }
    }
}
