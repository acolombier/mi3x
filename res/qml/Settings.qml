import "." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import "Theme"
import "Settings" as Settings

Popup {
    id: popup

    // Used to show click interaction on the Window. Mainly relevant on automated testing
    property bool enableDiagnosticClick: false

    // FIXME change to `final` when supported
    readonly property real smallScreenWidth: 1200

    function focusSection(section) {
        // TODO used by notification hook. need to finish when setting highlight is ready
        print("section passed:", section);
    }

    focus: true
    horizontalPadding: 20
    // Used by notifications to interact with the setting popup
    objectName: "settingsPopup"
    verticalPadding: 20

    background: Rectangle {
        anchors.fill: parent
        color: Theme.darkGray2
        opacity: parent.radius < 0 ? Math.max(0.1, 1 + parent.radius / 8) : 1
        radius: 8

        BusyIndicator {
            anchors.centerIn: parent
            visible: loader.item == null || loader.status != Loader.Ready
        }
    }
    contentItem: Loader {
        id: loader

        active: popup.opened
        anchors.fill: parent
        anchors.margins: 10
        asynchronous: true
        // Used by notifications to interact with the setting popup
        objectName: "settingsLoader"
        sourceComponent: content
        visible: item !== null && status == Loader.Ready

        // Accelerate the load of the setting popup after a specific delay
        Timer {
            id: timeout

            // This delay could be tailored to the platform. FOr example, we could image Mixxx.Core exposing a performance score to help computing this: an old RPI/Android phone could use 2 second async, to ensure no impact of the audio engine, while a modern desktop likely doesn't need more than 250ms.
            interval: 500
            repeat: false
            running: popup.opened

            onRunningChanged: {
                loader.asynchronous = running;
            }
        }
        Component {
            id: content

            Item {
                id: root

                property var activeCategory: null
                property alias activeCategoryIndex: categoryList.currentIndex
                readonly property var manager: managerItem
                property alias sections: managerItem.data

                function updateActiveCategory() {
                    root.activeCategory?.deactivated();
                    root.activeCategory = managerItem.data[categoryList.currentIndex] ?? null;
                    root.activeCategory?.activated();
                }

                anchors.fill: parent
                objectName: "settingsPopupItem"

                Component.onCompleted: updateActiveCategory()
                onActiveCategoryIndexChanged: updateActiveCategory()
                onSectionsChanged: updateActiveCategory()

                ListModel {
                    id: sectionProperties

                }
                Rectangle {
                    id: categories

                    border.color: Theme.darkGray3
                    border.width: 6
                    color: Theme.darkGray
                    visible: root.width > popup.smallScreenWidth || showCategories.checked
                    width: Math.min(280, root.width * 0.25)
                    z: 100

                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        top: parent.top
                    }
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 0

                        Rectangle {
                            id: searchSetting

                            property bool active: false
                            property alias input: searchInput

                            Layout.fillWidth: true
                            color: Theme.midGray
                            height: 30

                            Text {
                                id: searchInputPlaceholder

                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.white
                                text: 'Search...'
                                visible: !parent.active
                            }
                            TextInput {
                                id: searchInput

                                anchors.verticalCenter: parent.verticalCenter
                                visible: parent.active
                                width: parent.width

                                onActiveFocusChanged: {
                                    parent.active = activeFocus;
                                }
                                onTextEdited: {
                                    root.manager.search(text);
                                }
                            }
                            TapHandler {
                                onTapped: {
                                    parent.active = true;
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }
                        ListView {
                            id: categoryList

                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            clip: true
                            currentIndex: 0
                            focus: true
                            model: sectionProperties
                            visible: !searchSetting.active

                            delegate: Rectangle {
                                required property int index
                                required property var label

                                color: ListView.isCurrentItem ? Theme.darkGray3 : Theme.darkGray2
                                height: 38
                                objectName: "category_" + label
                                width: ListView.view.width

                                Image {
                                    id: handleImage

                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    fillMode: Image.PreserveAspectFit
                                    height: 24
                                    layer.enabled: true
                                    source: "images/gear.svg"

                                    layer.effect: MultiEffect {
                                        brightness: 1.0
                                        colorization: 1.0
                                        colorizationColor: parent.ListView.isCurrentItem ? Theme.accentColor : Theme.midGray
                                    }
                                }
                                Text {
                                    anchors.left: handleImage.right
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Theme.white
                                    font.bold: parent.ListView.isCurrentItem
                                    text: label
                                }
                                TapHandler {
                                    onTapped: {
                                        categoryList.currentIndex = index;
                                        showCategories.checked = false;
                                    }
                                }
                            }
                        }
                        ListView {
                            id: settingResultList

                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            clip: true
                            focus: true
                            model: root.manager.model
                            visible: searchSetting.active

                            delegate: Rectangle {
                                required property var display
                                required property int index
                                required property var toolTip
                                required property var whatsThis

                                color: Theme.darkGray2
                                height: 40
                                width: ListView.view.width

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 4

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: implicitHeight
                                        color: Theme.white
                                        text: searchSetting.input.text ? display.replace(searchSetting.input.text, `<b>${searchSetting.input.text}</b>`) : display
                                        textFormat: Text.RichText
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: implicitHeight
                                        color: Theme.midGray
                                        font.pixelSize: 10
                                        text: searchSetting.input.text ? whatsThis.replace(searchSetting.input.text, `<b>${searchSetting.input.text}</b>`) : whatsThis
                                        textFormat: Text.RichText
                                    }
                                }
                                TapHandler {
                                    onTapped: {
                                        for (let setting of toolTip) {
                                            setting.activated();
                                        }
                                        parent.forceActiveFocus();
                                        showCategories.checked = false;
                                    }
                                }
                            }
                        }
                    }
                }
                ColumnLayout {
                    id: content

                    states: [
                        State {
                            when: root.width <= popup.smallScreenWidth

                            AnchorChanges {
                                anchors.left: parent.left
                                target: content
                            }
                        }
                    ]

                    anchors {
                        bottom: parent.bottom
                        left: categories.right
                        right: parent.right
                        top: parent.top
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true

                        Skin.Button {
                            id: showCategories

                            activeColor: Theme.white
                            checkable: true
                            text: "M"
                            visible: root.width <= popup.smallScreenWidth
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            color: Theme.white
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            text: "Settings"
                        }
                        Skin.Button {
                            activeColor: Theme.white
                            objectName: "settingsCloseButton"
                            text: "X"

                            onPressed: {
                                popup.close();
                            }
                        }
                    }
                    Rectangle {
                        id: tabBar

                        readonly property int selectedIndex: root.activeCategory?.selectedIndex ?? 0
                        readonly property var tabs: root.activeCategory?.tabs ?? []

                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        color: Theme.darkGray3
                        visible: tabs?.length > 0

                        RowLayout {
                            anchors.fill: parent

                            Repeater {
                                model: tabBar.tabs

                                Skin.Button {
                                    required property int index
                                    required property string modelData

                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredHeight: 22
                                    Layout.preferredWidth: parent.width / (tabBar.tabs.length + 2)
                                    activeColor: Theme.white
                                    checked: tabBar.selectedIndex == index
                                    objectName: "tab_" + modelData
                                    text: modelData

                                    onPressed: {
                                        if (root.activeCategory?.selectedIndex || root.activeCategory?.selectedIndex === 0) {
                                            root.activeCategory.selectedIndex = index;
                                        }
                                        parent.forceActiveFocus();
                                        showCategories.checked = false;
                                    }
                                }
                            }
                        }
                    }
                    Mixxx.SettingParameterManager {
                        id: managerItem

                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.leftMargin: 20

                        Component.onCompleted: {
                            let activateBuilder = index => function () {
                                    categoryList.currentIndex = index;
                                };
                            let visibleBuilder = index => function () {
                                    return categoryList.currentIndex == index;
                                };
                            for (let index = 0; index < data.length; index++) {
                                let child = data[index];
                                if (!child.label)
                                    continue;
                                sectionProperties.append({
                                    label: child.label
                                });
                                child.visible = Qt.binding(visibleBuilder(index));
                                child.activated.connect(activateBuilder(index));
                                child.anchors.fill = this;
                            }
                            // This is needed to ensure the right category is displayed.
                            // It would seems there is a bug, where the component's layout appears out of date.
                            // Setting the value to its current one seems to be triggering a component update which help fixing the layout
                            root.activeCategoryIndex = root.activeCategoryIndex;
                        }

                        Settings.SoundHardware {
                        }
                        Settings.Library {
                        }
                        Settings.Controller {
                        }
                        Settings.Interface {
                        }
                        Settings.MixerEffect {
                        }
                        Settings.AutoDJ {
                        }
                        Settings.Broadcast {
                        }
                        Settings.Recording {
                        }
                        Settings.Analyzer {
                        }
                        Settings.StatsPerformance {
                        }
                    }
                }

                // Testing automation resources
                Rectangle {
                    id: click

                    color: clickDetector.clicked ? 'red' : 'green'
                    radius: width / 2
                    visible: opacity != 0 && popup.enableDiagnosticClick

                    NumberAnimation on height {
                        from: 20
                        running: clickDetector.clicked
                        to: 0
                    }
                    NumberAnimation on opacity {
                        from: 1
                        running: clickDetector.clicked
                        to: 0
                    }
                    NumberAnimation on width {
                        from: 20
                        running: clickDetector.clicked
                        to: 0
                    }
                }
                MouseArea {
                    id: clickDetector

                    property bool clicked: false

                    anchors.fill: parent
                    enabled: popup.enableDiagnosticClick

                    onPressed: mouse => {
                        clicked = false;
                        click.width = 20;
                        click.height = 20;
                        click.opacity = 1;
                        click.x = Qt.binding(() => mouse.x - click.width / 2);
                        click.y = Qt.binding(() => mouse.y - click.height / 2);
                        clicked = true;
                        mouse.accepted = false;
                    }
                }
            }
        }
    }

    onAboutToHide: {
        loader.asynchronous = true;
    }
    onClosed: {
        Mixxx.Core.removeOpenedPopup(this);
    }
    onOpened: {
        Mixxx.Core.addOpenedPopup(this);
    }
}
