import "." as Skin
import Mixxx 1.0 as Mixxx
import Mixxx.Controls 1.0 as MixxxControls
import QtQuick 2.12
import "Theme"

Item {
    id: root

    enum MouseStatus {
        Normal,
        Bending,
        Scratching
    }

    property var axesColor: '#a1a1a1a1'
    property double globalGain: Mixxx.Config.waveformVisualGainAll
    required property string group
    // TODO add support for color
    property color highColor: '#D5C2A2'
    property double highGain: Mixxx.Config.waveformVisualGainHigh
    property color lowColor: '#2154D7'
    property double lowGain: Mixxx.Config.waveformVisualGainLow
    property color midColor: '#97632D'
    property double middleGain: Mixxx.Config.waveformVisualGainMedium
    property bool splitStemTracks: false
    readonly property string zoomGroup: Mixxx.Config.waveformZoomSynchronization ? "[Channel1]" : group

    function onRenderAdded(object) {
        if (display.renderers[0] === null) {
            display.renderers[0] = object;
        } else {
            display.renderers.splice(0, 0, object);
        }
    }
    function onRenderRemoved(object) {
        let index = display.renderers.indexOf(object);
        if (index < 0) {
            console.error("Unable to find the stale rendered in the stack! Prepare for use after free crash.", object);
            return;
        }
        display.renderers[index] = null;
    }

    // Used by E2E tests - format <Renderer Debug string> + <stackedPropertyValue>
    function renderType() {
        print("Called renderType", display.renderers[0]);
        return "" + (display.renderers[0] ?? "") + " " + display.renderers[0]?.stacked;
    }

    MixxxControls.WaveformDisplay {
        id: display

        anchors.fill: parent
        backgroundColor: "transparent"
        group: root.group
        zoom: zoomControl.value

        Behavior on zoom {
            SmoothedAnimation {
                duration: 500
                velocity: -1
            }
        }

        Mixxx.WaveformRendererEndOfTrack {
            color: '#ff8872'
            endOfTrackWarningTime: Mixxx.Config.waveformEndOfTrackWarningTime
        }
        Mixxx.WaveformRendererPreroll {
            color: '#ff8872'
        }
        Mixxx.WaveformRendererMarkRange {
            // Loop
            Mixxx.WaveformMarkRange {
                color: '#00b400'
                disabledColor: '#FFFFFF'
                disabledOpacity: 0.6
                enabledControl: "loop_enabled"
                endControl: "loop_end_position"
                opacity: 0.7
                startControl: "loop_start_position"
            }
            // Intro
            Mixxx.WaveformMarkRange {
                color: '#2c5c9a'
                durationTextColor: '#ffffff'
                durationTextLocation: 'after'
                endControl: "intro_end_position"
                opacity: 0.6
                startControl: "intro_start_position"
            }
            // Outro
            Mixxx.WaveformMarkRange {
                color: '#2c5c9a'
                durationTextColor: '#ffffff'
                durationTextLocation: 'before'
                endControl: "outro_end_position"
                opacity: 0.6
                startControl: "outro_start_position"
            }
        }
        Mixxx.WaveformRendererStem {
            gainAll: root.splitStemTracks ? 2.0 : 1.0
            splitStemTracks: root.splitStemTracks
        }
        Mixxx.WaveformRendererBeat {
            color: Qt.alpha('#a1a1a1', Mixxx.Config.waveformBeatGridAlpha / 100)
        }
        Mixxx.WaveformRendererMark {
            playMarkerBackground: '#D9D9D9'
            playMarkerColor: '#D9D9D9'
            playMarkerPosition: Mixxx.Config.waveformPlayMarkerPosition
            untilMark.align: {
                switch (Mixxx.Config.waveformUntilMarkAlign) {
                case 0:
                    return Qt.AlignTop;
                case 2:
                    return Qt.AlignBottom;
                case 1:
                    return Qt.AlignVCenter;
                }
                console.warn("unknown value for waveformUntilMarkAlign. Defaulting to center");
                return Qt.AlignVCenter;
            }
            untilMark.showBeats: Mixxx.Config.waveformUntilMarkShowBeats
            untilMark.showTime: Mixxx.Config.waveformUntilMarkShowTime
            untilMark.textSize: Mixxx.Config.waveformUntilMarkTextPointSize

            defaultMark: Mixxx.WaveformMark {
                align: "bottom|right"
                color: "#00d9ff"
                endIcon: Qt.resolvedUrl("images/jump_%1.svg")
                text: " %1 "
                textColor: "#1a1a1a"
            }

            Mixxx.WaveformMark {
                align: 'top|right'
                color: 'red'
                control: "cue_point"
                text: 'CUE'
                textColor: '#1a1a1a'
            }
            Mixxx.WaveformMark {
                align: 'top|left'
                color: 'green'
                control: "loop_start_position"
                text: '↻'
                textColor: '#FFFFFF'
            }
            Mixxx.WaveformMark {
                align: 'bottom|right'
                color: 'green'
                control: "loop_end_position"
                textColor: '#FFFFFF'
            }
            Mixxx.WaveformMark {
                align: 'top|right'
                color: 'blue'
                control: "intro_start_position"
                text: '◢'
                textColor: '#FFFFFF'
            }
            Mixxx.WaveformMark {
                align: 'top|left'
                color: 'blue'
                control: "intro_end_position"
                text: '◢'
                textColor: '#FFFFFF'
            }
            Mixxx.WaveformMark {
                align: 'top|right'
                color: 'blue'
                control: "outro_start_position"
                text: '◣'
                textColor: '#FFFFFF'
            }
            Mixxx.WaveformMark {
                align: 'top|left'
                color: 'blue'
                control: "outro_end_position"
                text: '◣'
                textColor: '#FFFFFF'
            }
        }
    }
    Mixxx.ControlProxy {
        id: scratchPositionEnableControl

        group: root.group
        key: "scratch_position_enable"
    }
    Mixxx.ControlProxy {
        id: scratchPositionControl

        group: root.group
        key: "scratch_position"
    }
    Mixxx.ControlProxy {
        id: wheelControl

        group: root.group
        key: "wheel"
    }
    Mixxx.ControlProxy {
        id: rateRatioControl

        group: root.group
        key: "rate_ratio"
    }
    Mixxx.ControlProxy {
        id: zoomControl

        group: root.zoomGroup
        key: "waveform_zoom"

        Component.onCompleted: {
            if (group == root.group) {
                value = Mixxx.Config.waveformDefaultZoom;
            }
        }
    }
    Instantiator {
        active: Mixxx.Config.waveformType == Mixxx.WaveformDisplay.Filtered || Mixxx.Config.waveformType == Mixxx.WaveformDisplay.Stacked

        onObjectAdded: (_index, object) => root.onRenderAdded(object)
        onObjectRemoved: (_index, object) => root.onRenderRemoved(object)

        Mixxx.WaveformRendererFiltered {
            axesColor: root.axesColor
            gainAll: root.globalGain
            gainHigh: root.highGain
            gainLow: root.lowGain
            gainMid: root.middleGain
            highColor: root.highColor
            lowColor: root.lowColor
            midColor: root.midColor
            stacked: Mixxx.Config.waveformType == Mixxx.WaveformDisplay.Stacked
        }
    }
    Instantiator {
        active: Mixxx.Config.waveformType == Mixxx.WaveformDisplay.HSV

        onObjectAdded: (_index, object) => root.onRenderAdded(object)
        onObjectRemoved: (_index, object) => root.onRenderRemoved(object)

        Mixxx.WaveformRendererHSV {
            axesColor: root.axesColor
            color: root.lowColor
            gainAll: root.globalGain
            gainHigh: root.highGain
            gainLow: root.lowGain
            gainMid: root.middleGain
            ignoreStem: true
        }
    }
    Instantiator {
        active: Mixxx.Config.waveformType == Mixxx.WaveformDisplay.RGB

        onObjectAdded: (_index, object) => root.onRenderAdded(object)
        onObjectRemoved: (_index, object) => root.onRenderRemoved(object)

        Mixxx.WaveformRendererRGB {
            axesColor: root.axesColor
            gainAll: root.globalGain
            gainHigh: root.highGain
            gainLow: root.lowGain
            gainMid: root.middleGain
            highColor: root.highColor
            ignoreStem: true
            lowColor: root.lowColor
            midColor: root.midColor
        }
    }
    Instantiator {
        active: Mixxx.Config.waveformType == Mixxx.WaveformDisplay.Simple

        onObjectAdded: (_index, object) => root.onRenderAdded(object)
        onObjectRemoved: (_index, object) => root.onRenderRemoved(object)

        Mixxx.WaveformRendererSimple {
            axesColor: root.axesColor
            color: root.lowColor
            gain: root.globalGain
            ignoreStem: true
        }
    }
    MouseArea {
        property point mouseAnchor: Qt.point(0, 0)
        property int mouseStatus: WaveformDisplay.MouseStatus.Normal

        acceptedButtons: Qt.LeftButton | Qt.RightButton
        anchors.fill: parent

        onDoubleClicked: {
            if (mouse.button == Qt.RightButton) {
                root.splitStemTracks = !root.splitStemTracks;
            }
        }
        onPositionChanged: mouse => {
            const diff = mouse.x - mouseAnchor.x;
            switch (mouseStatus) {
            case WaveformDisplay.MouseStatus.Bending:
                {
                    // Start at the middle of [0.0, 1.0], and emit values based on how far
                    // the mouse has traveled horizontally. Note, for legacy (MIDI) reasons,
                    // this is tuned to 127.
                    const v = 0.5 + (diff / root.width);
                    // clamp to [0.0, 1.0]
                    wheelControl.parameter = Math.max(Math.min(v, 1), 0);
                    break;
                }
            case WaveformDisplay.MouseStatus.Scratching:
                // TODO: Calculate position properly
                scratchPositionControl.value = -diff * zoomControl.value * 200;
                break;
            }
        }
        onPressed: mouse => {
            mouseAnchor = Qt.point(mouse.x, mouse.y);
            if (mouse.button == Qt.LeftButton) {
                if (mouseStatus == WaveformDisplay.MouseStatus.Bending)
                    wheelControl.parameter = 0.5;

                mouseStatus = WaveformDisplay.MouseStatus.Scratching;
                scratchPositionControl.value = 0;
                scratchPositionEnableControl.value = 1;
            } else {
                if (mouseStatus == WaveformDisplay.MouseStatus.Scratching)
                    scratchPositionEnableControl.value = 0;

                wheelControl.parameter = 0.5;
                mouseStatus = WaveformDisplay.MouseStatus.Bending;
            }
        }
        onReleased: {
            switch (mouseStatus) {
            case WaveformDisplay.MouseStatus.Bending:
                wheelControl.parameter = 0.5;
                break;
            case WaveformDisplay.MouseStatus.Scratching:
                scratchPositionEnableControl.value = 0;
                scratchPositionControl.value = 0;
                break;
            }
            mouseStatus = WaveformDisplay.MouseStatus.Normal;
        }
        onWheel: mouse => {
            if (mouse.angleDelta.y < 0 && zoomControl.value > 1) {
                zoomControl.value -= 1;
            } else if (mouse.angleDelta.y > 0 && zoomControl.value < 10.0) {
                zoomControl.value += 1;
            }
        }
    }
}
