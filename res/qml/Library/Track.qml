import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Controls 2.15
import "../Theme"
import ".." as Skin

Item {
    id: root

    property var _lazyTrack: null
    required property var capabilities
    required property var crates
    readonly property var library: Mixxx.Library
    required property var playlists
    property alias tap: tapHandler
    required property var view

    function hasCapabilities(caps) {
        return (root.capabilities & caps) == caps;
    }

    TapHandler {
        id: tapHandler

        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onDoubleTapped: (eventPoint, button) => {
            if (button != Qt.LeftButton)
                return;
            view.selectionModel.selectRow(row);
            view.loadSelectedTrackIntoNextAvailableDeck(false);
        }
        onLongPressed: {
            view.selectionModel.selectRow(row);
            _lazyTrack = view.model?.getTrackByRow(row) ?? null;
            contextMenu.popup(parent);
        }
        onTapped: (eventPoint, button) => {
            view.selectionModel.selectRow(row);
            if (button === Qt.RightButton) {
                _lazyTrack = view.model?.getTrackByRow(row) ?? null;
                contextMenu.popup(parent, eventPoint.position);
            }
        }
    }
    TestableMenu {
        id: contextMenu

        title: qsTr("File")

        TestableMenu {
            enabled: {
                hasCapabilities(Mixxx.LibraryTrackListModel.Capability.LoadToDeck) || hasCapabilities(Mixxx.LibraryTrackListModel.Capability.LoadToSampler) || hasCapabilities(Mixxx.LibraryTrackListModel.Capability.LoadToPreviewDeck);
            }
            title: qsTr("Load to")

            TestableMenu {
                id: loadToDeckMenu

                enabled: hasCapabilities(Mixxx.LibraryTrackListModel.Capability.LoadToDeck)
                title: qsTr("Deck")

                Instantiator {
                    model: 4

                    delegate: MenuItem {
                        text: qsTr("Deck %1").arg(modelData + 1)

                        onTriggered: {
                            if (_lazyTrack)
                                Mixxx.PlayerManager.getPlayer(`[Channel${modelData + 1}]`).loadTrack(_lazyTrack);
                        }
                    }

                    onObjectAdded: (index, object) => loadToDeckMenu.insertItem(Math.min(count, object.modelData), object)
                    onObjectRemoved: (index, object) => loadToDeckMenu.removeItem(object)
                }
            }
            TestableMenu {
                enabled: hasCapabilities(Mixxx.LibraryTrackListModel.Capability.LoadToSampler)
                title: qsTr("Sampler")
            }

            // Instantiator {
            //     id: recentFilesInstantiator
            //     model: settings.recentFiles
            //     delegate: MenuItem {
            //         text: settings.displayableFilePath(modelData)
            //         onTriggered: loadFile(modelData)
            //     }

            //     onObjectAdded: (index, object) => recentFilesMenu.insertItem(index, object)
            //     onObjectRemoved: (index, object) => recentFilesMenu.removeItem(object)
            // }
        }
        TestableMenu {
            id: addToPlaylistMenu

            property var model: playlists.list()

            enabled: {
                hasCapabilities(Mixxx.LibraryTrackListModel.Capability.AddToTrackSet);
            }
            title: qsTr("Add to playlists")

            Instantiator {
                model: addToPlaylistMenu.model

                delegate: MenuItem {
                    enabled: !modelData.locked
                    text: modelData.name

                    onTriggered: modelData.addTrack(root._lazyTrack)
                }

                onObjectAdded: (index, object) => addToPlaylistMenu.insertItem(0, object)
                onObjectRemoved: (index, object) => addToPlaylistMenu.removeItem(object)
            }
            MenuSeparator {
            }
            NewEntityMenuItem {
                id: createPlaylistItem

                manager: playlists
                text: qsTr("Create New Playlist")

                onCreated: {
                    addToPlaylistMenu.model = playlists.list();
                }
            }
        }
        TestableMenu {
            id: addToCrateMenu

            property var model: root._lazyTrack ? crates.list([root._lazyTrack]) : 0

            enabled: {
                hasCapabilities(Mixxx.LibraryTrackListModel.Capability.AddToTrackSet);
            }
            title: qsTr("Crates")

            Instantiator {
                model: addToCrateMenu.model

                delegate: CheckBox {
                    checkable: true
                    checked: modelData.trackCount() == 1
                    enabled: !modelData.locked
                    text: modelData.name

                    onCheckedChanged: {
                        if (checked) {
                            modelData.addTrack(root._lazyTrack);
                        } else {
                            modelData.removeTrack(root._lazyTrack);
                        }
                    }
                }

                onObjectAdded: (index, object) => addToCrateMenu.insertItem(0, object)
                onObjectRemoved: (index, object) => addToCrateMenu.removeItem(object)
            }
            MenuSeparator {
            }
            NewEntityMenuItem {
                id: createCrateItem

                manager: crates
                text: qsTr("Create New Crate")

                onCreated: {
                    addToCrateMenu.model = manager.list([root._lazyTrack]);
                }
            }
        }
        TestableMenu {
            id: analyzeMenu

            enabled: {
                hasCapabilities(Mixxx.LibraryTrackListModel.Capability.EditMetadata) || hasCapabilities(Mixxx.LibraryTrackListModel.Capability.Analyze);
            }
            title: qsTr("Analyze")

            MenuItem {
                text: qsTr("Analyze")

                onTriggered: {
                    if (_lazyTrack)
                        library.analyze(_lazyTrack);
                }
            }
            MenuItem {
                enabled: false // TODO implement
                text: qsTr("Reanalyze")
            }
            MenuItem {
                enabled: false // TODO implement
                text: qsTr("Reanalyze (constant BPM)")
            }
            MenuItem {
                enabled: false // TODO implement
                text: qsTr("Reanalyze (variable BPM)")
            }
        }
    }

    component NewEntityMenuItem: MenuItem {
        id: createEntityItem

        property bool creating: false
        required property var manager

        signal created(string name)

        function cancelEditing() {
            createEntityItem.creating = false;
            input.text = "";
        }
        function startEditing() {
            createEntityItem.creating = true;
            input.forceActiveFocus();
        }
        function startKeyHandler(event) {
            if (Window.activeFocusItem != input) {
                startEditing();
            }
            event.accepted = true;
        }

        contentItem: Item {
            objectName: "contextMenuCreateEntityItem"

            TextInput {
                id: input

                anchors.fill: parent
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.margins: 7
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                color: acceptableInput ? "#000000" : 'red'
                horizontalAlignment: TextInput.AlignLeft
                visible: createEntityItem.creating

                onAccepted: {
                    if (text) {
                        manager.create(text);
                        createEntityItem.created(text);
                    }
                    createEntityItem.cancelEditing();
                }
            }
            Text {
                color: "#000000"
                elide: Text.ElideRight
                font: createEntityItem.font
                horizontalAlignment: Text.AlignLeft
                leftPadding: createEntityItem.indicator.width
                opacity: enabled ? 1.0 : 0.3
                rightPadding: createEntityItem.arrow.width
                text: createEntityItem.text
                verticalAlignment: Text.AlignVCenter
                visible: !createEntityItem.creating
            }
            TapHandler {
                onTapped: createEntityItem.startEditing()
            }
        }

        Keys.onEnterPressed: event => startKeyHandler(event)
        Keys.onEscapePressed: event => {
            cancelEditing();
            event.accepted = true;
        }
        Keys.onReturnPressed: event => startKeyHandler(event)
        Keys.onSpacePressed: event => startKeyHandler(event)
    }
    component TestableMenu: Menu {
        id: control

        readonly property int depth: {
            return parent instanceof MenuItem ? parent.menu.depth + 1 : 0;
        }

        function dumpTree(recursive) {
            let d = {
                count: this.contentItem.count,
                currentIndex: this.contentItem.currentIndex,
                items: Array(this.contentItem.count).fill().map((_, i) => {
                    let item = this.contentItem.itemAtIndex(i);
                    let m = recursive ? menuAt(i) : null;
                    return Object.assign({
                        objectName: item?.objectName,
                        text: item?.text
                    }, m ? {
                        menu: m.dumpTree()
                    } : {});
                })
            };
            return d;
        }

        contentItem: ListView {
            function serialisedDump() {
                return JSON.stringify(control.dumpTree(false));
            }
            function setMenuIndex(i) {
                control.currentIndex = i;
            }

            clip: true
            currentIndex: control.currentIndex
            implicitHeight: contentHeight
            interactive: Window.window ? contentHeight + control.topPadding + control.bottomPadding > control.height : false
            model: control.contentModel
            objectName: opened ? !depth ? "trackContextMenu" : `trackContextMenu_Sub${depth}` : null

            ScrollIndicator.vertical: ScrollIndicator {
            }
        }

        onOpenedChanged: {
            for (let i = 0; i < contentItem.count; i++) {
                contentItem.itemAtIndex(i).objectName = "menuItem" + i;
            }
        }
    }
}
