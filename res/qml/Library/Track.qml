import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Controls 2.15
import "../Theme"
import ".." as Skin

Item {
    id: root

    property var _lazyTrack: null
    required property var capabilities
    property alias contextMenu: contextMenu
    required property var crates
    readonly property var dragThreshold: 20
    readonly property var library: Mixxx.Library
    required property var playlists
    required property var view

    function fetchTrack() {
        if (!root._lazyTrack)
            root._lazyTrack = view.model?.getTrackByRow(row) ?? null;
        return root._lazyTrack;
    }
    function getActiveMenu() {
        let traverse = menu => {
            for (let i = 0; i < menu.count; i++) {
                if (menu.menuAt(i)?.visible)
                    return traverse(menu.menuAt(i));
            }
            return menu;
        };
        return traverse(contextMenu);
    }
    function hasCapabilities(caps) {
        return (root.capabilities & caps) == caps;
    }
    function select(row) {
        let activeMenu = root.getActiveMenu();
        let newIndex = Mixxx.MathUtils.positiveModulo(activeMenu.currentIndex + row, activeMenu.count);
        while (activeMenu.itemAt(newIndex) instanceof MenuSeparator) {
            newIndex = Mixxx.MathUtils.positiveModulo(newIndex + row, activeMenu.count);
        }
        activeMenu.currentIndex = newIndex;
    }

    TapHandler {
        id: tapHandler

        acceptedButtons: Qt.LeftButton | Qt.RightButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        dragThreshold: root.dragThreshold
        // FIXME: this is a workaround on Qt bug. See core proxy for details
        enabled: !Mixxx.Core.hasPopup

        onDoubleTapped: (eventPoint, button) => {
            if (button === Qt.RightButton)
                return;
            view.selectionModel.selectRow(row);
            view.loadSelectedTrackIntoNextAvailableDeck(false);
        }
        onTapped: (eventPoint, button) => {
            view.selectionModel.selectRow(row);
            if (button === Qt.RightButton) {
                contextMenu.popup(parent, eventPoint.position);
            }
        }
    }
    TapHandler {
        id: touchScreenTapHandler

        acceptedDevices: PointerDevice.TouchScreen | PointerDevice.Stylus
        dragThreshold: root.dragThreshold
        // FIXME: this is a workaround on Qt bug. See core proxy for details
        enabled: !Mixxx.Core.hasPopup

        onDoubleTapped: (eventPoint, button) => {
            view.selectionModel.selectRow(row);
            view.loadSelectedTrackIntoNextAvailableDeck(false);
        }
        onLongPressed: {
            view.selectionModel.selectRow(row);
            contextMenu.popup(parent, 0, 0);
        }
        onTapped: (eventPoint, button) => {
            view.selectionModel.selectRow(row);
        }
    }
    Mixxx.ControlProxy {
        group: "[Library]"
        key: "GoToItem"

        onValueChanged: value => {
            if (!contextMenu.opened || value == 0)
                return;
            let activeMenu = root.getActiveMenu();
            let item = activeMenu.itemAt(activeMenu.currentIndex);
            if (!item)
                item = activeMenu.menuAt(activeMenu.currentIndex);
            if (!item)
                item = activeMenu.actionAt(activeMenu.currentIndex);
            item.triggered();
        }
    }
    Mixxx.ControlProxy {
        group: "[Library]"
        key: "MoveVertical"

        onValueChanged: value => {
            if (!contextMenu.opened || value == 0)
                return;
            select(value);
        }
    }
    Mixxx.ControlProxy {
        group: "[Library]"
        key: "MoveUp"

        onValueChanged: value => {
            if (!contextMenu.opened || value == 0)
                return;
            select(-1);
        }
    }
    Mixxx.ControlProxy {
        group: "[Library]"
        key: "MoveDown"

        onValueChanged: value => {
            if (!contextMenu.opened || value == 0)
                return;
            select(1);
        }
    }
    Mixxx.ControlProxy {
        id: showTrackMenuControl

        group: "[Library]"
        key: "show_track_menu"

        onValueChanged: {
            if (!value && contextMenu.opened) {
                contextMenu.close();
            }
        }
    }
    CustomMenu {
        id: contextMenu

        function build() {
            itemModel.clear();
            let record = data => Object.assign({
                    type: "item",
                    itemChecked: null,
                    itemText: null,
                    itemAction: null,
                    itemEnabled: true,
                    menuTitle: null,
                    menuItems: null,
                    createCollection: null,
                    createCreated: null
                }, data);
            let addItem = (text, action, enabled, parent) => (parent ? parent.push : itemModel.append)(record({
                    type: "item",
                    itemText: qsTr(text),
                    itemAction: action,
                    itemEnabled: typeof enabled === "undefined" || !!enabled
                }));
            let addMenu = (text, menu, parent) => (parent ? parent.push : itemModel.append)(record({
                    type: "menu",
                    menuTitle: qsTr(text),
                    menuItems: menu
                }));
            let addSeparator = parent => (parent ? parent.push : itemModel.append)(record({
                    type: "separator"
                }));

            let findMenu = (menu, title) => {
                for (let i = 0; i < menu.count; i++) {
                    if (menu.get(i).menuTitle == title)
                        return menu.get(i);
                    if (menu.get(i).menuItems) {
                        let nested = findMenu(menu.get(i).menuItems, title);
                        if (nested)
                            return nested;
                    }
                }
                return null;
            };

            let track = root.fetchTrack();
            let searchMenu = [];
            let searchQuery = new Set();
            let addSearchEntry = (field, details, search) => {
                if (searchMenu.length)
                    searchMenu.push(record({
                        type: "separator"
                    }));
                // FIXME Not very reliable - doesn't detect field alias, doesn't detected quoted values
                if (view?.model.search.includes(search))
                    searchQuery.add(search);
                searchMenu.push(record({
                    type: "checkbox",
                    itemText: qsTr(field) + ": " + details,
                    itemChecked: view?.model.search.includes(search),
                    itemAction: checked => {
                        if (!checked)
                            searchQuery.delete(search);
                        else
                            searchQuery.add(search);
                    }
                }));
            };
            if (track.keyText)
                addSearchEntry("Key", qsTr("harmonic with %1").arg(track.keyText), `~key:"${track.keyText}"`);
            if (track.bpm)
                addSearchEntry("BPM", qsTr("%1 - %2").arg(parseInt(track.bpm - 8)).arg(parseInt(track.bpm + 8)), `bpm:${parseInt(track.bpm - 8)}-${parseInt(track.bpm + 8)}`);
            if (track.artist)
                addSearchEntry("Artist", track.artist, `artist:${JSON.stringify(track.artist)}`);
            if (track.albumArtist)
                addSearchEntry("Album Artist", track.albumArtist, `album_artist:${JSON.stringify(track.albumArtist)}`);
            if (track.composer)
                addSearchEntry("Composer", track.composer, `composer:${JSON.stringify(track.composer)}`);
            if (track.title)
                addSearchEntry("Title", track.title, `title:${JSON.stringify(track.title)}`);
            if (track.album)
                addSearchEntry("Album", track.album, `album:${JSON.stringify(track.album)}`);
            if (track.grouping)
                addSearchEntry("Grouping", track.grouping, `grouping:${track.grouping}`);
            if (track.year)
                addSearchEntry("Year", track.year, `y:${track.year}`);
            // FIXME not exposed currently
            // if (track.directory) addSearchEntry("Directory", track.directory, `lo:${track.directory}`);

            searchMenu.push(record({
                type: "separator"
            }));
            searchMenu.push(record({
                type: "item",
                itemText: qsTr("Search selected"),
                itemAction: () => {
                    if (!view.model)
                        return;
                    view.model.search = Array.from(searchQuery).join(" ");
                }
            }));

            addMenu("Search related Tracks", searchMenu);  // Will use custom delegate
            if (hasCapabilities(Mixxx.LibraryTrackListModel.Capability.SelectInLibrary)) {
                addItem("Select in Library");
            }
            addSeparator();
            if (hasCapabilities(Mixxx.LibraryTrackListModel.Capability.AddToAutoDJ)) {
                addItem("Add to Auto DJ Queue (bottom)");
                addItem("Add to Auto DJ Queue (top)");
                addItem("Add to Auto DJ Queue (replace)");
                addSeparator();
            }

            let loadToDeck = hasCapabilities(Mixxx.LibraryTrackListModel.Capability.LoadToDeck);
            let loadToPreviewDeck = hasCapabilities(Mixxx.LibraryTrackListModel.Capability.LoadToPreviewDeck);
            let loadToSampler = hasCapabilities(Mixxx.LibraryTrackListModel.Capability.LoadToSampler);
            let loadTo = loadToDeck || loadToSampler || loadToPreviewDeck;
            if (loadTo) {
                let loadMenu = [];
                if (loadToDeck)
                    loadMenu.push(...[record({
                            type: "menu",
                            menuTitle: qsTr("Deck"),
                            menuItems: Array(numDecksControl.value).fill().map((_, i) => record({
                                    type: "item",
                                    itemText: qsTr(`Deck ${i + 1}`),
                                    itemAction: () => Mixxx.PlayerManager.getPlayer(`[Channel${i + 1}]`).loadTrack(root.fetchTrack())
                                }))
                        })]);
                if (loadToSampler)
                    loadMenu.push(...[record({
                            type: "menu",
                            menuTitle: qsTr("Sampler"),
                            menuItems: Array(numSamplersControl.value <= 16 ? numSamplersControl.value : 16 + Math.ceil((numSamplersControl.value - 16) / 16)).fill().map((_, i) => i < 16 ? record({
                                    type: "item",
                                    itemText: qsTr(`Sampler ${i + 1}`),
                                    itemAction: () => Mixxx.PlayerManager.getPlayer(`[Sampler${i + 1}]`).loadTrack(root.fetchTrack())
                                }) : record({
                                    type: "menu",
                                    menuTitle: qsTr(`Sampler ${1 + (i - 16 + 1) * 16}-${Math.min(16 + (i - 16 + 1) * 16, numSamplersControl.value)}`),
                                    menuItems: Array(Math.min(16, numSamplersControl.value - (i - 16 + 1) * 16)).fill().map((_, j) => record({
                                            type: "item",
                                            itemText: qsTr(`Sampler ${1 + (i - 16 + 1) * 16 + j}`),
                                            itemAction: () => Mixxx.PlayerManager.getPlayer(`[Sampler${1 + (i - 16 + 1) * 16 + j}]`).loadTrack(root.fetchTrack())
                                        }))
                                }))
                        })]);
                if (loadToPreviewDeck)
                    loadMenu.push(...[record({
                            type: "item",
                            itemText: qsTr("Preview Deck"),
                            itemAction: () => Mixxx.PlayerManager.getPlayer(`[PreviewDeck1]`).loadTrack(root.fetchTrack())
                        })]);
                addMenu("Load to", loadMenu);
                addSeparator();
            }
            if (hasCapabilities(Mixxx.LibraryTrackListModel.Capability.AddToTrackSet)) {
                let playlistMenu = [...root.playlists.list().map(playlist => record({
                            type: "item",
                            itemText: playlist.name,
                            itemEnabled: !playlist.locked,
                            itemAction: () => playlist.addTrack(root.fetchTrack())
                        })), record({
                        type: "separator"
                    }), record({
                        type: "create",
                        itemText: qsTr("Create New Playlist"),
                        createCollection: playlists,
                        createCreated: (item, name) => {
                            let lists = playlists.list();
                            let playlist = lists.find(playlist => playlist.name == name);
                            let menu = findMenu(itemModel, "Add to playlists");
                            // FIXME do we want to just auto close for playlist?
                            menu.menuItems.insert(lists.indexOf(playlist), record({
                                type: "item",
                                itemText: name,
                                itemEnabled: true,
                                itemAction: () => playlist.addTrack(root.fetchTrack())
                            }));
                        }
                    })];
                addMenu("Add to playlists", playlistMenu);
                let crateMenu = [...root.crates.list([root.fetchTrack()]).map(crate => record({
                            type: "checkbox",
                            itemText: crate.name,
                            itemEnabled: !crate.locked,
                            itemChecked: !!crate.trackCount(),
                            itemAction: checked => {
                                let cb = (checked ? crate.addTrack : crate.removeTrack);
                                cb(root.fetchTrack());
                            }
                        })), record({
                        type: "separator"
                    }), record({
                        type: "create",
                        itemText: qsTr("Create New Crate"),
                        createCollection: root.crates,
                        createCreated: (item, name) => {
                            let lists = crates.list([]);
                            let crate = lists.find(crate => crate.name == name);
                            let menu = findMenu(itemModel, "Crates");
                            crate.addTrack(root.fetchTrack());
                            menu.menuItems.insert(lists.indexOf(crate), record({
                                type: "checkbox",
                                itemText: name,
                                itemEnabled: true,
                                itemChecked: true,
                                itemAction: checked => (checked ? crate.addTrack : crate.removeTrack)(root.fetchTrack())
                            }));
                        }
                    })];
                addMenu("Crates", crateMenu);
                addSeparator();
            }
            if (hasCapabilities(Mixxx.LibraryTrackListModel.Capability.RemovePlaylist)) {
                itemModel.append(record({
                    type: "item",
                    itemText: qsTr("Remove from Playlist"),
                    itemAction: () => {
                        // TODO need to expose playlist, maybe something like via root.view.sidebar.feature
                        print("REMOVE", root.view.model);
                    },
                    itemEnabled: hasCapabilities(Mixxx.LibraryTrackListModel.Capability.Locked)
                }));
                addSeparator();
            }
            if (hasCapabilities(Mixxx.LibraryTrackListModel.Capability.RemoveCrate)) {
                addItem("Remove from Crate");
                addSeparator();
            }

            let bpmScaleActionBuilder = scale => () => {
                    let track = root.fetchTrack();
                    track.bpm *= scale;
                };
            let bpmMenu = [record({
                    type: "item",
                    itemText: qsTr("Halve BPM"),
                    itemAction: bpmScaleActionBuilder(0.5)
                }), record({
                    type: "item",
                    itemText: qsTr("2/3 BPM"),
                    itemAction: bpmScaleActionBuilder(2 / 3)
                }), record({
                    type: "item",
                    itemText: qsTr("3/4 BPM"),
                    itemAction: bpmScaleActionBuilder(3 / 4)
                }), record({
                    type: "item",
                    itemText: qsTr("4/5 BPM"),
                    itemAction: bpmScaleActionBuilder(4 / 5)
                }), record({
                    type: "item",
                    itemText: qsTr("5/4 BPM"),
                    itemAction: bpmScaleActionBuilder(5 / 4)
                }), record({
                    type: "item",
                    itemText: qsTr("4/3 BPM"),
                    itemAction: bpmScaleActionBuilder(4 / 3)
                }), record({
                    type: "item",
                    itemText: qsTr("3/2 BPM"),
                    itemAction: bpmScaleActionBuilder(3 / 2)
                }), record({
                    type: "item",
                    itemText: qsTr("Double BPM"),
                    itemAction: bpmScaleActionBuilder(2)
                }), record({
                    type: "separator"
                }), record({
                    type: "item",
                    itemText: qsTr("Lock BPM")
                }), record({
                    type: "item",
                    itemText: qsTr("Unlock BPM")
                }), record({
                    type: "separator"
                }), record({
                    type: "item",
                    itemText: qsTr("Clear BPM and Beatgrid")
                }), record({
                    type: "item",
                    itemText: qsTr("Undo last BPM/beats change")
                }),];
            addMenu("Adjust BPM", bpmMenu);
            addItem("Rating"); // Will use custom delegate
            addMenu("Select Color"); // Will use custom delegate
            addSeparator();
            addMenu("Metadata", [record({
                    type: "item",
                    itemText: qsTr("Import From File Tags")
                }), record({
                    type: "item",
                    itemText: qsTr("Export To File Tags")
                }), record({
                    type: "menu",
                    menuTitle: qsTr("Cover Art")
                }), record({
                    type: "item",
                    itemText: qsTr("Import From MusicBrainz")
                }), record({
                    type: "menu",
                    menuTitle: qsTr("Update external collections")
                }), record({
                    type: "menu",
                    menuTitle: qsTr("Find on Web")
                }),]);
            addMenu("Hotcues", [record({
                    type: "item",
                    itemText: qsTr("Sort hotcues by position (remove offsets)")
                }), record({
                    type: "item",
                    itemText: qsTr("Sort hotcues by position")
                }),]);
            addMenu("Clear", [record({
                    type: "item",
                    itemText: qsTr("BPM and Beatgrid")
                }), record({
                    type: "item",
                    itemText: qsTr("Play Count")
                }), record({
                    type: "item",
                    itemText: qsTr("Rating")
                }), record({
                    type: "item",
                    itemText: qsTr("Comment")
                }), record({
                    type: "item",
                    itemText: qsTr("Cue Point")
                }), record({
                    type: "item",
                    itemText: qsTr("Hotcues")
                }), record({
                    type: "item",
                    itemText: qsTr("Intro")
                }), record({
                    type: "item",
                    itemText: qsTr("Outro")
                }), record({
                    type: "item",
                    itemText: qsTr("Loops")
                }), record({
                    type: "item",
                    itemText: qsTr("Key")
                }), record({
                    type: "item",
                    itemText: qsTr("ReplayGain")
                }), record({
                    type: "item",
                    itemText: qsTr("Waveform")
                }), record({
                    type: "separator"
                }), record({
                    type: "item",
                    itemText: qsTr("All")
                })]);
            if (hasCapabilities(Mixxx.LibraryTrackListModel.Capability.EditMetadata) || hasCapabilities(Mixxx.LibraryTrackListModel.Capability.Analyze)) {
                addMenu("Analyze", [record({
                        type: "item",
                        itemText: qsTr("Analyze"),
                        itemAction: () => library.analyze(root.fetchTrack())
                    }), record({
                        type: "item",
                        itemText: qsTr("Reanalyze"),
                        itemAction: () => library.analyze(root.fetchTrack(), true)
                    }), record({
                        type: "item",
                        itemText: qsTr("Reanalyze (constant BPM)"),
                        itemAction: () => library.analyze(root.fetchTrack(), true, true)
                    }), record({
                        type: "item",
                        itemText: qsTr("Reanalyze (variable BPM)"),
                        itemAction: () => library.analyze(root.fetchTrack(), true, false)
                    }),]);
            }
            addSeparator();
            if (hasCapabilities(Mixxx.LibraryTrackListModel.Capability.Hide)) {
                addItem("Hide from Library");
            }
            if (hasCapabilities(Mixxx.LibraryTrackListModel.Capability.Unhide)) {
                addItem("Unhide from Library");
            }
            if (hasCapabilities(Mixxx.LibraryTrackListModel.Capability.Purge)) {
                addMenu("Purge from Library");
            }
            if (hasCapabilities(Mixxx.LibraryTrackListModel.Capability.RemoveFromDisk)) {
                addItem("Move Track File(s) to Trash");
            }
            addMenu("Open in File Browser");
            if (hasCapabilities(Mixxx.LibraryTrackListModel.Capability.Properties)) {
                addSeparator();
                addItem("Properties", () => {
                    root.Window.window.requestTrackProperties(root.fetchTrack());
                });
            }
        }

        menuName: "trackContextMenu"

        onAboutToShow: {
            contextMenu.build();
        }
        onOpened: {
            focusedWidgetControl.value = Qt.binding(() => opened ? Skin.FocusedWidgetControl.WidgetKind.ContextMenu : Skin.FocusedWidgetControl.WidgetKind.LibraryView);
            showTrackMenuControl.value = Qt.binding(() => opened ? 1 : 0);
        }

        Skin.FocusedWidgetControl {
            id: focusedWidgetControl

        }
        Mixxx.ControlProxy {
            id: numDecksControl

            group: "[App]"
            key: "num_decks"
        }
        Mixxx.ControlProxy {
            id: numSamplersControl

            group: "[App]"
            key: "num_samplers"
        }
        ListModel {
            id: itemModel

            dynamicRoles: true
        }
        DelegateChooser {
            id: menuDelegate

            role: "type"

            DelegateChoice {
                roleValue: "separator"

                MenuSeparator {
                    padding: 10
                    verticalPadding: 2

                    contentItem {
                        implicitHeight: 1
                    }
                }
            }
            DelegateChoice {
                roleValue: "item"

                CustomMenuItem {
                    id: item

                    enabled: itemEnabled && itemAction
                    text: itemText

                    onTriggered: {
                        if (!itemAction)
                            return;
                        itemAction();
                    }
                }
            }
            DelegateChoice {
                roleValue: "create"

                NewEntityMenuItem {
                    id: item

                    required property var modelData

                    manager: modelData.createCollection
                    text: modelData.itemText

                    onCreated: name => {
                        if (!modelData.createCreated)
                            return;
                        modelData.createCreated(item, name);
                    }
                }
            }
            DelegateChoice {
                roleValue: "checkbox"

                CheckBox {
                    required property var modelData

                    checkable: true
                    checked: modelData.itemChecked
                    enabled: modelData.itemEnabled && modelData.itemAction
                    implicitHeight: 20
                    text: modelData.itemText

                    onCheckedChanged: {
                        if (!modelData.itemAction)
                            return;
                        modelData.itemAction(checked);
                    }

                    indicator {
                        implicitHeight: 14
                        implicitWidth: 14
                    }
                }
            }
            DelegateChoice {
                roleValue: "menu"

                CustomMenu {
                    id: item

                    title: menuTitle

                    Instantiator {
                        delegate: menuDelegate
                        model: menuItems

                        onObjectAdded: (index, object) => {
                            if (object instanceof Menu) {
                                item.insertMenu(index, object);
                            } else {
                                item.insertItem(index, object);
                            }
                        }
                        onObjectRemoved: (index, object) => {
                            if (object instanceof Menu) {
                                item.removeMenu(object);
                            } else {
                                item.removeItem(object);
                            }
                        }
                    }
                }
            }
        }
        Instantiator {
            delegate: menuDelegate
            model: itemModel

            onObjectAdded: (index, object) => {
                if (object instanceof Menu) {
                    contextMenu.insertMenu(index, object);
                } else {
                    contextMenu.insertItem(index, object);
                }
            }
            onObjectRemoved: (index, object) => {
                if (object instanceof Menu) {
                    contextMenu.removeMenu(object);
                } else {
                    contextMenu.removeItem(object);
                }
            }
        }
    }

    component CustomMenu: Skin.TestableMenu {
        delegate: CustomMenuItem {
        }
    }
    component CustomMenuItem: MenuItem {
        id: menuItem

        implicitHeight: 20

        background: Rectangle {
            color: menuItem.highlighted ? Theme.accentColor : "transparent"
            implicitHeight: 40
            opacity: enabled ? 1 : 0.3
        }

        arrow {
            height: 10
            width: 10
        }
        indicator {
            height: 10
            width: 10
        }
        icon {
            height: 10
            width: 10
        }
    }
    component NewEntityMenuItem: CustomMenuItem {
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
            objectName: createEntityItem.creating ? "contextMenuCreateEntityItem" : ""

            TextInput {
                id: input

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
                onActiveFocusChanged: {
                    if (!activeFocus && createEntityItem.creating)
                        cancelEditing();
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
                gesturePolicy: TapHandler.WithinBounds

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
}
