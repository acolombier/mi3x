import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Mixxx 1.0 as Mixxx
import "." as Setting
import "." as SettingComponents
import ".." as Skin
import "../Theme"

Category {
    id: root

    property bool dirty: false

    function load() {
        bpmDetectionSetting.selected = Mixxx.Config.bpmDetectionEnabled ? "on" : "off";
        bpmAnalyserPlugin.selected = Mixxx.Config.bpmAnalyserPluginId == "mixxxbpmdetection" ? "soundtouch" : "queenmary";
        bpmFixedTempoSetting.selected = Mixxx.Config.bpmFixedTempoAssumption ? "on" : "off";
        // Fast analysis cannot be combined with non-constant tempo
        // beatgrids (see DlgPrefBeats::updateGui).
        bpmFastAnalysisSetting.selected = (Mixxx.Config.bpmFastAnalysis && Mixxx.Config.bpmFixedTempoAssumption) ? "on" : "off";
        bpmReanalyzeSetting.selected = Mixxx.Config.bpmReanalyzeWhenSettingsChange ? "on" : "off";
        bpmReanalyzeImportedSetting.selected = Mixxx.Config.bpmReanalyzeImported ? "on" : "off";

        keyDetectionSetting.selected = Mixxx.Config.keyDetectionEnabled ? "on" : "off";
        keyAnalyserPlugin.selected = Mixxx.Config.keyAnalyserPluginId == "keyfinder:2" ? "keyfinder" : "queenmary";
        keyFastAnalysisSetting.selected = Mixxx.Config.keyFastAnalysis ? "on" : "off";
        keyReanalyzeSetting.selected = Mixxx.Config.keyReanalyzeWhenSettingsChange ? "on" : "off";
        keyNotationSetting.selected = ({
            "Lancelot": "lancelot",
            "Lancelot/Traditional": "lancelot",
            "OpenKey": "openkey",
            "OpenKey/Traditional": "openkey",
            "Traditional": "traditional",
            "Custom": "custom",
        })[Mixxx.Config.keyNotation] ?? "traditional";

        replayGainSetting.selected = Mixxx.Config.replayGainEnabled ? "on" : "off";
        replayGainAnalyserPlugin.selected = Mixxx.Config.replayGainAnalyserVersion == 1 ? "replaygain10" : "replaygain20";
        replayGainReanalyzeSetting.selected = Mixxx.Config.replayGainReanalyze ? "on" : "off";
        replayGainTargetLoudnessInput.setValue(Mixxx.Config.replayGainTargetLoudnessAdjust);
        replayGainDefaultBoostInput.setValue(Mixxx.Config.replayGainDefaultBoost);
        root.dirty = false;
    }
    function reset() {
        // NOTE: Keep the defaults in sync with BeatDetectionSettings,
        // KeyDetectionSettings and ReplayGainSettings.
        Mixxx.Config.bpmDetectionEnabled = true;
        Mixxx.Config.bpmAnalyserPluginId = "qm-tempotracker:0";
        Mixxx.Config.bpmFixedTempoAssumption = true;
        Mixxx.Config.bpmFastAnalysis = false;
        Mixxx.Config.bpmReanalyzeWhenSettingsChange = false;
        Mixxx.Config.bpmReanalyzeImported = false;

        Mixxx.Config.keyDetectionEnabled = true;
        Mixxx.Config.keyAnalyserPluginId = "qm-keydetector:2";
        Mixxx.Config.keyFastAnalysis = false;
        Mixxx.Config.keyReanalyzeWhenSettingsChange = false;
        Mixxx.Config.keyNotation = "Traditional";
        keyNotationControl.value = 4; // KeyUtils::KeyNotation::Traditional

        Mixxx.Config.replayGainEnabled = true;
        Mixxx.Config.replayGainAnalyser = true;
        Mixxx.Config.replayGainAnalyserVersion = 2;
        Mixxx.Config.replayGainReanalyze = false;
        Mixxx.Config.replayGainTargetLoudnessAdjust = 0;
        Mixxx.Config.replayGainDefaultBoost = -6;
        load();
    }
    function save() {
        const bpmEnabled = bpmDetectionSetting.selected == "on";
        Mixxx.Config.bpmDetectionEnabled = bpmEnabled;
        Mixxx.Config.bpmAnalyserPluginId = bpmAnalyserPlugin.selected == "soundtouch" ? "mixxxbpmdetection" : "qm-tempotracker:0";
        const fixedTempo = bpmFixedTempoSetting.selected == "on";
        Mixxx.Config.bpmFixedTempoAssumption = fixedTempo;
        // Fast analysis cannot be combined with non-constant tempo
        // beatgrids (see DlgPrefBeats::slotApply).
        Mixxx.Config.bpmFastAnalysis = bpmEnabled && fixedTempo && bpmFastAnalysisSetting.selected == "on";
        Mixxx.Config.bpmReanalyzeWhenSettingsChange = bpmEnabled && bpmReanalyzeSetting.selected == "on";
        Mixxx.Config.bpmReanalyzeImported = bpmEnabled && bpmReanalyzeImportedSetting.selected == "on";

        const keyEnabled = keyDetectionSetting.selected == "on";
        Mixxx.Config.keyDetectionEnabled = keyEnabled;
        Mixxx.Config.keyAnalyserPluginId = keyAnalyserPlugin.selected == "keyfinder" ? "keyfinder:2" : "qm-keydetector:2";
        Mixxx.Config.keyFastAnalysis = keyEnabled && keyFastAnalysisSetting.selected == "on";
        Mixxx.Config.keyReanalyzeWhenSettingsChange = keyEnabled && keyReanalyzeSetting.selected == "on";
        const notationNames = {
            "lancelot": "Lancelot",
            "openkey": "OpenKey",
            "traditional": "Traditional",
            "custom": "Custom",
        };
        // KeyUtils::KeyNotation: Custom = 1, OpenKey = 2, Lancelot = 3,
        // Traditional = 4. The '[Library],key_notation' ControlObject drives
        // the key sort order of the library tracks (see ColumnCache), keep
        // it in sync with the notation config.
        const notationValues = {
            "lancelot": 3,
            "openkey": 2,
            "traditional": 4,
            "custom": 1,
        };
        Mixxx.Config.keyNotation = notationNames[keyNotationSetting.selected];
        keyNotationControl.value = notationValues[keyNotationSetting.selected];

        const replayGainEnabled = replayGainSetting.selected == "on";
        Mixxx.Config.replayGainEnabled = replayGainEnabled;
        Mixxx.Config.replayGainAnalyser = replayGainEnabled;
        Mixxx.Config.replayGainAnalyserVersion = replayGainAnalyserPlugin.selected == "replaygain10" ? 1 : 2;
        Mixxx.Config.replayGainReanalyze = replayGainEnabled && replayGainReanalyzeSetting.selected == "on";
        Mixxx.Config.replayGainTargetLoudnessAdjust = Math.round(replayGainTargetLoudnessInput.value);
        Mixxx.Config.replayGainDefaultBoost = Math.round(replayGainDefaultBoostInput.value);
        load();
    }

    label: qsTr("Analyzer")

    Mixxx.ControlProxy {
        id: keyNotationControl

        group: "[Library]"
        key: "key_notation"
    }

    Component.onCompleted: {
        root.load();
    }

    ScrollView {
        id: scrollView

        ScrollBar.vertical: ScrollBar {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.top: parent.top
            objectName: "analyzerSettingsScrollBar"
            policy: ScrollBar.AsNeeded
        }
        anchors.bottom: buttonActions.top
        anchors.bottomMargin: 18
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        ColumnLayout {
            width: root.width - 10

            Mixxx.SettingGroup {
                Layout.bottomMargin: 6
                implicitWidth: scrollView.width
                implicitHeight: bpmColumn.height
                label: qsTr("BPM and Beat detection")

                Column {
                    id: bpmColumn

                    anchors.left: parent.left
                    anchors.right: parent.right

                    RowLayout {
                        Layout.bottomMargin: 12
                        Layout.leftMargin: 17
                        Layout.rightMargin: 17
                        Layout.topMargin: 6
                        width: parent.width

                        Text {
                            Layout.fillWidth: true
                            color: Theme.white
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            text: qsTr("BPM and Beat detection")
                        }
                        RatioChoice {
                            id: bpmDetectionSetting

                            inactiveColor: Theme.darkGray4
                            maxWidth: parent.width * 0.25
                            objectName: "setting_bpmDetection"
                            options: ["off", "on"]

                            onSelectedChanged: root.dirty = true
                        }
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        color: Theme.darkGray2
                        implicitHeight: bpmPane.implicitHeight + 20

                        GridLayout {
                            id: bpmPane

                            anchors.bottomMargin: 10
                            anchors.fill: parent
                            anchors.leftMargin: 17
                            anchors.rightMargin: 17
                            anchors.topMargin: 10
                            columnSpacing: 20
                            columns: bpmColumn.width < 850 ? 1 : 2
                            objectName: "analyzerBpmGrid"
                            rowSpacing: 15

                            RowLayout {
                                Layout.columnSpan: bpmPane.columns
                                Layout.preferredWidth: bpmPane.width

                                Mixxx.SettingParameter {
                                    Layout.fillWidth: true
                                    label: qsTr("Analyser")
                                    keywords: [qsTr("Beat"), qsTr("BPM")]

                                    Text {
                                        anchors.fill: parent
                                        color: Theme.white
                                        font.pixelSize: 16
                                        font.weight: Font.DemiBold
                                        horizontalAlignment: Text.AlignHCenter
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                RatioChoice {
                                    id: bpmAnalyserPlugin

                                    enabled: bpmDetectionSetting.selected != "off"
                                    inactiveColor: Theme.darkGray4
                                    maxWidth: parent.width * 0.5
                                    objectName: "setting_bpmAnalyser"
                                    options: ["queenmary", "soundtouch"]
                                    tooltips: [
                                        qsTr("Queen Mary Tempo and Beat Tracker"),
                                        qsTr("SoundTouch BPM Detector (Legacy)"),
                                    ]

                                    onSelectedChanged: root.dirty = true
                                }
                            }
                            RowLayout {
                                Layout.preferredWidth: bpmPane.width / bpmPane.columns

                                Mixxx.SettingParameter {
                                    Layout.fillWidth: true
                                    label: qsTr("Assume constant tempo")

                                    Text {
                                        anchors.fill: parent
                                        color: Theme.white
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                RatioChoice {
                                    id: bpmFixedTempoSetting

                                    enabled: bpmDetectionSetting.selected != "off" && bpmAnalyserPlugin.selected == "queenmary"
                                    inactiveColor: Theme.darkGray4
                                    maxWidth: parent.width * 0.5
                                    objectName: "setting_bpmFixedTempo"
                                    options: ["off", "on"]

                                    onSelectedChanged: root.dirty = true
                                }
                            }
                            RowLayout {
                                Layout.preferredWidth: bpmPane.width / bpmPane.columns

                                Mixxx.SettingParameter {
                                    Layout.fillWidth: true
                                    label: qsTr("Re-analyse beats when settings change or beat detection data is outdated")

                                    Text {
                                        anchors.fill: parent
                                        color: Theme.white
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                RatioChoice {
                                    id: bpmReanalyzeSetting

                                    enabled: bpmDetectionSetting.selected != "off"
                                    inactiveColor: Theme.darkGray4
                                    maxWidth: parent.width * 0.5
                                    objectName: "setting_bpmReanalyze"
                                    options: ["off", "on"]

                                    onSelectedChanged: root.dirty = true
                                }
                            }
                            ColumnLayout {
                                Layout.preferredWidth: bpmPane.width / bpmPane.columns

                                RowLayout {
                                    width: parent.width

                                    Mixxx.SettingParameter {
                                        Layout.fillWidth: true
                                        label: qsTr("Fast Analysis")

                                        Column {
                                            anchors.fill: parent
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                color: Theme.white
                                                font.pixelSize: 14
                                                font.weight: Font.Medium
                                                horizontalAlignment: Text.AlignLeft
                                                text: parent.parent.label
                                                verticalAlignment: Text.AlignVCenter
                                                width: parent.width
                                            }
                                            Text {
                                                color: Theme.midGray
                                                font.pixelSize: 11
                                                text: qsTr("Recommended for slow computer, may be less accurate")
                                                width: parent.width
                                            }
                                        }
                                    }
                                    RatioChoice {
                                        id: bpmFastAnalysisSetting

                                        // Fast analysis cannot be combined with
                                        // non-constant tempo beatgrids (see
                                        // DlgPrefBeats::updateGui).
                                        enabled: bpmDetectionSetting.selected != "off" && bpmAnalyserPlugin.selected == "queenmary" && bpmFixedTempoSetting.selected == "on"
                                        inactiveColor: Theme.darkGray4
                                        maxWidth: parent.width * 0.5
                                        objectName: "setting_bpmFastAnalysis"
                                        options: ["off", "on"]

                                        onSelectedChanged: root.dirty = true
                                    }
                                }
                            }
                            RowLayout {
                                Layout.preferredWidth: bpmPane.width / bpmPane.columns

                                Mixxx.SettingParameter {
                                    Layout.fillWidth: true
                                    label: qsTr("Re-analyse beatgrids imported from other DJ software")

                                    Text {
                                        anchors.fill: parent
                                        color: Theme.white
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                RatioChoice {
                                    id: bpmReanalyzeImportedSetting

                                    enabled: bpmDetectionSetting.selected != "off"
                                    inactiveColor: Theme.darkGray4
                                    maxWidth: parent.width * 0.5
                                    objectName: "setting_bpmReanalyzeImported"
                                    options: ["off", "on"]

                                    onSelectedChanged: root.dirty = true
                                }
                            }
                        }
                    }
                }
            }
            Mixxx.SettingGroup {
                Layout.bottomMargin: 6
                implicitWidth: scrollView.width
                implicitHeight: keyColumn.height
                label: qsTr("Key detection")

                Column {
                    id: keyColumn

                    anchors.left: parent.left
                    anchors.right: parent.right

                    RowLayout {
                        Layout.bottomMargin: 12
                        Layout.leftMargin: 17
                        Layout.rightMargin: 17
                        Layout.topMargin: 6
                        width: parent.width

                        Text {
                            Layout.fillWidth: true
                            color: Theme.white
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            text: qsTr("Key detection")
                        }
                        RatioChoice {
                            id: keyDetectionSetting

                            inactiveColor: Theme.darkGray4
                            maxWidth: parent.width * 0.25
                            objectName: "setting_keyDetection"
                            options: ["off", "on"]

                            onSelectedChanged: root.dirty = true
                        }
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        color: Theme.darkGray2
                        implicitHeight: keyPane.implicitHeight + 20

                        GridLayout {
                            id: keyPane

                            anchors.bottomMargin: 10
                            anchors.fill: parent
                            anchors.leftMargin: 17
                            anchors.rightMargin: 17
                            anchors.topMargin: 10
                            columnSpacing: 20
                            columns: keyColumn.width < 850 ? 1 : 2
                            objectName: "analyzerKeyGrid"
                            rowSpacing: 15

                            RowLayout {
                                Layout.columnSpan: keyPane.columns
                                Layout.preferredWidth: keyPane.width

                                Mixxx.SettingParameter {
                                    Layout.fillWidth: true
                                    label: qsTr("Analyser")
                                    keywords: [qsTr("Key")]

                                    Text {
                                        anchors.fill: parent
                                        color: Theme.white
                                        font.pixelSize: 16
                                        font.weight: Font.DemiBold
                                        horizontalAlignment: Text.AlignHCenter
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                RatioChoice {
                                    id: keyAnalyserPlugin

                                    enabled: keyDetectionSetting.selected != "off"
                                    inactiveColor: Theme.darkGray4
                                    maxWidth: parent.width * 0.5
                                    objectName: "setting_keyAnalyser"
                                    options: ["queenmary", "keyfinder"]
                                    tooltips: [
                                        qsTr("Queen Mary Key Detector"),
                                        qsTr("KeyFinder"),
                                    ]

                                    onSelectedChanged: root.dirty = true
                                }
                            }
                            ColumnLayout {
                                Layout.preferredWidth: keyPane.width / keyPane.columns

                                RowLayout {
                                    width: parent.width

                                    Mixxx.SettingParameter {
                                        Layout.fillWidth: true
                                        label: qsTr("Fast Analysis")

                                        Column {
                                            anchors.fill: parent
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                color: Theme.white
                                                font.pixelSize: 14
                                                font.weight: Font.Medium
                                                horizontalAlignment: Text.AlignLeft
                                                text: parent.parent.label
                                                verticalAlignment: Text.AlignVCenter
                                                width: parent.width
                                            }
                                            Text {
                                                color: Theme.midGray
                                                font.pixelSize: 11
                                                text: qsTr("Recommended for slow computer, may be less accurate")
                                                width: parent.width
                                            }
                                        }
                                    }
                                    RatioChoice {
                                        id: keyFastAnalysisSetting

                                        enabled: keyDetectionSetting.selected != "off"
                                        inactiveColor: Theme.darkGray4
                                        maxWidth: parent.width * 0.5
                                        objectName: "setting_keyFastAnalysis"
                                        options: ["off", "on"]

                                        onSelectedChanged: root.dirty = true
                                    }
                                }
                            }
                            RowLayout {
                                Layout.preferredWidth: keyPane.width / keyPane.columns

                                Mixxx.SettingParameter {
                                    Layout.fillWidth: true
                                    label: qsTr("Re-analyse beats when settings change or 3rd-party keys are present")

                                    Text {
                                        anchors.fill: parent
                                        color: Theme.white
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                RatioChoice {
                                    id: keyReanalyzeSetting

                                    enabled: keyDetectionSetting.selected != "off"
                                    inactiveColor: Theme.darkGray4
                                    maxWidth: parent.width * 0.5
                                    objectName: "setting_keyReanalyze"
                                    options: ["off", "on"]

                                    onSelectedChanged: root.dirty = true
                                }
                            }
                            RowLayout {
                                Layout.columnSpan: keyPane.columns
                                Layout.preferredWidth: keyPane.width

                                Mixxx.SettingParameter {
                                    Layout.fillWidth: true
                                    label: qsTr("Key Notation")

                                    Text {
                                        anchors.fill: parent
                                        color: Theme.white
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                RatioChoice {
                                    id: keyNotationSetting

                                    enabled: keyDetectionSetting.selected != "off"
                                    inactiveColor: Theme.darkGray4
                                    maxWidth: parent.width * 0.65
                                    objectName: "setting_keyNotation"
                                    options: ["lancelot", "traditional", "openkey", "custom"]

                                    onSelectedChanged: root.dirty = true
                                }
                            }
                        }
                    }
                }
            }
            Mixxx.SettingGroup {
                Layout.bottomMargin: 6
                Layout.topMargin: 40
                implicitWidth: scrollView.width
                implicitHeight: replayGainColumn.height
                label: qsTr("ReplayGain Loudness Normalization")

                Column {
                    id: replayGainColumn

                    anchors.left: parent.left
                    anchors.right: parent.right

                    RowLayout {
                        Layout.bottomMargin: 12
                        Layout.leftMargin: 17
                        Layout.rightMargin: 17
                        Layout.topMargin: 6
                        width: parent.width

                        Text {
                            Layout.fillWidth: true
                            color: Theme.white
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            text: qsTr("ReplayGain Loudness Normalization")
                        }
                        RatioChoice {
                            id: replayGainSetting

                            inactiveColor: Theme.darkGray4
                            maxWidth: parent.width * 0.25
                            objectName: "setting_replayGain"
                            options: ["off", "on"]

                            onSelectedChanged: root.dirty = true
                        }
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        color: Theme.darkGray2
                        implicitHeight: replayGainPane.implicitHeight + 20

                        GridLayout {
                            id: replayGainPane

                            anchors.bottomMargin: 10
                            anchors.fill: parent
                            anchors.leftMargin: 17
                            anchors.rightMargin: 17
                            anchors.topMargin: 10
                            columnSpacing: 20
                            columns: replayGainColumn.width < 850 ? 1 : 2
                            objectName: "analyzerReplayGainGrid"
                            rowSpacing: 15

                            RowLayout {
                                Layout.columnSpan: replayGainPane.columns
                                Layout.preferredWidth: replayGainPane.width

                                Mixxx.SettingParameter {
                                    Layout.fillWidth: true
                                    label: qsTr("Analyser")
                                    keywords: [qsTr("ReplayGain"), qsTr("EBU R128"), qsTr("Loudness")]

                                    Text {
                                        anchors.fill: parent
                                        color: Theme.white
                                        font.pixelSize: 16
                                        font.weight: Font.DemiBold
                                        horizontalAlignment: Text.AlignHCenter
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                RatioChoice {
                                    id: replayGainAnalyserPlugin

                                    enabled: replayGainSetting.selected != "off"
                                    inactiveColor: Theme.darkGray4
                                    maxWidth: parent.width * 0.5
                                    objectName: "setting_replayGainAnalyser"
                                    options: ["replaygain20", "replaygain10"]
                                    tooltips: [
                                        qsTr("ReplayGain 2.0 (ITU-R BS.1770)"),
                                        qsTr("ReplayGain 1.0"),
                                    ]

                                    onSelectedChanged: root.dirty = true
                                }
                            }
                            ColumnLayout {
                                Layout.preferredWidth: replayGainPane.width / replayGainPane.columns

                                Mixxx.SettingParameter {
                                    Layout.fillWidth: true
                                    label: qsTr("Target loudness")

                                    Text {
                                        anchors.fill: parent
                                        color: Theme.white
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    color: Theme.midGray
                                    font.pixelSize: 11
                                    // ReplayGain targets a reference loudness of
                                    // -18 LUFS. The adjustment is relative to it.
                                    text: qsTr("Adjust by: %1%2 dB")
                                        .arg(replayGainTargetLoudnessInput.value < 0 ? "" : "+")
                                        .arg(replayGainTargetLoudnessInput.value)
                                }
                                SettingComponents.Slider {
                                    id: replayGainTargetLoudnessInput

                                    Layout.preferredWidth: 400
                                    decimals: 0
                                    markers: [-12, -6, 0, 6, 12]
                                    max: 12
                                    min: -12
                                    objectName: "setting_replayGainTargetLoudness"
                                    suffix: qsTr(" dB")
                                    value: 0
                                    wheelStep: 1

                                    onValueChanged: root.dirty = true
                                }
                            }
                            RowLayout {
                                Layout.preferredWidth: replayGainPane.width / replayGainPane.columns

                                Mixxx.SettingParameter {
                                    Layout.fillWidth: true
                                    label: qsTr("Re-analyse and override an existing value")

                                    Text {
                                        anchors.fill: parent
                                        color: Theme.white
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                RatioChoice {
                                    id: replayGainReanalyzeSetting

                                    enabled: replayGainSetting.selected != "off"
                                    inactiveColor: Theme.darkGray4
                                    maxWidth: parent.width * 0.5
                                    objectName: "setting_replayGainReanalyze"
                                    options: ["off", "on"]

                                    onSelectedChanged: root.dirty = true
                                }
                            }
                            ColumnLayout {
                                Layout.preferredWidth: replayGainPane.width / replayGainPane.columns

                                Mixxx.SettingParameter {
                                    Layout.fillWidth: true
                                    label: qsTr("Initial boost without ReplayGain")
                                    keywords: [qsTr("Gain"), qsTr("Unanalysed"), qsTr("Unanalyzed")]

                                    Text {
                                        anchors.fill: parent
                                        color: Theme.white
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                SettingComponents.Slider {
                                    id: replayGainDefaultBoostInput

                                    Layout.preferredWidth: 400
                                    decimals: 0
                                    markers: [-12, -6, 0, 6, 12]
                                    max: 12
                                    min: -12
                                    objectName: "setting_replayGainDefaultBoost"
                                    suffix: qsTr(" dB")
                                    value: -6
                                    wheelStep: 1

                                    onValueChanged: root.dirty = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Item {
        id: buttonActions

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 20

        Skin.FormButton {
            activeColor: "#999999"
            anchors.left: parent.left
            backgroundColor: "#7D3B3B"
            objectName: "analyzerResetButton"
            opacity: enabled ? 1.0 : 0.5
            text: qsTr("Reset")

            onPressed: {
                root.reset();
            }
        }
        Row {
            anchors.right: parent.right
            spacing: 10

            Skin.FormButton {
                activeColor: "#999999"
                backgroundColor: "#3F3F3F"
                objectName: "analyzerCancelButton"
                opacity: enabled ? 1.0 : 0.5
                text: qsTr("Cancel")
                visible: root.dirty

                onPressed: {
                    root.load();
                }
            }
            Skin.FormButton {
                activeColor: "#999999"
                backgroundColor: root.dirty ? "#3a60be" : "#3F3F3F"
                // Weird bug on MacOS - if the button is disabled before the pressed property is clicked, the button remains pressed, leading to a no-op click when it gets next enabled
                enabled: pressed || root.dirty
                objectName: "analyzerSaveButton"
                opacity: enabled ? 1.0 : 0.5
                text: qsTr("Save")

                onPressed: {
                    root.save();
                }
            }
        }
    }
}
