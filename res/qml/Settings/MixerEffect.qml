import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Mixxx 1.0 as Mixxx
import "." as SettingComponents
import ".." as Skin
import "../Theme"

Category {
    id: root

    property bool crossfaderDirty: false
    property bool effectsDirty: false
    property bool equalizersDirty: false
    property bool loading: false
    property int mainEqIndex: 0
    property var mainEqSlot: null
    property bool mainEqUpdating: false
    property var savedDeckEqIds: []
    property var savedDeckQuickPresetNames: []
    property var savedMainEq: null
    property var savedQuickPresetOrder: []
    property var savedStandardPresetOrder: []
    property var savedVisibleEffects: []

    signal mainEqRestored

    function cancelEffects() {
        Mixxx.EffectsManager.setVisibleEffects(savedVisibleEffects);
        Mixxx.EffectsManager.setChainPresetOrder(savedStandardPresetOrder, false);
        Mixxx.EffectsManager.setChainPresetOrder(savedQuickPresetOrder, true);
        loadEffects();
    }
    function cancelEqualizers() {
        const savedMainEqSnapshot = savedMainEq;
        const savedEqIds = savedDeckEqIds;
        const savedQuickNames = savedDeckQuickPresetNames;
        if (savedMainEqSnapshot && mainEqSlot) {
            if (mainEqSlot.effectId !== savedMainEqSnapshot.uniqueId) {
                mainEqSlot.effectId = savedMainEqSnapshot.uniqueId;
            }
            for (const parameterId in savedMainEqSnapshot.values) {
                mainEqSlot.setParameterValue(parameterId, savedMainEqSnapshot.values[parameterId]);
            }
        }
        Mixxx.EffectsManager.applyDeckEqSettings(Mixxx.Config.mixerEqsBypassed, Mixxx.Config.mixerEqsOnly, Mixxx.Config.mixerSingleEq, savedEqIds);
        Mixxx.EffectsManager.applyQuickEffectSettings(quickPresetIndices(savedQuickNames));
        loadEqualizers();
        mainEqUpdating = true;
        mainEqRestored();
        mainEqUpdating = false;
    }
    function deckEqIds() {
        const ids = [];
        for (let i = 0; i < deckSettings.count; ++i) {
            ids.push(deckSettings.get(i).eqUniqueId);
        }
        return ids;
    }
    function deckEqModel() {
        return eqsOnlyInput.selected === "on" ? Mixxx.EffectsManager.mixingEqEffectsModel : Mixxx.EffectsManager.allEffectsModel;
    }
    function deckEqSelectionUniqueId(row) {
        if (singleEqInput.selected === "on" && deckSettings.count > 0) {
            return deckSettings.get(0).eqUniqueId;
        }
        return row.eqUniqueId;
    }
    function deckQuickPresetName(row) {
        if (singleEqInput.selected === "on" && deckSettings.count > 0) {
            return deckSettings.get(0).quickPresetName;
        }
        return row.quickPresetName;
    }
    function deckQuickPresetNames() {
        const names = [];
        const singleEq = singleEqInput.selected === "on";
        for (let i = 0; i < deckSettings.count; ++i) {
            names.push(singleEq && i > 0 ? names[0] : deckSettings.get(i).quickPresetName);
        }
        return names;
    }
    function load() {
        loading = true;
        Mixxx.EffectsManager.migrateLegacyEffectSettings();
        loadCrossfader();
        loadEqualizers();
        loadEffects();
        loading = false;
    }
    function loadCrossfader() {
        xfaderModeInput.selected = xfaderModeInput.options[Mixxx.Config.mixerXfaderMode] ?? xfaderModeInput.options[0];
        xfaderCurveInput.setValue(Mixxx.Config.mixerXfaderSliderPositionFromCurve(Mixxx.Config.mixerXfaderCurve));
        xfaderReverseInput.selected = Mixxx.Config.mixerXfaderReverse ? "on" : "off";
        crossfaderDirty = false;
    }
    function loadDecks() {
        deckSettings.clear();
        for (let deckNumber = 1; deckNumber <= Mixxx.EffectsManager.numDecks(); ++deckNumber) {
            const eqSlot = Mixxx.EffectsManager.getDeckEqEffectSlot(deckNumber);
            const quickSlot = Mixxx.EffectsManager.getDeckQuickEffectSlot(deckNumber);
            deckSettings.append({
                "deckNumber": deckNumber,
                "eqUniqueId": eqSlot?.effectId ?? "",
                "quickPresetName": quickSlot?.chainPresetName ?? "---"
            });
        }
    }
    function loadEffects() {
        savedVisibleEffects = [];
        const visibleModel = Mixxx.EffectsManager.visibleEffectsSettingsModel;
        for (let i = 0; i < visibleModel.rowCount(); ++i) {
            savedVisibleEffects.push(visibleModel.get(i).uniqueId);
        }
        savedStandardPresetOrder = presetNames(Mixxx.EffectsManager.standardChainPresetSettingsModel);
        savedQuickPresetOrder = presetNames(Mixxx.EffectsManager.quickChainPresetSettingsModel);
        adoptMetaknobInput.selected = Mixxx.Config.effectsAdoptMetaknobValue ? "on" : "off";
        effectsDirty = false;
    }
    function loadEqualizers() {
        loading = true;
        eqBypassInput.selected = Mixxx.Config.mixerEqsBypassed ? "on" : "off";
        eqsOnlyInput.selected = Mixxx.Config.mixerEqsOnly ? "on" : "off";
        singleEqInput.selected = Mixxx.Config.mixerSingleEq ? "on" : "off";
        eqAutoResetInput.selected = Mixxx.Config.mixerEqAutoReset ? "on" : "off";
        gainAutoResetInput.selected = Mixxx.Config.mixerGainAutoReset ? "on" : "off";
        stemAutoResetInput.selected = Mixxx.Config.mixerStemAutoReset ? "on" : "off";
        let high = Math.round(Mixxx.Config.mixerHighEqFrequency);
        let low = Math.round(Mixxx.Config.mixerLowEqFrequency);
        if (high === low) {
            high = 2500;
            low = 250;
        }
        highEqInput.value = high;
        lowEqInput.value = low;
        Mixxx.Config.applyMixerEqFrequencies();
        loadDecks();
        savedDeckEqIds = deckEqIds();
        savedDeckQuickPresetNames = deckQuickPresetNames();
        loadMainEq();
        loading = false;
        equalizersDirty = false;
    }
    function loadMainEq() {
        mainEqUpdating = true;
        mainEqSlot = Mixxx.EffectsManager.getMainEqEffectSlot();
        const model = Mixxx.EffectsManager.mainEqEffectsModel;
        const row = model.rowForUniqueId(mainEqSlot?.effectId ?? "");
        mainEqIndex = row >= 0 ? row : 0;
        const values = ({});
        if (mainEqSlot) {
            const parameters = mainEqSlot.parametersModel;
            for (let i = 0; i < parameters.rowCount(); ++i) {
                const parameter = parameters.get(i);
                if (parameter.loaded) {
                    values[parameter.parameterId] = mainEqSlot.getParameterValue(parameter.parameterId);
                }
            }
        }
        savedMainEq = {
            "uniqueId": mainEqSlot?.effectId ?? "",
            "values": values
        };
        mainEqUpdating = false;
    }
    function openExportDialog(model, row) {
        if (row < 0) {
            return;
        }
        exportFileDialog.targetModel = model;
        exportFileDialog.targetRow = row;
        exportFileDialog.open();
    }
    function openImportDialog(model) {
        importFileDialog.targetModel = model;
        importFileDialog.open();
    }
    function openRenameDialog(model, row) {
        if (row < 0) {
            return;
        }
        renamePresetDialog.targetModel = model;
        renamePresetDialog.targetRow = row;
        renamePresetDialog.presetName = model.get(row).name;
        renamePresetDialog.open();
    }
    function presetNames(model) {
        const names = [];
        for (let i = 0; i < model.rowCount(); ++i) {
            names.push(model.get(i).name);
        }
        return names;
    }
    function quickPresetIndex(name) {
        const model = Mixxx.EffectsManager.quickChainPresetModel;
        for (let i = 0; i < model.rowCount(); ++i) {
            if (model.get(i).name === name) {
                return i;
            }
        }
        return 0;
    }
    function quickPresetIndices(names) {
        const indices = [];
        for (const name of names) {
            indices.push(quickPresetIndex(name));
        }
        return indices;
    }
    function resetCrossfader() {
        xfaderModeInput.selected = xfaderModeInput.options[0];
        xfaderCurveInput.setValue(Mixxx.Config.mixerXfaderSliderPositionFromCurve(1.0));
        xfaderReverseInput.selected = "off";
        crossfaderDirty = true;
    }
    function resetEffects() {
        adoptMetaknobInput.selected = "on";
        Mixxx.EffectsManager.standardChainPresetSettingsModel.resetToDefaults();
        Mixxx.EffectsManager.quickChainPresetSettingsModel.resetToDefaults();
        effectsDirty = true;
    }
    function resetEqualizers() {
        eqBypassInput.selected = "off";
        eqsOnlyInput.selected = "on";
        singleEqInput.selected = "on";
        eqAutoResetInput.selected = "off";
        gainAutoResetInput.selected = "off";
        stemAutoResetInput.selected = "on";
        highEqInput.value = 2500;
        lowEqInput.value = 250;
        Mixxx.EffectsManager.loadDefaultEqsAndQuickEffects();
        loadDecks();
        if (mainEqSlot) {
            mainEqSlot.effectId = "";
        }
        mainEqIndex = 0;
        equalizersDirty = true;
    }
    function saveCrossfader() {
        Mixxx.Config.mixerXfaderMode = xfaderModeInput.options.indexOf(xfaderModeInput.selected);
        Mixxx.Config.mixerXfaderCurve = Mixxx.Config.mixerXfaderCurveFromSliderPosition(xfaderCurveInput.value);
        Mixxx.Config.mixerXfaderReverse = xfaderReverseInput.selected === "on";
        Mixxx.Config.applyMixerXfaderSettings();
        loadCrossfader();
    }
    function saveEffects() {
        Mixxx.Config.effectsAdoptMetaknobValue = adoptMetaknobInput.selected === "on";
        loadEffects();
    }
    function saveEqualizers() {
        Mixxx.Config.mixerEqsBypassed = eqBypassInput.selected === "on";
        Mixxx.Config.mixerEqsOnly = eqsOnlyInput.selected === "on";
        Mixxx.Config.mixerSingleEq = singleEqInput.selected === "on";
        Mixxx.Config.mixerEqAutoReset = eqAutoResetInput.selected === "on";
        Mixxx.Config.mixerGainAutoReset = gainAutoResetInput.selected === "on";
        Mixxx.Config.mixerStemAutoReset = stemAutoResetInput.selected === "on";
        Mixxx.Config.mixerHighEqFrequency = highEqInput.value;
        Mixxx.Config.mixerLowEqFrequency = lowEqInput.value;
        Mixxx.Config.applyMixerEqFrequencies();
        Mixxx.EffectsManager.applyDeckEqSettings(Mixxx.Config.mixerEqsBypassed, Mixxx.Config.mixerEqsOnly, Mixxx.Config.mixerSingleEq, deckEqIds());
        Mixxx.EffectsManager.applyQuickEffectSettings(quickPresetIndices(deckQuickPresetNames()));
        loadEqualizers();
    }

    label: qsTr("Mixer & Effects")
    objectName: "mixerEffectPage"
    selectedIndex: 0
    tabs: [qsTr("crossfader"), qsTr("equalizers"), qsTr("effects")]

    Component.onCompleted: root.load()

    ListModel {
        id: deckSettings

    }
    FileDialog {
        id: importFileDialog

        property var targetModel

        fileMode: FileDialog.OpenFiles
        nameFilters: [qsTr("Mixxx Effect Chain Presets") + " (*.xml)"]
        title: qsTr("Import effect chain preset")

        onAccepted: {
            if (targetModel) {
                const paths = [];
                for (let i = 0; i < selectedFiles.length; ++i) {
                    paths.push(selectedFiles[i].toString());
                }
                targetModel.importPresets(paths);
            }
        }
    }
    FileDialog {
        id: exportFileDialog

        property var targetModel
        property int targetRow: -1

        defaultSuffix: "xml"
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("Mixxx Effect Chain Presets") + " (*.xml)"]
        title: qsTr("Export effect chain preset")

        onAccepted: {
            if (targetModel && targetRow >= 0) {
                targetModel.exportPresetToFile(targetRow, selectedFile.toString());
            }
        }
    }
    Dialog {
        id: renamePresetDialog

        property string presetName: ""
        property var targetModel
        property int targetRow: -1

        anchors.centerIn: parent
        modal: true
        title: qsTr("Rename effect chain preset")
        width: 360

        contentItem: ColumnLayout {
            Text {
                Layout.fillWidth: true
                color: Theme.white
                text: qsTr("New name for effect chain preset")
                wrapMode: Text.WordWrap
            }
            TextField {
                id: renamePresetTextField

                Layout.fillWidth: true
                text: renamePresetDialog.presetName
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight

                Skin.FormButton {
                    text: qsTr("Cancel")

                    onPressed: renamePresetDialog.close()
                }
                Skin.FormButton {
                    text: qsTr("Rename")

                    onPressed: {
                        if (renamePresetDialog.targetModel && renamePresetDialog.targetRow >= 0) {
                            renamePresetDialog.targetModel.renamePreset(renamePresetDialog.targetRow, renamePresetTextField.text);
                        }
                        renamePresetDialog.close();
                    }
                }
            }
        }

        onOpened: renamePresetTextField.forceActiveFocus()
    }
    ScrollView {
        id: scrollView

        anchors.bottom: buttonActions.top
        anchors.bottomMargin: 18
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        ScrollBar.vertical: ScrollBar {
            id: mixerEffectSettingsScrollBar

            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.top: parent.top
            policy: ScrollBar.AsNeeded
        }

        Item {
            implicitHeight: [crossfaderTab.implicitHeight, equalizersTab.implicitHeight, effectsTab.implicitHeight][root.selectedIndex]
            implicitWidth: scrollView.width

            Mixxx.SettingGroup {
                id: crossfaderTab

                implicitHeight: crossfaderColumn.y + crossfaderColumn.height
                label: qsTr("Crossfader")
                visible: root.selectedIndex === 0
                width: scrollView.width

                ColumnLayout {
                    id: crossfaderColumn

                    spacing: 16
                    width: parent.width
                    y: 20

                    RowLayout {
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        spacing: 20

                        Mixxx.SettingParameter {
                            Layout.fillWidth: true
                            label: qsTr("Crossfader mode")

                            Text {
                                anchors.fill: parent
                                color: Theme.white
                                font.pixelSize: 14
                                text: parent.label
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        SettingComponents.RatioChoice {
                            id: xfaderModeInput

                            Layout.preferredWidth: 280
                            options: [qsTr("Additive"), qsTr("Constant Power")]

                            onSelectedChanged: {
                                if (!root.loading)
                                    root.crossfaderDirty = true;
                            }
                        }
                    }
                    RowLayout {
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        spacing: 20

                        Mixxx.SettingParameter {
                            Layout.fillWidth: true
                            label: qsTr("Crossfader curve")

                            Text {
                                anchors.fill: parent
                                color: Theme.white
                                font.pixelSize: 14
                                text: parent.label
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        SettingComponents.Slider {
                            id: xfaderCurveInput

                            Layout.preferredWidth: 420
                            max: 100
                            min: 0

                            onValueChanged: {
                                if (!root.loading)
                                    root.crossfaderDirty = true;
                            }
                        }
                    }
                    RowLayout {
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        spacing: 20

                        Mixxx.SettingParameter {
                            Layout.fillWidth: true
                            label: qsTr("Reverse crossfader")

                            Text {
                                anchors.fill: parent
                                color: Theme.white
                                font.pixelSize: 14
                                text: parent.label
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        SettingComponents.RatioChoice {
                            id: xfaderReverseInput

                            options: ["off", "on"]

                            onSelectedChanged: {
                                if (!root.loading)
                                    root.crossfaderDirty = true;
                            }
                        }
                    }
                    Canvas {
                        id: xfaderPreview

                        readonly property real curve: Mixxx.Config.mixerXfaderCurveFromSliderPosition(xfaderCurveInput.value)
                        readonly property int mode: xfaderModeInput.selected === xfaderModeInput.options[1] ? 1 : 0
                        readonly property bool reverse: xfaderReverseInput.selected === "on"

                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.preferredHeight: 140
                        Layout.rightMargin: 14

                        onCurveChanged: requestPaint()
                        onModeChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            const calibration = Math.pow(0.5, 1.0 / curve);
                            const width = xfaderPreview.width;
                            const height = xfaderPreview.height;
                            ctx.reset();
                            ctx.fillStyle = Theme.darkGray2;
                            ctx.fillRect(0, 0, width, height);
                            ctx.strokeStyle = Theme.midGray3;
                            ctx.lineWidth = 1;
                            for (let i = 1; i < 5; ++i) {
                                ctx.beginPath();
                                ctx.moveTo(width * i / 5, 0);
                                ctx.lineTo(width * i / 5, height);
                                ctx.stroke();
                            }
                            for (let i = 1; i < 4; ++i) {
                                ctx.beginPath();
                                ctx.moveTo(0, height * i / 4);
                                ctx.lineTo(width, height * i / 4);
                                ctx.stroke();
                            }
                            const curvePath = function (gainFunction, color, lineWidth) {
                                ctx.beginPath();
                                for (let x = 0; x <= width; ++x) {
                                    const position = -1.0 + 2.0 * x / width;
                                    const gains = gainFunction(position);
                                    const y = height - Math.min(1.0, gains) * (height - 4) - 2;
                                    if (x === 0) {
                                        ctx.moveTo(x, y);
                                    } else {
                                        ctx.lineTo(x, y);
                                    }
                                }
                                ctx.strokeStyle = color;
                                ctx.lineWidth = lineWidth;
                                ctx.stroke();
                            };
                            const gainsAt = function (position) {
                                let xfadePosition = position;
                                let left = position;
                                let right = position;
                                if (mode === 1) {
                                    xfadePosition *= calibration;
                                    left = xfadePosition - calibration;
                                    right = xfadePosition + calibration;
                                }
                                let gain1 = 1.0;
                                let gain2 = 1.0;
                                if (left < 0) {
                                    gain2 = 1.0 - Math.pow(Math.abs(left), curve);
                                }
                                if (right > 0) {
                                    gain1 = 1.0 - Math.pow(right, curve);
                                }
                                gain1 = Math.max(0.0, gain1);
                                gain2 = Math.max(0.0, gain2);
                                if (mode === 1) {
                                    if (gain1 > gain2) {
                                        gain2 = 1.0 - gain1;
                                    } else {
                                        gain1 = 1.0 - gain2;
                                    }
                                    const gain = Math.sqrt(gain1 * gain1 + gain2 * gain2);
                                    if (gain > 0) {
                                        gain1 /= gain;
                                        gain2 /= gain;
                                    }
                                }
                                if (reverse) {
                                    return [gain2, gain1];
                                }
                                return [gain1, gain2];
                            };
                            curvePath(position => gainsAt(position)[0], Theme.accentColor, 2);
                            curvePath(position => gainsAt(position)[1], Theme.effectColor, 2);
                            curvePath(position => {
                                const gains = gainsAt(position);
                                return Math.sqrt(gains[0] * gains[0] + gains[1] * gains[1]);
                            }, Theme.white, 2);
                        }
                        onReverseChanged: requestPaint()
                    }
                }
            }
            Mixxx.SettingGroup {
                id: equalizersTab

                // implicitHeight: equalizersColumn.y + equalizersColumn.height + frequenciesColumn.height
                label: qsTr("Equalizers")
                visible: root.selectedIndex === 1
                width: scrollView.width

                ColumnLayout {
                    spacing: 20
                    width: equalizersTab.width - 10

                    GridLayout {
                        id: equalizersColumn

                        columnSpacing: 14
                        columns: 2
                        width: parent.width
                        y: 20

                        RowLayout {
                            spacing: 20

                            Mixxx.SettingParameter {
                                Layout.fillWidth: true
                                label: qsTr("Bypass EQ")

                                Text {
                                    anchors.fill: parent
                                    color: Theme.white
                                    font.pixelSize: 14
                                    text: parent.label
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            SettingComponents.RatioChoice {
                                id: eqBypassInput

                                options: ["off", "on"]

                                onSelectedChanged: {
                                    if (!root.loading)
                                        root.equalizersDirty = true;
                                }
                            }
                        }
                        RowLayout {
                            spacing: 20

                            Mixxx.SettingParameter {
                                Layout.fillWidth: true
                                label: qsTr("EQ effects only")

                                Text {
                                    anchors.fill: parent
                                    color: Theme.white
                                    font.pixelSize: 14
                                    text: parent.label
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            SettingComponents.RatioChoice {
                                id: eqsOnlyInput

                                options: ["off", "on"]

                                onSelectedChanged: {
                                    if (!root.loading)
                                        root.equalizersDirty = true;
                                }
                            }
                        }
                        RowLayout {
                            spacing: 20

                            Mixxx.SettingParameter {
                                Layout.fillWidth: true
                                label: qsTr("Single EQ effect")

                                Text {
                                    anchors.fill: parent
                                    color: Theme.white
                                    font.pixelSize: 14
                                    text: parent.label
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            SettingComponents.RatioChoice {
                                id: singleEqInput

                                options: ["off", "on"]

                                onSelectedChanged: {
                                    if (!root.loading)
                                        root.equalizersDirty = true;
                                }
                            }
                        }
                    }
                    // Mixxx.SettingGroup {
                    //     Layout.fillWidth: true
                    //     label: qsTr("Main EQ")

                    // ColumnLayout {
                    //     spacing: 8
                    //     width: parent.width

                    RowLayout {
                        spacing: 10
                        width: parent.width

                        Text {
                            Layout.preferredWidth: 100
                            color: Theme.white
                            font.pixelSize: 13
                            text: qsTr("Main EQ")
                        }
                        Skin.ComboBox {
                            id: mainEqCombo

                            Layout.fillWidth: true
                            currentIndex: root.mainEqIndex
                            model: Mixxx.EffectsManager.mainEqEffectsModel
                            textRole: "display"

                            onActivated: idx => {
                                root.mainEqIndex = idx;
                                if (root.mainEqSlot) {
                                    root.mainEqSlot.effectId = model.get(idx).uniqueId;
                                }
                                root.equalizersDirty = true;
                            }
                        }
                        Skin.FormButton {
                            id: mixerEffectMainEqResetButton

                            text: qsTr("Reset")

                            onPressed: {
                                if (root.mainEqSlot) {
                                    root.mainEqSlot.effectId = "";
                                }
                                root.mainEqIndex = 0;
                                root.equalizersDirty = true;
                            }
                        }
                    }
                    RowLayout {
                        implicitHeight: 500
                        width: parent.width

                        Repeater {
                            id: mainEqParameterRepeater

                            model: root.mainEqSlot ? root.mainEqSlot.parametersModel : null

                            ColumnLayout {
                                required property real defaultValue
                                required property bool loaded
                                required property real maximum
                                required property real minimum
                                required property string name
                                required property string parameterId

                                Layout.fillHeight: true
                                Layout.fillWidth: true
                                spacing: 10
                                visible: loaded

                                Text {
                                    // Layout.preferredWidth: 130
                                    Layout.fillWidth: true
                                    color: Theme.white
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    text: name
                                }
                                SettingComponents.Slider {
                                    id: mainEqParameterSlider

                                    property bool initializing: true

                                    Layout.fillHeight: true
                                    Layout.fillWidth: true
                                    decimals: maximum - minimum > 100 ? 0 : 2
                                    margins: 0
                                    markers: [-12, 0, 12]
                                    max: maximum
                                    min: minimum
                                    objectName: "mixerEffectMainEqParameter_" + parameterId
                                    slider.orientation: Qt.Vertical
                                    suffix: "dB"

                                    Component.onCompleted: {
                                        mainEqParameterSlider.setValue(root.mainEqSlot ? root.mainEqSlot.getParameterValue(parameterId) : defaultValue);
                                        mainEqParameterSlider.initializing = false;
                                    }
                                    onValueChanged: {
                                        if (!initializing && !root.mainEqUpdating && !root.loading && root.mainEqSlot) {
                                            root.mainEqSlot.setParameterValue(parameterId, value);
                                            root.equalizersDirty = true;
                                        }
                                    }

                                    Connections {
                                        function onMainEqRestored() {
                                            mainEqParameterSlider.setValue(root.mainEqSlot ? root.mainEqSlot.getParameterValue(parameterId) : defaultValue);
                                        }

                                        target: root
                                    }
                                }
                            }
                        }
                    }
                    // }
                    // }
                    GroupPane {
                        Layout.fillWidth: true
                        label: qsTr("Deck EQs and QuickEffects")

                        Repeater {
                            id: deckRepeater

                            model: deckSettings

                            RowLayout {
                                id: deckRow

                                required property int deckNumber
                                property alias eqCombo: deckEqCombo
                                required property string eqUniqueId
                                required property int index
                                required property string quickPresetName

                                Layout.fillWidth: true
                                spacing: 10

                                Text {
                                    Layout.preferredWidth: 70
                                    color: Theme.white
                                    font.pixelSize: 13
                                    text: qsTr("Deck %1").arg(deckRow.deckNumber)
                                }
                                Skin.ComboBox {
                                    id: deckEqCombo

                                    Layout.fillWidth: true
                                    Layout.horizontalStretchFactor: 3
                                    Layout.preferredWidth: deckRow.width / 2
                                    currentIndex: root.deckEqModel().rowForUniqueId(root.deckEqSelectionUniqueId(deckRow))
                                    enabled: root.eqBypassInput.selected !== "on" && (root.singleEqInput.selected !== "on" || deckRow.deckNumber === 1)
                                    model: root.deckEqModel()
                                    objectName: "mixerEffectDeckEq_" + deckRow.deckNumber
                                    textRole: "display"

                                    onActivated: idx => {
                                        deckSettings.setProperty(deckRow.index, "eqUniqueId", model.get(idx).uniqueId);
                                        root.equalizersDirty = true;
                                    }
                                }
                                Skin.ComboBox {
                                    Layout.fillWidth: true
                                    Layout.horizontalStretchFactor: 1
                                    Layout.preferredWidth: deckRow.width / 3
                                    currentIndex: root.quickPresetIndex(root.deckQuickPresetName(deckRow))
                                    enabled: root.singleEqInput.selected !== "on" || deckRow.deckNumber === 1
                                    model: Mixxx.EffectsManager.quickChainPresetModel
                                    objectName: "mixerEffectDeckQuickEffect_" + deckRow.deckNumber
                                    textRole: "display"

                                    onActivated: idx => {
                                        deckSettings.setProperty(deckRow.index, "quickPresetName", model.get(idx).name);
                                        root.equalizersDirty = true;
                                    }
                                }
                            }
                        }
                    }
                    GroupPane {
                        Layout.fillWidth: true
                        label: "Deck onload behavior"

                        GridLayout {
                            columns: 2

                            RowLayout {
                                spacing: 20

                                Mixxx.SettingParameter {
                                    Layout.fillWidth: true
                                    label: qsTr("EQ auto reset")

                                    Text {
                                        anchors.fill: parent
                                        color: Theme.white
                                        font.pixelSize: 14
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                SettingComponents.RatioChoice {
                                    id: eqAutoResetInput

                                    options: ["off", "on"]

                                    onSelectedChanged: {
                                        if (!root.loading)
                                            root.equalizersDirty = true;
                                    }
                                }
                            }
                            RowLayout {
                                spacing: 20

                                Mixxx.SettingParameter {
                                    Layout.fillWidth: true
                                    label: qsTr("Gain auto reset")

                                    Text {
                                        anchors.fill: parent
                                        color: Theme.white
                                        font.pixelSize: 14
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                SettingComponents.RatioChoice {
                                    id: gainAutoResetInput

                                    options: ["off", "on"]

                                    onSelectedChanged: {
                                        if (!root.loading)
                                            root.equalizersDirty = true;
                                    }
                                }
                            }
                            RowLayout {
                                spacing: 20
                                visible: Mixxx.Config.mixerStemSupported

                                Mixxx.SettingParameter {
                                    Layout.fillWidth: true
                                    label: qsTr("Stem auto reset")

                                    Text {
                                        anchors.fill: parent
                                        color: Theme.white
                                        font.pixelSize: 14
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                SettingComponents.RatioChoice {
                                    id: stemAutoResetInput

                                    options: ["off", "on"]

                                    onSelectedChanged: {
                                        if (!root.loading)
                                            root.equalizersDirty = true;
                                    }
                                }
                            }
                        }
                    }
                    GroupPane {
                        Layout.fillWidth: true
                        label: "Equalizer frequencies shelves"

                        Mixxx.SettingParameter {
                            Layout.fillWidth: true
                            Layout.horizontalStretchFactor: 1
                            Layout.preferredWidth: 100
                            label: qsTr("High EQ shelf")

                            Text {
                                anchors.fill: parent
                                color: Theme.white
                                font.pixelSize: 14
                                text: parent.label
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        SettingComponents.Slider {
                            id: highEqInput

                            Layout.fillWidth: true
                            Layout.horizontalStretchFactor: 2
                            Layout.preferredWidth: 240
                            markers: [16, 1000, 3000, 9000, 20050]
                            max: 20050
                            min: 16
                            suffix: " Hz"
                            value: 2500

                            onValueChanged: {
                                if (!root.loading && lowEqInput.value > highEqInput.value) {
                                    lowEqInput.value = highEqInput.value;
                                }
                                if (!root.loading)
                                    root.equalizersDirty = true;
                            }
                        }
                        Mixxx.SettingParameter {
                            Layout.fillWidth: true
                            label: qsTr("Low EQ shelf")

                            Text {
                                anchors.fill: parent
                                color: Theme.white
                                font.pixelSize: 14
                                text: parent.label
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        SettingComponents.Slider {
                            id: lowEqInput

                            Layout.fillWidth: true
                            Layout.horizontalStretchFactor: 2
                            Layout.preferredWidth: 240
                            markers: [16, 1000, 3000, 9000, 20050]
                            max: 20050
                            min: 16
                            suffix: " Hz"
                            value: 250

                            onValueChanged: {
                                if (!root.loading && highEqInput.value < lowEqInput.value) {
                                    highEqInput.value = lowEqInput.value;
                                }
                                if (!root.loading)
                                    root.equalizersDirty = true;
                            }
                        }
                    }
                }
            }
            Mixxx.SettingGroup {
                id: effectsTab

                implicitHeight: effectsColumn.y + effectsColumn.height
                label: qsTr("Effects")
                visible: root.selectedIndex === 2
                width: scrollView.width

                ColumnLayout {
                    id: effectsColumn

                    spacing: 14
                    width: parent.width
                    y: 20

                    RowLayout {
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        spacing: 20

                        Mixxx.SettingParameter {
                            Layout.fillWidth: true
                            label: qsTr("Adopt metaknob value")

                            Text {
                                anchors.fill: parent
                                color: Theme.white
                                font.pixelSize: 14
                                text: parent.label
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        SettingComponents.RatioChoice {
                            id: adoptMetaknobInput

                            options: ["off", "on"]

                            onSelectedChanged: {
                                if (!root.loading)
                                    root.effectsDirty = true;
                            }
                        }
                    }
                    GroupPane {
                        Layout.fillWidth: true
                        label: "Effects"

                        Mixxx.SettingGroup {
                            label: qsTr("Visible effects")
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.horizontalStretchFactor: 1
                                Layout.preferredWidth: effectsColumn.width / 2
                                spacing: 4

                                Text {
                                    color: Theme.white
                                    font.pixelSize: 13
                                    text: qsTr("Visible effects")
                                }
                                EffectList {
                                    id: visibleEffectsList

                                    Layout.fillHeight: true
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 170
                                    model: Mixxx.EffectsManager.visibleEffectsSettingsModel
                                }
                                RowLayout {
                                    Skin.FormButton {
                                        enabled: visibleEffectsList.currentIndex > 0
                                        text: qsTr("Up")

                                        onPressed: {
                                            const row = visibleEffectsList.currentIndex;
                                            Mixxx.EffectsManager.moveVisibleEffect(row, row - 1);
                                            visibleEffectsList.currentIndex = row - 1;
                                            root.effectsDirty = true;
                                        }
                                    }
                                    Skin.FormButton {
                                        enabled: visibleEffectsList.currentIndex >= 0 && visibleEffectsList.currentIndex < visibleEffectsList.count - 1
                                        text: qsTr("Down")

                                        onPressed: {
                                            const row = visibleEffectsList.currentIndex;
                                            Mixxx.EffectsManager.moveVisibleEffect(row, row + 1);
                                            visibleEffectsList.currentIndex = row + 1;
                                            root.effectsDirty = true;
                                        }
                                    }
                                    Skin.FormButton {
                                        enabled: visibleEffectsList.currentIndex >= 0
                                        opacity: enabled ? 1 : 0.6
                                        text: qsTr("Hide")

                                        onPressed: {
                                            const row = visibleEffectsList.currentIndex;
                                            Mixxx.EffectsManager.setEffectVisible(Mixxx.EffectsManager.visibleEffectsSettingsModel.get(row).uniqueId, false);
                                            visibleEffectsList.currentIndex = Math.min(visibleEffectsList.currentIndex, visibleEffectsList.count - 1);
                                            root.effectsDirty = true;
                                        }
                                    }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.horizontalStretchFactor: 1
                                Layout.preferredWidth: effectsColumn.width / 2
                                spacing: 4

                                Text {
                                    color: Theme.white
                                    font.pixelSize: 13
                                    text: qsTr("Hidden effects")
                                }
                                EffectList {
                                    id: hiddenEffectsList

                                    Layout.fillHeight: true
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 170
                                    model: Mixxx.EffectsManager.hiddenEffectsSettingsModel
                                }
                                Skin.FormButton {
                                    enabled: hiddenEffectsList.currentIndex >= 0
                                    opacity: enabled ? 1 : 0.6
                                    text: qsTr("Show")

                                    onPressed: {
                                        const row = hiddenEffectsList.currentIndex;
                                        Mixxx.EffectsManager.setEffectVisible(Mixxx.EffectsManager.hiddenEffectsSettingsModel.get(row).uniqueId, true);
                                        hiddenEffectsList.currentIndex = Math.min(hiddenEffectsList.currentIndex, hiddenEffectsList.count - 1);

                                        root.effectsDirty = true;
                                    }
                                }
                            }
                        }
                    }
                    RowLayout {
                        GroupPane {
                            Layout.fillWidth: true
                            Layout.horizontalStretchFactor: 1
                            Layout.preferredWidth: parent.width / 2
                            label: qsTr("Effect chain presets")

                            ChainPresetSection {
                                presetModel: Mixxx.EffectsManager.standardChainPresetSettingsModel
                            }
                        }
                        GroupPane {
                            Layout.fillWidth: true
                            Layout.horizontalStretchFactor: 1
                            Layout.preferredWidth: parent.width / 2
                            label: qsTr("QuickEffect chain presets")

                            ChainPresetSection {
                                Layout.fillWidth: true
                                presetModel: Mixxx.EffectsManager.quickChainPresetSettingsModel
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
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 14
        height: 20

        Skin.FormButton {
            id: mixerEffectResetButton

            activeColor: "#999999"
            anchors.left: parent.left
            backgroundColor: "#7D3B3B"
            opacity: enabled ? 1.0 : 0.5
            text: qsTr("Reset")

            onPressed: {
                switch (root.selectedIndex) {
                case 0:
                    root.resetCrossfader();
                    break;
                case 1:
                    root.resetEqualizers();
                    break;
                case 2:
                    root.resetEffects();
                    break;
                }
            }
        }
        Row {
            readonly property bool hasChanges: root.selectedIndex === 0 && root.crossfaderDirty || root.selectedIndex === 1 && root.equalizersDirty || root.selectedIndex === 2 && root.effectsDirty

            anchors.right: parent.right
            spacing: 10

            Skin.FormButton {
                id: mixerEffectCancelButton

                activeColor: "#999999"
                backgroundColor: "#3F3F3F"
                enabled: pressed || parent.hasChanges
                opacity: enabled ? 1.0 : 0.5
                text: qsTr("Cancel")

                onPressed: {
                    switch (root.selectedIndex) {
                    case 0:
                        root.loadCrossfader();
                        break;
                    case 1:
                        root.cancelEqualizers();
                        break;
                    case 2:
                        root.cancelEffects();
                        break;
                    }
                }
            }
            Skin.FormButton {
                id: mixerEffectSaveButton

                activeColor: "#999999"
                backgroundColor: enabled ? "#3a60be" : "#3F3F3F"
                enabled: pressed || parent.hasChanges
                opacity: enabled ? 1.0 : 0.5
                text: qsTr("Save")

                onPressed: {
                    switch (root.selectedIndex) {
                    case 0:
                        root.saveCrossfader();
                        break;
                    case 1:
                        root.saveEqualizers();
                        break;
                    case 2:
                        root.saveEffects();
                        break;
                    }
                }
            }
        }
    }

    component ChainPresetSection: GridLayout {
        id: presetSection

        required property var presetModel

        columnSpacing: 4
        columns: 2

        Rectangle {
            Layout.fillWidth: true
            color: Theme.darkGray2
            implicitHeight: 140

            ListView {
                id: presetList

                anchors.fill: parent
                clip: true
                model: presetSection.presetModel

                delegate: Rectangle {
                    required property int index
                    required property string name

                    color: ListView.isCurrentItem ? Theme.accentColor : "transparent"
                    height: 24
                    width: ListView.view.width

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        color: Theme.white
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        text: name
                        verticalAlignment: Text.AlignVCenter
                    }
                    TapHandler {
                        onTapped: presetList.currentIndex = index
                    }
                }
            }
        }
        ColumnLayout {
            Skin.FormButton {
                enabled: presetList.currentIndex > 0
                text: qsTr("Up")

                onPressed: {
                    const row = presetList.currentIndex;
                    presetSection.presetModel.movePreset(row, row - 1);
                    presetList.currentIndex = row - 1;
                    root.effectsDirty = true;
                }
            }
            Skin.FormButton {
                enabled: presetList.currentIndex >= 0 && presetList.currentIndex < presetList.count - 1
                text: qsTr("Down")

                onPressed: {
                    const row = presetList.currentIndex;
                    presetSection.presetModel.movePreset(row, row + 1);
                    presetList.currentIndex = row + 1;
                    root.effectsDirty = true;
                }
            }
            Skin.FormButton {
                text: qsTr("Import")

                onPressed: root.openImportDialog(presetSection.presetModel)
            }
            Skin.FormButton {
                enabled: presetList.currentIndex >= 0
                text: qsTr("Export")

                onPressed: root.openExportDialog(presetSection.presetModel, presetList.currentIndex)
            }
            Skin.FormButton {
                enabled: presetList.currentIndex >= 0
                text: qsTr("Rename")

                onPressed: root.openRenameDialog(presetSection.presetModel, presetList.currentIndex)
            }
            Skin.FormButton {
                enabled: presetList.currentIndex >= 0
                text: qsTr("Delete")

                onPressed: {
                    presetSection.presetModel.deletePreset(presetList.currentIndex);
                    presetList.currentIndex = -1;
                    root.effectsDirty = true;
                }
            }
            Skin.FormButton {
                text: qsTr("Reset")

                onPressed: {
                    presetSection.presetModel.resetToDefaults();
                    root.effectsDirty = true;
                }
            }
        }
        Text {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            color: Theme.red
            font.pixelSize: 11
            text: presetSection.presetModel.lastError
            visible: text !== ""
            wrapMode: Text.WordWrap
        }
    }
    component EffectList: Rectangle {
        property alias count: effectsList.count
        property alias currentIndex: effectsList.currentIndex
        required property var model

        color: Theme.darkGray2

        ListView {
            id: effectsList

            anchors.fill: parent
            clip: true
            model: parent.model

            delegate: Rectangle {
                id: delegate

                required property string author
                required property string description
                required property string display
                required property int index
                required property var type
                required property string uniqueId
                required property string version

                color: ListView.isCurrentItem ? Theme.accentColor : "transparent"
                height: 24
                width: ListView.view.width

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    color: Theme.white
                    elide: Text.ElideRight
                    font.pixelSize: 12
                    text: display
                    verticalAlignment: Text.AlignVCenter
                }
                InfoBubble {
                    id: infoBubbleEffect

                    active: effectInfoPopup.opened
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    border.color: active ? Theme.darkGray4 : Theme.white
                    height: parent.height - 5
                    visible: parent.ListView.isCurrentItem
                    width: parent.height - 5

                    onPressed: {
                        if (effectInfoPopup.opened) {
                            effectInfoPopup.close();
                        } else {
                            effectInfoPopup.open();
                            effectInfoPopup.forceActiveFocus(Qt.PopupFocusReason);
                        }
                    }

                    Skin.ActionPopup {
                        id: effectInfoPopup

                        facing: x > 0 ? Skin.ActionPopup.Facing.Left : Skin.ActionPopup.Facing.Right
                        focus: true
                        height: effectInfoColumn.implicitHeight + 20
                        padding: 6
                        width: 300
                        x: {
                            const rect = infoBubbleEffect.mapToItem(root, width, height);
                            print(rect);
                            if (rect.x > root.width) {
                                return -width;
                            }
                            return infoBubbleEffect.width;
                        }
                        y: infoBubbleEffect.height / 2 - effectInfoPopup.height / 2

                        GridLayout {
                            id: effectInfoColumn

                            columnSpacing: 20
                            columns: 2

                            Text {
                                Layout.fillWidth: true
                                Layout.horizontalStretchFactor: 1
                                Layout.preferredWidth: implicitWidth
                                color: Theme.white
                                font.pixelSize: 12
                                text: "Name"
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.horizontalStretchFactor: 3
                                Layout.preferredWidth: implicitWidth
                                color: Theme.white
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight
                                text: delegate.display
                                wrapMode: Text.Wrap
                            }
                            Text {
                                Layout.alignment: Qt.AlignLeft
                                Layout.fillWidth: true
                                Layout.horizontalStretchFactor: 1
                                Layout.preferredWidth: implicitWidth
                                color: Theme.white
                                font.pixelSize: 12
                                text: "Version"
                            }
                            Text {
                                Layout.alignment: Qt.AlignRight
                                Layout.fillWidth: true
                                Layout.horizontalStretchFactor: 3
                                color: Theme.white
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight
                                text: delegate.version
                                wrapMode: Text.Wrap
                            }
                            Text {
                                Layout.alignment: Qt.AlignLeft
                                Layout.fillWidth: true
                                Layout.horizontalStretchFactor: 1
                                Layout.preferredWidth: implicitWidth
                                color: Theme.white
                                font.pixelSize: 12
                                text: "Author"
                            }
                            Text {
                                Layout.alignment: Qt.AlignRight
                                Layout.fillWidth: true
                                Layout.horizontalStretchFactor: 3
                                color: Theme.white
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight
                                text: delegate.author
                                wrapMode: Text.Wrap
                            }
                            Text {
                                Layout.alignment: Qt.AlignLeft
                                Layout.fillWidth: true
                                Layout.horizontalStretchFactor: 1
                                Layout.preferredWidth: implicitWidth
                                color: Theme.white
                                font.pixelSize: 12
                                text: "Type"
                            }
                            Text {
                                Layout.alignment: Qt.AlignRight
                                Layout.fillWidth: true
                                Layout.horizontalStretchFactor: 3
                                color: Theme.white
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight
                                text: {
                                    print("effecttype", delegate.type);
                                    switch (delegate.type) {
                                    case Mixxx.EffectManifestModel.BackendType.BuiltIn:
                                        return "Built-in";
                                    case Mixxx.EffectManifestModel.BackendType.AudioUnit:
                                        return "Audio Unit";
                                    case Mixxx.EffectManifestModel.BackendType.LV2:
                                        return "LV2";
                                    case Mixxx.EffectManifestModel.BackendType.Unknown:
                                        return "Unknown";
                                    }
                                    console.warning("Unsupported effect backend type:", delegate.type);
                                    return "N/A";
                                }
                                wrapMode: Text.Wrap
                            }
                            Text {
                                Layout.alignment: Qt.AlignLeft
                                Layout.fillWidth: true
                                Layout.horizontalStretchFactor: 1
                                Layout.preferredWidth: implicitWidth
                                color: Theme.white
                                font.pixelSize: 12
                                text: "Description"
                            }
                            Text {
                                Layout.alignment: Qt.AlignRight
                                Layout.fillWidth: true
                                Layout.horizontalStretchFactor: 3
                                color: Theme.white
                                font.pixelSize: 12
                                horizontalAlignment: lineCount > 1 ? Text.AlignJustify : Text.AlignRight
                                text: delegate.description
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
                TapHandler {
                    onTapped: effectsList.currentIndex = index
                }
            }
        }
    }
    component GroupPane: Column {
        default property alias children: paneColumn.children
        required property string label

        spacing: 10

        Text {
            color: Theme.white
            font.pixelSize: 16
            font.weight: Font.DemiBold
            text: label
        }
        Mixxx.SettingGroup {
            label: parent.label
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            color: Qt.alpha('#676767', 0.21)
            implicitHeight: paneColumn.implicitHeight + 20

            ColumnLayout {
                id: paneColumn

                anchors.bottomMargin: 10
                anchors.left: parent.left
                anchors.leftMargin: 25
                anchors.right: parent.right
                anchors.rightMargin: 25
                anchors.top: parent.top
                anchors.topMargin: 10
                spacing: 14
                y: 20
            }
        }
    }
}
