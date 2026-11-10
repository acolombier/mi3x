import QtQuick 2.15

import "../Defines"
import "../Widgets" as Widgets
import "../Overlays" as Overlays
import "../ViewModels" as ViewModels

import Mixxx 1.0 as Mixxx
import Mixxx.Controls 1.0 as MixxxControls

Item {
    id: view

    property int deckId: deckInfo.deckId

    //--------------------------------------------------------------------------------------------------------------------

    required property var deckInfo
    property string deckSizeState: "large"
    property bool hideBPM: false
    property bool hideKey: false
    property bool hideLoop: false
    property bool isInEditMode: false
    readonly property int minSampleWidth: 2048
    property string propertiesPath: ""
    property int sampleWidth: minSampleWidth << zoomLevel
    property bool showLoopSize: false
    readonly property bool trackIsLoaded: deckInfo.isLoaded
    property int zoomLevel: deckInfo.zoomLevel

    //--------------------------------------------------------------------------------------------------------------------
    // WAVEFORM Position
    //------------------------------------------------------------------------------------------------------------------

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

        group: root.group
        key: "waveform_zoom"
    }
    MixxxControls.WaveformDisplay {
        id: singleWaveform

        anchors.fill: parent
        backgroundColor: "#36000000"
        group: `[Channel${view.deckId}]`
        height: (settings.alwaysShowTempoInfo || deckInfo.adjustEnabled ? (settings.hideWaveformOverview ? content.waveformHeight + display.secondRowHeight - 51 : content.waveformHeight - 38) : (!deckInfo.showBPMInfo ? (settings.hideWaveformOverview ? content.waveformHeight + display.secondRowHeight - 13 : content.waveformHeight) : (settings.hideWaveformOverview ? content.waveformHeight + display.secondRowHeight - 51 : content.waveformHeight - 38))) + (settings.hidePhase && settings.hidePhrase ? 16 : 0) + (!settings.hidePhase && !settings.hidePhrase ? -16 : 0)
        width: 316
        x: 0
        zoom: zoomControl.value

        Behavior on height {
            PropertyAnimation {
                duration: 90
            }
        }

        Mixxx.WaveformRendererEndOfTrack {
            color: 'blue'
            endOfTrackWarningTime: 30
        }
        Mixxx.WaveformRendererPreroll {
            color: '#998977'
        }
        Mixxx.WaveformRendererMarkRange {
            // <!-- Loop -->
            Mixxx.WaveformMarkRange {
                color: '#00b400'
                disabledColor: '#FFFFFF'
                disabledOpacity: 0.6
                enabledControl: "loop_enabled"
                endControl: "loop_end_position"
                opacity: 0.7
                startControl: "loop_start_position"
            }
            // <!-- Intro -->
            Mixxx.WaveformMarkRange {
                color: '#2c5c9a'
                durationTextColor: '#ffffff'
                durationTextLocation: 'after'
                endControl: "intro_end_position"
                opacity: 0.6
                startControl: "intro_start_position"
            }
            // <!-- Outro -->
            Mixxx.WaveformMarkRange {
                color: '#2c5c9a'
                durationTextColor: '#ffffff'
                durationTextLocation: 'before'
                endControl: "outro_end_position"
                opacity: 0.6
                startControl: "outro_start_position"
            }
        }
        Mixxx.WaveformRendererRGB {
            axesColor: '#00ffffff'
            gainAll: 1.5
            gainHigh: 1.0
            gainLow: 1.0
            gainMid: 1.0
            highColor: 'blue'
            lowColor: 'red'
            midColor: 'green'
        }
        Mixxx.WaveformRendererStem {
            gainAll: 1.5
            splitStemTracks: true
        }
        Mixxx.WaveformRendererBeat {
            color: settings.hideBeatgrid ? 'transparent' : Qt.rgba(0.81, 0.81, 0.81, settings.beatgridVisibility)
        }
        Mixxx.WaveformRendererMark {
            playMarkerBackground: 'transparent'
            playMarkerColor: 'cyan'
            untilMark.align: settings.distanceToCueAlignment == "bottom" ? Qt.AlignBottom : settings.distanceToCueAlignment == "top" ? Qt.AlignTop : Qt.AlignCenter
            untilMark.showBeats: settings.showBeatToCue
            untilMark.showTime: settings.showTimeToCue
            untilMark.textSize: settings.distanceToCueFontSize

            defaultMark: Mixxx.WaveformMark {
                align: "bottom|right"
                color: "#FF0000"
                text: " %1 "
                textColor: "#FFFFFF"
            }

            Mixxx.WaveformMark {
                align: 'top|right'
                color: 'red'
                control: "cue_point"
                text: 'C'
                textColor: '#FFFFFF'
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
                textColor: '#FFFFFF'
            }
        }
    }

    //--------------------------------------------------------------------------------------------------------------------
    // Stem Color Indicators (Rectangles)
    //--------------------------------------------------------------------------------------------------------------------

    StemColorIndicators {
        id: stemColorIndicators

        anchors.fill: singleWaveform
        anchors.rightMargin: 309
        deckId: view.deckId
        deckInfo: view.deckInfo
        indicatorHeight: !settings.hidePhase && !settings.hidePhrase ? (deckInfo.showBPMInfo ? [19, 19, 19, 20] : [27, 27, 27, 27]) : (deckInfo.showBPMInfo ? [23, 23, 23, 23] : [31, 31, 31, 31])
        visible: deckInfoModel.isStemDeck
    }
    Widgets.LoopSize {
        id: loopSize

        anchors.fill: parent
        anchors.topMargin: 1
        visible: (deckInfo.showLoopInfo || deckInfo.loopActive || settings.alwaysShowLoopSize) && !hideLoop
    }
    Widgets.KeyDisplay {
        id: keyDisplay

        anchors.fill: parent
        anchors.topMargin: 1
        visible: !hideKey
    }
    Widgets.BpmDisplay {
        id: bpmDisplay

        anchors.bottomMargin: 1
        anchors.fill: parent
        anchors.top: singleWaveform.bottom
        visible: !hideBPM && (!deckInfo.showBPMInfo && !settings.alwaysShowTempoInfo && !deckInfo.adjustEnabled) || settings.hideWaveforms
    }
}
