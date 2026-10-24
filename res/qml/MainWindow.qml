import "." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Window 2.12
import Qt5Compat.GraphicalEffects
import "Theme"

Item {
    id: root

    readonly property bool _showLibrary: maximizeLibrary || height - mixer.height >= 400
    readonly property int designHeight: 1008
    readonly property int designWidth: 1792
    property alias editDeck: editDeckButton.checked

    // Used to show click interaction on the Window. Mainly relevant on automated testing
    property bool enableDiagnosticClick: false
    property var focusedDeck: null
    readonly property Item imeFocusItem: Window.activeFocusItem
    // Pull-to-top IME shift: while the soft keyboard is up, lift the
    // content column so the focused editor sits `imeKeyboardMargin` below
    // the window top (desktop: no IME, stays 0). Mapping relative to this
    // root keeps it independent of the shift and its animation.
    readonly property real imeKeyboardMargin: 0
    // Future: let a focused item opt into another policy, e.g.
    // imeShiftPolicy: "none" | "top" | "aboveKeyboard".
    readonly property real imeShift: {
        if (!Qt.inputMethod.visible || !root.imeFocusItem) {
            return 0;
        }
        // The discarded geometric arithmetic registers
        // geometry changes as binding dependencies;
        root.imeFocusItem?.imeLayoutSideEffect;
        return Math.max(0, root.imeFocusItem.mapToItem(root, 0, 0).y - root.imeKeyboardMargin);
    }
    readonly property bool isMobile: Qt.platform.os === "android" || Qt.platform.os === "ios"
    property alias maximizeLibrary: maximizeLibraryButton.checked
    readonly property int numDecks: 4
    readonly property int numPreviewDecks: 1
    readonly property int numSamplers: 16
    readonly property bool show4decks: show4DecksButton.checked && show4DecksButton.visible
    property alias showEffects: showEffectsButton.checked
    property alias showSamplers: showSamplersButton.checked
    readonly property int waveformOverviewTypeRgb: 2

    y: -root.imeShift

    Behavior on y {
        NumberAnimation {
            duration: 150
        }
    }

    // color: Theme.backgroundColor
    // height: isMobile ? Screen.height : designHeight
    // visible: true
    // width: isMobile ? Screen.width : designWidth
    // visibility: Mixxx.Config.configStartInFullscreenKey || isMobile ? Window.FullScreen : Window.Windowed

    Mixxx.ControlProxy {
        group: "[App]"
        key: "num_decks"

        onInitializedChanged: {
            value = root.numDecks;
        }
    }
    Mixxx.ControlProxy {
        group: "[App]"
        key: "num_samplers"

        onInitializedChanged: {
            value = root.numSamplers;
        }
    }
    Mixxx.ControlProxy {
        group: "[App]"
        key: "num_preview_decks"

        onInitializedChanged: {
            value = root.numPreviewDecks;
        }
    }
    Mixxx.ControlProxy {
        group: "[Waveform]"
        key: "WaveformOverviewType"

        onInitializedChanged: {
            value = root.waveformOverviewTypeRgb;
        }
    }
    Column {
        id: content

        anchors.fill: parent

        move: Transition {
            NumberAnimation {
                duration: 150
                properties: "x,y"
            }
        }

        Rectangle {
            id: toolbar

            color: Theme.toolbarBackgroundColor
            height: 36
            radius: 1
            width: parent.width

            RowLayout {
                anchors.fill: parent

                Skin.Button {
                    id: show4DecksButton

                    activeColor: Theme.white
                    checkable: true
                    objectName: "show4DecksButton"
                    text: "4 Decks"
                    visible: root.height > 515
                }
                Skin.Button {
                    id: maximizeLibraryButton

                    activeColor: Theme.white
                    checkable: true
                    objectName: "library"
                    text: "Library"

                    onCheckedChanged: () => {
                        showMaximizedLibrary.value = this.checked;
                    }

                    Mixxx.ControlProxy {
                        id: showMaximizedLibrary

                        group: "[Skin]"
                        key: "show_maximized_library"

                        onValueChanged: () => {
                            maximizeLibraryButton.checked = this.value;
                        }
                    }
                }
                Skin.Button {
                    id: showEffectsButton

                    activeColor: Theme.white
                    checkable: true
                    text: "Effects"
                }
                Skin.Button {
                    id: showAuxButton

                    activeColor: Theme.white
                    checkable: true
                    text: "Aux"
                }
                Skin.Button {
                    id: showSamplersButton

                    activeColor: Theme.white
                    checkable: true
                    text: "Sampler"
                }
                Item {
                    Layout.fillWidth: true
                }
                Skin.Button {
                    id: editDeckButton

                    activeColor: Theme.white
                    checkable: true
                    objectName: "editDeckButton"
                    text: "Edit"
                }
                Skin.Button {
                    id: showDevToolsButton

                    activeColor: Theme.white
                    checkable: true
                    checked: devToolsWindow.visible
                    text: "Develop"

                    onClicked: {
                        if (devToolsWindow.visible)
                            devToolsWindow.close();
                        else
                            devToolsWindow.show();
                    }

                    DeveloperToolsWindow {
                        id: devToolsWindow

                        height: 480
                        width: 640
                    }
                }
                Skin.Button {
                    id: notificationButton

                    activeColor: Theme.white
                    checked: notificationPopup.opened
                    icon.height: 16
                    icon.source: "images/notification_bell.svg"
                    icon.width: 16
                    implicitWidth: implicitHeight
                    objectName: "showPreferencesButton"

                    onClicked: {
                        if (!notificationPopup.opened) {
                            notificationPopup.open();
                        }
                    }

                    Rectangle {
                        id: notificationCounter

                        color: '#2D4EA1'
                        height: width
                        radius: height / 2
                        width: 10
                        x: 3 * parent.width / 4
                        y: parent.height - height
                    }
                    Skin.ActionPopup {
                        id: notificationPopup

                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
                        facing: ActionPopup.Facing.Top
                        focus: true
                        height: Math.min(180, notificationList.contentHeight) + bottomInset + topInset + 20
                        width: 500
                        x: {
                            opened; // Bind to opening
                            let pos = notificationButton.mapToItem(root, 0, 0);
                            return root.width - pos.x - width - 18;
                        }
                        y: notificationButton.height

                        Item {
                            clip: true
                            height: notificationList.contentHeight
                            width: 500

                            ListView {
                                id: notificationList

                                height: contentHeight
                                model: Mixxx.Core.notifications
                                width: parent.width

                                delegate: Item {
                                    required property int index
                                    required property var modelData

                                    height: notificationGrid.height + 5
                                    width: ListView.view.width

                                    GridLayout {
                                        id: notificationGrid

                                        columns: 2
                                        width: parent.width

                                        Item {
                                            Layout.fillHeight: true
                                            Layout.minimumWidth: 60
                                            Layout.rowSpan: 3

                                            Rectangle {
                                                anchors.centerIn: parent
                                                color: Qt.alpha('#FF9A9A', 0.3)
                                                height: width
                                                radius: width / 2
                                                width: 30

                                                Text {
                                                    anchors.fill: parent
                                                    color: '#ffffff'
                                                    font.pixelSize: 24
                                                    font.weight: Font.DemiBold
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: '!'
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                            }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            Layout.minimumHeight: 25
                                            color: '#FFFFFF'
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            text: modelData.text
                                            verticalAlignment: Text.AlignBottom
                                            wrapMode: Text.WrapAnywhere
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            color: '#656565'
                                            font.pixelSize: 13
                                            text: modelData.details
                                            visible: modelData.details.length > 0
                                            wrapMode: Text.WrapAnywhere
                                        }
                                        RowLayout {
                                            Item {
                                                Layout.fillWidth: true
                                            }
                                            Repeater {
                                                model: modelData.buttons

                                                Item {
                                                    required property var modelData

                                                    Layout.preferredHeight: 15
                                                    Layout.preferredWidth: button.implicitWidth
                                                    Layout.rightMargin: 10

                                                    Skin.Button {
                                                        id: button

                                                        activeColor: Theme.white
                                                        text: modelData.label

                                                        onClicked: modelData.invoke()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        color: 'black'
                                        height: 2
                                        visible: index != notificationList.count - 1
                                        width: parent.width
                                    }
                                }
                            }
                        }
                    }
                }
                Skin.Button {
                    id: showPreferencesButton

                    activeColor: Theme.white
                    checked: settingsPopup.opened
                    icon.height: 16
                    icon.source: "images/gear.svg"
                    icon.width: 16
                    implicitWidth: implicitHeight
                    objectName: "showPreferencesButton"

                    onClicked: {
                        if (!settingsPopup.opened) {
                            settingsPopup.open();
                        }
                    }
                    onPressAndHold: {
                        Mixxx.PreferencesDialog.show();
                    }
                }
            }
        }
        SplitView {
            id: splitView

            height: parent.height - y
            orientation: Qt.Vertical
            width: parent.width

            handle: Rectangle {
                id: handleDelegate

                property color handleColor: SplitHandle.pressed || SplitHandle.hovered ? Theme.libraryPanelSplitterHandleActive : Theme.libraryPanelSplitterHandle
                property int handleSize: SplitHandle.pressed || SplitHandle.hovered ? 6 : 3

                clip: true
                color: Theme.libraryPanelSplitterBackground
                implicitHeight: 4
                implicitWidth: 8

                containmentMask: Item {
                    height: 8
                    width: splitView.width
                    x: (handleDelegate.width - width) / 2
                }

                RowLayout {
                    anchors.centerIn: parent

                    Repeater {
                        model: 3

                        Rectangle {
                            color: handleColor
                            height: handleSize
                            radius: handleSize
                            width: handleSize
                        }
                    }
                }
            }

            Item {
                id: waveforms

                SplitView.fillHeight: !_showLibrary
                SplitView.preferredHeight: _showLibrary ? 120 : undefined
                visible: !root.maximizeLibrary

                FadeBehavior on visible {
                    fadeTarget: waveforms
                }

                Loader {
                    id: deck3waveform

                    readonly property string group: "[Channel3]"

                    active: root.show4decks
                    anchors.top: parent.top
                    height: parent.height / 4
                    width: root.width

                    sourceComponent: Component {
                        Skin.WaveformDisplay {
                            group: deck3waveform.group

                            FadeBehavior on visible {
                                fadeTarget: deck3waveform
                            }
                        }
                    }
                }
                Skin.WaveformDisplay {
                    id: deck1waveform

                    anchors.top: root.show4decks ? deck3waveform.bottom : parent.top
                    group: "[Channel1]"
                    height: parent.height / (root.show4decks ? 4 : 2)
                    width: root.width
                }
                Skin.WaveformDisplay {
                    id: deck2waveform

                    anchors.bottom: root.show4decks ? deck4waveform.top : parent.bottom
                    group: "[Channel2]"
                    height: parent.height / (root.show4decks ? 4 : 2)
                    width: root.width
                }
                Loader {
                    id: deck4waveform

                    readonly property string group: "[Channel4]"

                    active: root.show4decks
                    anchors.bottom: parent.bottom
                    height: parent.height / 4
                    width: root.width

                    sourceComponent: Component {
                        Skin.WaveformDisplay {
                            group: deck4waveform.group

                            FadeBehavior on visible {
                                fadeTarget: deck4waveform
                            }
                        }
                    }
                }
                Rectangle {
                    width: 125

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            color: Theme.darkGray
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
                    width: 125

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            color: 'transparent'
                            position: 0
                        }
                        GradientStop {
                            color: Theme.darkGray
                            position: 1
                        }
                    }

                    anchors {
                        bottom: parent.bottom
                        right: parent.right
                        top: parent.top
                    }
                }
            }
            Item {
                SplitView.fillHeight: _showLibrary
                SplitView.maximumHeight: _showLibrary ? undefined : mixer.height
                SplitView.minimumHeight: mixer.height

                Deck {
                    id: deck1

                    editMode: root.editDeck
                    group: "[Channel1]"
                    height: root.maximizeLibrary ? 80 : root.show4decks ? mixer.height / 2 : mixer.height
                    minimized: root.maximizeLibrary
                    objectName: "deck1"
                    width: (parent.width - mixer.width) / 2

                    Behavior on height {
                        SpringAnimation {
                            id: deck1HeightAnimation

                            damping: 0.2
                            duration: 500
                            spring: 2
                        }
                    }
                    states: [
                        State {
                            when: root.maximizeLibrary

                            AnchorChanges {
                                anchors.right: parent.horizontalCenter
                                target: deck1
                            }
                        }
                    ]

                    onToggleFocus: {
                        root.focusedDeck = (root.focusedDeck === deck1) ? null : deck1;
                    }

                    anchors {
                        right: mixer.left
                        top: parent.top
                    }
                }
                Mixer {
                    id: mixer

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    groups: [deck1.group, deck2.group, deck3.group, deck4.group]
                    show4decks: root.show4decks
                    visible: !root.maximizeLibrary

                    Behavior on height {
                        SpringAnimation {
                            id: mixerHeightAnimation

                            damping: 0.2
                            duration: 500
                            spring: 2
                        }
                    }
                    states: [
                        State {
                            when: root.focusedDeck === deck1 && root.width < 1400 && !root.maximizeLibrary

                            AnchorChanges {
                                anchors.horizontalCenter: parent.right
                                target: mixer
                            }
                            PropertyChanges {
                                target: deck1
                                width: root.width - (mixer.width / 2)
                            }
                        },
                        State {
                            when: root.focusedDeck === deck2 && root.width < 1400 && !root.maximizeLibrary

                            AnchorChanges {
                                anchors.horizontalCenter: parent.left
                                target: mixer
                            }
                            PropertyChanges {
                                target: deck2
                                width: root.width - (mixer.width / 2)
                            }
                        },
                        State {
                            when: (!root.focusedDeck || root.width > 1400) && !root.maximizeLibrary

                            AnchorChanges {
                                anchors.horizontalCenter: parent.horizontalCenter
                                target: mixer
                            }
                            PropertyChanges {
                                target: deck1
                                width: (root.width - mixer.width) / 2
                            }
                            PropertyChanges {
                                target: deck2
                                width: (root.width - mixer.width) / 2
                            }
                        },
                        State {
                            when: root.maximizeLibrary

                            AnchorChanges {
                                anchors.horizontalCenter: parent.horizontalCenter
                                target: mixer
                            }
                            PropertyChanges {
                                target: deck1
                                width: root.width / 2
                            }
                            PropertyChanges {
                                target: deck2
                                width: root.width / 2
                            }
                        }
                    ]
                    transitions: Transition {
                        AnchorAnimation {
                            duration: 200
                        }
                    }
                    FadeBehavior on visible {
                        fadeTarget: mixer
                    }
                }
                Deck {
                    id: deck2

                    editMode: root.editDeck
                    group: "[Channel2]"
                    height: root.maximizeLibrary ? 80 : root.show4decks ? mixer.height / 2 : mixer.height
                    minimized: root.maximizeLibrary
                    objectName: "deck2"

                    Behavior on height {
                        SpringAnimation {
                            id: deck2HeightAnimation

                            damping: 0.2
                            duration: 500
                            spring: 2
                        }
                    }
                    states: [
                        State {
                            when: root.maximizeLibrary

                            AnchorChanges {
                                anchors.left: parent.horizontalCenter
                                target: deck2
                            }
                        }
                    ]

                    onToggleFocus: {
                        root.focusedDeck = (root.focusedDeck === deck2) ? null : deck2;
                    }

                    anchors {
                        left: mixer.right
                        right: parent.right
                        top: parent.top
                    }
                }
                Loader {
                    id: deck3

                    readonly property string group: "[Channel3]"

                    active: root.show4decks
                    height: active ? (root.maximizeLibrary ? 80 : mixer.height / 2) : 0
                    objectName: "deck3Loader"

                    Behavior on height {
                        SpringAnimation {
                            id: deck3HeightAnimation

                            damping: 0.2
                            duration: 500
                            spring: 2
                        }
                    }
                    sourceComponent: Component {
                        Deck {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            editMode: root.editDeck
                            group: deck3.group
                            minimized: root.maximizeLibrary
                            objectName: "deck3"
                        }
                    }
                    states: [
                        State {
                            when: root.maximizeLibrary

                            AnchorChanges {
                                anchors.right: parent.horizontalCenter
                                target: deck3
                            }
                        }
                    ]

                    anchors {
                        left: parent.left
                        right: mixer.left
                        top: deck1.bottom
                    }
                }
                Loader {
                    id: deck4

                    readonly property string group: "[Channel4]"

                    active: root.show4decks
                    height: active ? (root.maximizeLibrary ? 80 : mixer.height / 2) : 0
                    objectName: "deck4Loader"

                    Behavior on height {
                        SpringAnimation {
                            id: deck4HeightAnimation

                            damping: 0.2
                            duration: 500
                            spring: 2
                        }
                    }
                    sourceComponent: Component {
                        Deck {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            editMode: root.editDeck
                            group: deck4.group
                            minimized: root.maximizeLibrary
                            objectName: "deck4"
                        }
                    }
                    states: [
                        State {
                            when: root.maximizeLibrary

                            AnchorChanges {
                                anchors.left: parent.horizontalCenter
                                target: deck4
                            }
                        }
                    ]

                    anchors {
                        left: mixer.right
                        right: parent.right
                        top: deck2.bottom
                    }
                }

                // Skin.SamplerRow {
                //     id: samplers
                //     visible: root.showSamplers
                //     width: parent.width

                //     Skin.FadeBehavior on visible {
                //         fadeTarget: samplers
                //     }
                // }
                // Skin.EffectRow {
                //     id: effects
                //     visible: root.showEffects
                //     width: parent.width

                //     Skin.FadeBehavior on visible {
                //         fadeTarget: effects
                //     }
                // }
                Loader {
                    id: library

                    active: true
                    width: parent.width

                    sourceComponent: Component {
                        Skin.Library {
                            anchors.fill: parent
                            objectName: "libraryContent"
                        }
                    }
                    states: [
                        State {
                            when: root.maximizeLibrary && root.show4decks

                            AnchorChanges {
                                anchors.top: deck4.bottom
                                target: library
                            }
                        },
                        State {
                            when: root.maximizeLibrary && !root.show4decks

                            AnchorChanges {
                                anchors.top: deck1.bottom
                                target: library
                            }
                        },
                        State {
                            when: !root.maximizeLibrary && root.height - mixer.height < 400

                            PropertyChanges {
                                target: library
                                visible: false
                            }
                        }
                    ]

                    anchors {
                        bottom: parent.bottom
                        top: mixer.bottom
                    }
                }
            }
        }
    }
    Skin.Settings {
        id: settingsPopup

        enableDiagnosticClick: parent.enableDiagnosticClick
        height: Math.min(840, parent.height)
        modal: true
        width: Math.min(1400, parent.width)
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)

        Overlay.modal: Rectangle {
            id: overlayModal

            readonly property bool hasHardwareAcceleration: Mixxx.Config.useAcceleration
            property real radius: 12

            anchors.fill: parent
            color: Qt.alpha('#00000010', hasHardwareAcceleration ? 1.0 : 0.6)

            Repeater {
                model: hasHardwareAcceleration ? 1 : 0

                GaussianBlur {
                    anchors.fill: overlayModal
                    deviation: 4
                    radius: Math.max(0, overlayModal.radius)
                    samples: 16
                    source: content
                }
            }
        }
    }
}
