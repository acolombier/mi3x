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
        bpmAnalyzer.detection.selected = Mixxx.Config.bpmDetectionEnabled ? "on" : "off";
        bpmAnalyzer.plugin.selected = Mixxx.Config.bpmAnalyserPluginId == "mixxxbpmdetection" ? "soundtouch" : "queenmary";
        bpmFixedTempoSetting.selected = Mixxx.Config.bpmFixedTempoAssumption ? "on" : "off";
        // Fast analysis cannot be combined with non-constant tempo
        // beatgrids (see DlgPrefBeats::updateGui).
        bpmFastAnalysisSetting.selected = (Mixxx.Config.bpmFastAnalysis && Mixxx.Config.bpmFixedTempoAssumption) ? "on" : "off";
        bpmReanalyzeSetting.selected = Mixxx.Config.bpmReanalyzeWhenSettingsChange ? "on" : "off";
        bpmReanalyzeImportedSetting.selected = Mixxx.Config.bpmReanalyzeImported ? "on" : "off";

        keyAnalyzer.detection.selected = Mixxx.Config.keyDetectionEnabled ? "on" : "off";
        keyAnalyzer.plugin.selected = Mixxx.Config.keyAnalyserPluginId == "keyfinder:2" ? "keyfinder" : "queenmary";
        keyFastAnalysisSetting.selected = Mixxx.Config.keyFastAnalysis ? "on" : "off";
        keyReanalyzeSetting.selected = Mixxx.Config.keyReanalyzeWhenSettingsChange ? "on" : "off";
        keyNotationSetting.selected = ({
                "Lancelot": "lancelot",
                "Lancelot/Traditional": "lancelot",
                "OpenKey": "openkey",
                "OpenKey/Traditional": "openkey",
                "Traditional": "traditional",
                "Custom": "custom"
            })[Mixxx.Config.keyNotation] ?? "traditional";

        replayGainAnalyzer.detection.selected = Mixxx.Config.replayGainEnabled ? "on" : "off";
        replayGainAnalyzer.plugin.selected = Mixxx.Config.replayGainAnalyserVersion == 1 ? "replaygain10" : "replaygain20";
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
        const bpmEnabled = bpmAnalyzer.detection.selected == "on";
        Mixxx.Config.bpmDetectionEnabled = bpmEnabled;
        Mixxx.Config.bpmAnalyserPluginId = bpmAnalyzer.plugin.selected == "soundtouch" ? "mixxxbpmdetection" : "qm-tempotracker:0";
        const fixedTempo = bpmFixedTempoSetting.selected == "on";
        Mixxx.Config.bpmFixedTempoAssumption = fixedTempo;
        // Fast analysis cannot be combined with non-constant tempo
        // beatgrids (see DlgPrefBeats::slotApply).
        Mixxx.Config.bpmFastAnalysis = bpmEnabled && fixedTempo && bpmFastAnalysisSetting.selected == "on";
        Mixxx.Config.bpmReanalyzeWhenSettingsChange = bpmEnabled && bpmReanalyzeSetting.selected == "on";
        Mixxx.Config.bpmReanalyzeImported = bpmEnabled && bpmReanalyzeImportedSetting.selected == "on";

        const keyEnabled = keyAnalyzer.detection.selected == "on";
        Mixxx.Config.keyDetectionEnabled = keyEnabled;
        Mixxx.Config.keyAnalyserPluginId = keyAnalyzer.plugin.selected == "keyfinder" ? "keyfinder:2" : "qm-keydetector:2";
        Mixxx.Config.keyFastAnalysis = keyEnabled && keyFastAnalysisSetting.selected == "on";
        Mixxx.Config.keyReanalyzeWhenSettingsChange = keyEnabled && keyReanalyzeSetting.selected == "on";
        const notationNames = {
            "lancelot": "Lancelot",
            "openkey": "OpenKey",
            "traditional": "Traditional",
            "custom": "Custom"
        };
        // KeyUtils::KeyNotation: Custom = 1, OpenKey = 2, Lancelot = 3,
        // Traditional = 4. The '[Library],key_notation' ControlObject drives
        // the key sort order of the library tracks (see ColumnCache), keep
        // it in sync with the notation config.
        const notationValues = {
            "lancelot": 3,
            "openkey": 2,
            "traditional": 4,
            "custom": 1
        };
        Mixxx.Config.keyNotation = notationNames[keyNotationSetting.selected];
        keyNotationControl.value = notationValues[keyNotationSetting.selected];

        const replayGainEnabled = replayGainAnalyzer.detection.selected == "on";
        Mixxx.Config.replayGainEnabled = replayGainEnabled;
        Mixxx.Config.replayGainAnalyser = replayGainEnabled;
        Mixxx.Config.replayGainAnalyserVersion = replayGainAnalyzer.plugin.selected == "replaygain10" ? 1 : 2;
        Mixxx.Config.replayGainReanalyze = replayGainEnabled && replayGainReanalyzeSetting.selected == "on";
        Mixxx.Config.replayGainTargetLoudnessAdjust = Math.round(replayGainTargetLoudnessInput.value);
        Mixxx.Config.replayGainDefaultBoost = Math.round(replayGainDefaultBoostInput.value);
        load();
    }

    label: qsTr("Analyzer")

    Component.onCompleted: {
        root.load();
    }

    Mixxx.ControlProxy {
        id: keyNotationControl

        group: "[Library]"
        key: "key_notation"
    }
    ScrollView {
        id: scrollView

        anchors.bottom: buttonActions.top
        anchors.bottomMargin: 18
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        ScrollBar.vertical: ScrollBar {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.top: parent.top
            objectName: "scrollBar"
            policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
            width: root.width - 10

            AnalyzerSection {
                id: bpmAnalyzer

                label: qsTr("BPM and Beat detection")
                objectName: "bpm"
                parameter.keywords: [qsTr("Beat"), qsTr("BPM")]

                plugin {
                    metric.font.pixelSize: 18
                    options: ["queenmary", "soundtouch"]
                    tooltips: [qsTr("Queen Mary Tempo and Beat Tracker"), qsTr("SoundTouch BPM Detector (Legacy)"),]

                    delegate: Component {
                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            color: Theme.white
                            font.capitalization: Font.AllUppercase
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            text: parent.modelData == "queenmary" ? "Queen Mary Tempo and Beat Tracker" : 'SoundTouch BPM Detector<span style="color: #6A6A6A;" size="1">(Legacy)</span>'
                            textFormat: Text.RichText
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.Wrap
                        }
                    }
                }
                ColumnLayout {
                    RowLayout {
                        implicitHeight: bpmFastAnalysisLabel.height
                        width: parent.width

                        Mixxx.SettingParameter {
                            Layout.fillWidth: true
                            Layout.minimumHeight: bpmFastAnalysisLabel.implicitHeight
                            label: qsTr("Fast Analysis")

                            Column {
                                id: bpmFastAnalysisLabel

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
                                    font.italic: true
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
                            enabled: bpmAnalyzer.detection.selected != "off" && bpmAnalyzer.plugin.selected == "queenmary" && bpmFixedTempoSetting.selected == "on"
                            inactiveColor: Theme.darkGray4
                            maxWidth: parent.width * 0.5
                            objectName: "fastAnalysis"
                            options: ["off", "on"]

                            onSelectedChanged: root.dirty = true
                        }
                    }
                }
                RowLayout {
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
                            wrapMode: Text.Wrap
                        }
                    }
                    RatioChoice {
                        id: bpmReanalyzeSetting

                        Layout.minimumWidth: implicitWidth
                        enabled: bpmAnalyzer.detection.selected != "off"
                        inactiveColor: Theme.darkGray4
                        maxWidth: parent.width * 0.5
                        objectName: "reanalyze"
                        options: ["off", "on"]

                        onSelectedChanged: root.dirty = true
                    }
                }
                RowLayout {
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

                        enabled: bpmAnalyzer.detection.selected != "off" && bpmAnalyzer.plugin.selected == "queenmary"
                        inactiveColor: Theme.darkGray4
                        maxWidth: parent.width * 0.5
                        objectName: "fixedTempo"
                        options: ["off", "on"]

                        onSelectedChanged: root.dirty = true
                    }
                }
                RowLayout {
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

                        enabled: bpmAnalyzer.detection.selected != "off"
                        inactiveColor: Theme.darkGray4
                        maxWidth: parent.width * 0.5
                        objectName: "reanalyzeImported"
                        options: ["off", "on"]

                        onSelectedChanged: root.dirty = true
                    }
                }
            }
            AnalyzerSection {
                id: keyAnalyzer

                label: qsTr("Key detection")
                objectName: "key"
                parameter.keywords: [qsTr("Key")]

                plugin {
                    metric.font.pixelSize: 18
                    options: ["queenmary", "keyfinder"]
                    tooltips: [qsTr("Queen Mary Key Detector"), qsTr("KeyFinder"),]

                    delegate: Component {
                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            color: Theme.white
                            font.capitalization: Font.AllUppercase
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            text: parent.modelData == "queenmary" ? "Queen Mary Key Detector" : 'KeyFinder'
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.Wrap
                        }
                    }
                }
                ColumnLayout {
                    RowLayout {
                        width: parent.width

                        Mixxx.SettingParameter {
                            Layout.fillWidth: true
                            Layout.minimumHeight: keyFastAnalysisLabel.implicitHeight
                            label: qsTr("Fast Analysis")

                            Column {
                                id: keyFastAnalysisLabel

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
                                    font.italic: true
                                    font.pixelSize: 11
                                    text: qsTr("Recommended for slow computer, may be less accurate")
                                    width: parent.width
                                }
                            }
                        }
                        RatioChoice {
                            id: keyFastAnalysisSetting

                            enabled: keyAnalyzer.detection.selected != "off"
                            inactiveColor: Theme.darkGray4
                            maxWidth: parent.width * 0.5
                            objectName: "fastAnalysis"
                            options: ["off", "on"]

                            onSelectedChanged: root.dirty = true
                        }
                    }
                }
                RowLayout {
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
                            wrapMode: Text.Wrap
                        }
                    }
                    RatioChoice {
                        id: keyReanalyzeSetting

                        Layout.minimumWidth: implicitWidth
                        enabled: keyAnalyzer.detection.selected != "off"
                        inactiveColor: Theme.darkGray4
                        maxWidth: parent.width * 0.5
                        objectName: "reanalyze"
                        options: ["off", "on"]

                        onSelectedChanged: root.dirty = true
                    }
                }
                RowLayout {
                    Layout.columnSpan: keyAnalyzer.pane.columns
                    Layout.preferredWidth: keyAnalyzer.pane.width

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

                        enabled: keyAnalyzer.detection.selected != "off"
                        inactiveColor: Theme.darkGray4
                        maxWidth: parent.width * 0.65
                        objectName: "notation"
                        options: ["lancelot", "traditional", "openkey", "custom"]

                        onSelectedChanged: root.dirty = true
                    }
                }
            }
            AnalyzerSection {
                id: replayGainAnalyzer

                label: qsTr("ReplayGain Loudness Normalization")
                objectName: "replayGain"
                parameter.keywords: [qsTr("ReplayGain"), qsTr("EBU R128"), qsTr("Loudness")]

                plugin {
                    metric.font.pixelSize: 18
                    options: ["replaygain20", "replaygain10"]
                    tooltips: [qsTr("ReplayGain 2.0 (ITU-R BS.1770)"), qsTr("ReplayGain 1.0"),]

                    delegate: Component {
                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            color: Theme.white
                            font.capitalization: Font.AllUppercase
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            text: parent.modelData == "2" ? "ReplayGain 2.0" : 'ReplayGain 1.0'
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.Wrap
                        }
                    }
                }
                RowLayout {
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
                        text: qsTr("Adjust by: %1%2 dB").arg(replayGainTargetLoudnessInput.value < 0 ? "" : "+").arg(replayGainTargetLoudnessInput.value)
                    }
                    SettingComponents.Slider {
                        id: replayGainTargetLoudnessInput

                        Layout.preferredWidth: 400
                        decimals: 0
                        markers: [-12, -6, 0, 6, 12]
                        max: 12
                        min: -12
                        objectName: "targetLoudness"
                        suffix: qsTr(" dB")
                        value: 0
                        wheelStep: 1

                        onValueChanged: root.dirty = true
                    }
                }
                RowLayout {
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

                        enabled: replayGainAnalyzer.detection.selected != "off"
                        inactiveColor: Theme.darkGray4
                        maxWidth: parent.width * 0.5
                        objectName: "reanalyze"
                        options: ["off", "on"]

                        onSelectedChanged: root.dirty = true
                    }
                }
                RowLayout {
                    Mixxx.SettingParameter {
                        Layout.fillWidth: true
                        keywords: [qsTr("Gain"), qsTr("Unanalysed"), qsTr("Unanalyzed")]
                        label: qsTr("Initial boost without ReplayGain")

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
                        objectName: "defaultBoost"
                        suffix: qsTr(" dB")
                        value: -6
                        wheelStep: 1

                        onValueChanged: root.dirty = true
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
            objectName: "reset"
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
                objectName: "cancel"
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
                objectName: "save"
                opacity: enabled ? 1.0 : 0.5
                text: qsTr("Save")

                onPressed: {
                    root.save();
                }
            }
        }
    }

    component AnalyzerSection: Mixxx.SettingGroup {
        id: analyzer

        default property alias children: analyzerPane.children
        property alias detection: analyzerDetectionSetting
        property alias pane: analyzerPane
        property alias parameter: analyzerSetting
        property alias plugin: analyzerPlugin

        function dumpObjectTree() {
            function toJson(o) {
                const children = [];
                for (let i = 0; i < o.children.length; ++i)
                    children.push(toJson(o.children[i]));
                return {
                    className: o.toString() ?? "Unknown",
                    objectName: o.objectName || "",
                    children: children
                };
            }
            return JSON.stringify(toJson(analyzer), null, 2);
        }

        Layout.bottomMargin: 6
        implicitHeight: analyzerColumn.height
        implicitWidth: scrollView.width

        Column {
            id: analyzerColumn

            anchors.left: parent.left
            anchors.right: parent.right

            RowLayout {
                height: 40
                width: parent.width

                Text {
                    Layout.fillWidth: true
                    color: Theme.white
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    text: analyzer.label
                }
                RatioChoice {
                    id: analyzerDetectionSetting

                    inactiveColor: Theme.darkGray4
                    maxWidth: parent.width * 0.25
                    objectName: "state"
                    options: ["off", "on"]

                    onSelectedChanged: root.dirty = true
                }
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                color: Qt.alpha('#676767', 0.21)
                implicitHeight: analyzerHeader.implicitHeight + analyzerPane.implicitHeight + 40

                // Note: we used two GridLayout, one for the static header, one for the custom content. Attempts were made to use "pragma ListPropertyAssignBehavior: ReplaceIfNotDefault", but even if this was working, this seems to create a strange parenting relationship, where the header element weren't always reachable through the parent tree, making it unstable.
                GridLayout {
                    id: analyzerHeader

                    anchors.bottomMargin: 10
                    anchors.left: parent.left
                    anchors.leftMargin: 25
                    anchors.right: parent.right
                    anchors.rightMargin: 25
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    columnSpacing: 20
                    columns: analyzerColumn.width < 850 ? 1 : 2
                    objectName: "grid"
                    rowSpacing: 15
                    uniformCellWidths: true

                    GridLayout {
                        Layout.columnSpan: analyzerPane.columns
                        Layout.preferredWidth: analyzerPane.width
                        columns: 2
                        uniformCellWidths: true

                        Mixxx.SettingParameter {
                            id: analyzerSetting

                            Layout.fillWidth: true
                            label: qsTr("Analyser")

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
                            id: analyzerPlugin

                            Layout.alignment: Qt.AlignHCenter
                            content.height: 34
                            enabled: analyzerDetectionSetting.selected != "off"
                            inactiveColor: Theme.darkGray4
                            normalizedWidth: true
                            objectName: "plugin"

                            onSelectedChanged: root.dirty = true
                        }
                    }
                }
                GridLayout {
                    id: analyzerPane

                    anchors.bottomMargin: 10
                    anchors.left: parent.left
                    anchors.leftMargin: 25
                    anchors.right: parent.right
                    anchors.rightMargin: 25
                    anchors.top: analyzerHeader.bottom
                    anchors.topMargin: 10
                    columnSpacing: 20
                    columns: analyzerColumn.width < 850 ? 1 : 2
                    objectName: "grid"
                    rowSpacing: 15
                    uniformCellWidths: true
                }
            }
        }
    }
}
