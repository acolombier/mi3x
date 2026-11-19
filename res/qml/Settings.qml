import "." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import "Theme"
import "Settings" as Settings

DetachablePopup {
    id: root

    property var requestFocusSection: null

    // FIXME change to `final` when supported
    readonly property real smallScreenWidth: 1200

    signal saved(var group)

    function focusSection(section) {
        root.requestFocusSection = section;
        if (loader.item) {
            const group = loader.item.manager.findSettings(root.requestFocusSection);
            group?.activated();
            root.requestFocusSection = null;
        }
    }

    loader {
        objectName: "settingsLoader"

        sourceComponent: Component {
            Item {
                id: content

                property var activeCategory: null
                property alias activeCategoryIndex: categoryList.currentIndex
                readonly property var manager: managerItem
                property alias sections: managerItem.data

                function updateActiveCategory() {
                    content.activeCategory?.deactivated();
                    content.activeCategory = managerItem.data[categoryList.currentIndex] ?? null;
                    content.activeCategory?.activated();
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
                    visible: content.width > root.smallScreenWidth || showCategories.checked
                    width: Math.min(280, content.width * 0.25)
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
                                    content.manager.search(text);
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
                                objectName: "category_" + label.replace(/[^a-zA-Z0-9]+/g, '')
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
                            model: content.manager.model
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
                    id: contentLayout

                    states: [
                        State {
                            when: content.width <= root.smallScreenWidth

                            AnchorChanges {
                                anchors.left: parent.left
                                target: contentLayout
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
                            visible: content.width <= root.smallScreenWidth
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
                    }
                    Rectangle {
                        id: tabBar

                        readonly property int selectedIndex: content.activeCategory?.selectedIndex ?? 0
                        readonly property var tabs: content.activeCategory?.tabs ?? []

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
                                        if (content.activeCategory?.selectedIndex || content.activeCategory?.selectedIndex === 0) {
                                            content.activeCategory.selectedIndex = index;
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
                            let savedBuilder = child => function () {
                                    root.saved(child);
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
                                child.saved.connect(savedBuilder(child));
                                child.anchors.fill = this;
                            }
                            // This is needed to ensure the right category is displayed.
                            // It would seems there is a bug, where the component's layout appears out of date.
                            // Setting the value to its current one seems to be triggering a component update which help fixing the layout
                            content.activeCategoryIndex = content.activeCategoryIndex;
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
            }
        }

        onLoaded: {
            if (!root.requestFocusSection)
                return;
            const group = loader.item.manager.findSettings(root.requestFocusSection);
            group?.activated();
            root.requestFocusSection = null;
        }
    }
}
