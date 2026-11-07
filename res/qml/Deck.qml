import "." as Skin
import Mixxx 1.0 as Mixxx
import Mixxx.Controls 1.0 as MixxxControls
import QtQuick 2.12
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls 2.12
import QtQuick.Effects
import QtQml.Models // DelegateChoice for Qt >= 6.9
import Qt.labs.qmlmodels // DelegateChooser
import "Theme"

import "Deck" as DeckComponent

Item {
    id: root

    enum Cardinality {
        North,
        East,
        South,
        West
    }

    property real availableWidth: -1
    property var collapsedItem: Array()
    readonly property var currentTrack: deckPlayer.currentTrack
    property var deckPlayer: Mixxx.PlayerManager.getPlayer(group)
    property bool editMode: false
    required property string group
    property bool minimized: false
    property alias minimizedModel: minimizedItemModel
    property alias normalModel: itemModel

    signal toggleFocus

    function computeOverflow() {
        let expanded = [];
        let traverse = (item, depth) => {
            let width = 0;
            let acc = size => (item.disposition == GridLayout.TopToBottom) ? Math.max(width, size) : width + size;
            for (let child of item.children) {
                if (child instanceof LayoutContainer) {
                    width = acc(child.collapsed ? child.width : traverse(child, depth + 1));
                } else if (child instanceof LayoutItem) {
                    let size = child.Layout.minimumWidth;
                    // print(" ".repeat(depth), "*** minimumWidth", child, size);
                    if (!child.collapsed && child.autoCollapsed) {
                        expanded.push(child);
                    }
                    width = acc(size);
                } else {
                    continue;
                }
                if (item.disposition == GridLayout.LeftToRight) {
                    width += item.columnSpacing;
                }
            }
            if (item.disposition == GridLayout.LeftToRight) {
                width -= item.columnSpacing;
            }
            // print(" ".repeat(depth), "*** minimumWidth", item, "->", width)
            return width;
        };
        return [traverse(grid, 0) - grid.width, expanded];
    }
    function expandItem(layoutItem) {
        // print("onTapped", availableWidth);

        let neededWidth = layoutItem.desiredWidth();
        // for (let child of layoutItem.parent.children){
        //     if (!(child instanceof LayoutItem) || layoutItem == child) continue;
        // //     // print("onTapped", neededWidth, child)
        //     neededWidth += layoutItem.parent.columnSpacing;
        //     if (child.collapsed) continue;
        //     neededWidth += child.desiredWidth()
        // }
        // print("onTapped needed", neededWidth);
        // // print("onTapped", neededWidth, availableWidth)
        let currentAvailableWidth = root.availableWidth - neededWidth + 20;

        if (currentAvailableWidth < 0) {
            let traverse = item => {
                for (let child of item.children) {
                    if (child instanceof LayoutContainer) {
                        traverse(child);
                    }
                    if (child.autoCollapsed && !child.collapsed) {
                        child.collapsed = Qt.binding(() => child.autoCollapsed);
                        if (child.autoCollapsed) {
                            root.collapsedItem.push(child);
                        }
                    }
                }
            };
            traverse(grid);
        }
        root.collapsedItem.splice(root.collapsedItem.indexOf(layoutItem), 1);
        layoutItem.collapsed = false;
        if (currentAvailableWidth < 0) {
            root.updateAvailableWidth();
        }
    // root.availableWidth = currentAvailableWidth - neededWidth;
    // }
    // print("onTapped finish", neededWidth, root.availableWidth, currentAvailableWidth);
    }
    function resetLayout() {
        itemModel.clear();
        itemModel.append({
            "type": "column",
            "items": [
                {
                    "type": "info"
                },
                {
                    "type": "row",
                    "items": [
                        {
                            "type": "column",
                            "items": [
                                {
                                    "type": "waveformOverview"
                                },
                                {
                                    "type": "row",
                                    "items": [
                                        {
                                            "type": "column",
                                            "items": [
                                                {
                                                    "type": "play"
                                                },
                                                {
                                                    "type": "cue"
                                                }
                                            ]
                                        },
                                        {
                                            "type": "column",
                                            "items": [
                                                {
                                                    "type": "toolbar"
                                                },
                                                {
                                                    "type": "row",
                                                    "items": [
                                                        {
                                                            "type": "hotcueAndStem",
                                                            "minWidth": 600
                                                        },
                                                        {
                                                            "type": "beatjump",
                                                            "minWidth": 750
                                                        },
                                                        {
                                                            "type": "loop",
                                                            "minWidth": 400
                                                        }
                                                    ]
                                                }
                                            ]
                                        }
                                    ]
                                }
                            ]
                        },
                        {
                            "type": "column",
                            "minWidth": 1200,
                            "items": [
                                {
                                    "type": "spinny"
                                },
                                {
                                    "type": "fxAssign"
                                }
                            ]
                        },
                        {
                            "minWidth": 350,
                            "type": "tempo"
                        }
                    ]
                }
            ]
        });
        minimizedItemModel.clear();
        minimizedItemModel.append({
            "type": "row",
            "items": [
                {
                    "type": "column",
                    "items": [
                        {
                            "type": "play"
                        },
                        {
                            "type": "cue"
                        }
                    ]
                },
                {
                    "type": "column",
                    "items": [
                        {
                            "type": "info"
                        },
                        {
                            "type": "waveformOverview"
                        }
                    ]
                }
            ]
        });
    }
    function serializeModel(item) {
        let result = new Array();
        for (let i = 0; i < item.count; i++) {
            let child = item.get(i);
            let object = {
                type: child.type
            };
            if (child.items !== undefined) {
                // Should be needed
                // print("serializeModel", child.items.count)
                // if (child.items.count == 0) continue;
                object.items = serializeModel(child.items);
            }
            if (child.minWidth !== undefined) {
                object.minWidth = child.minWidth;
            }
            result.push(object);
        }
        return result;
    }
    function updateAvailableWidth() {
        // print(this, reservedWidth)

        let traverse = (item, depth) => {
            let width = 0;
            let acc = size => (item.disposition == GridLayout.TopToBottom) ? Math.max(width, size) : width + size;
            for (let child of item.children) {
                if (child instanceof LayoutContainer) {
                    width = acc(traverse(child, depth + 1));
                } else if (child instanceof LayoutItem) {
                    let size = child.actualWidth();
                    // print(" ".repeat(depth), child, size)
                    width = acc(size);
                } else {
                    continue;
                }
                if (item.disposition == GridLayout.LeftToRight) {
                    width += item.columnSpacing;
                }
            }
            if (item.disposition == GridLayout.LeftToRight) {
                width -= item.columnSpacing;
            }
            // print(" ".repeat(depth), item, "->", width)
            // let width = 0;
            // for (let child of item.children) {
            //     if (child.actualWidth) {
            //         let size = child.actualWidth();
            //         print(" ".repeat(depth), child, size);
            //         width = size;
            //     }
            // }
            // print(" ".repeat(depth), item, "->", width);
            return width;
        };
        let reservedWidth = traverse(grid, 0);
        root.availableWidth = width - reservedWidth;
    }
    function updateLayout() {
        // print("updateLayout", root, grid.width, availableWidth, collapsedItem.length);
        if (availableWidth >= 0 || root.editMode) {
            let currentAvailableWidth = availableWidth;
            collapsedItem.sort((a, b) => {
                // print(`  a=${a.availableWidthThreshold}\tb=${b.availableWidthThreshold}`);
                return b.availableWidthThreshold - a.availableWidthThreshold;
            });
            // print("=> collapsedItem", collapsedItem, root);
            // print("-- collapsedItem", currentAvailableWidth, collapsedItem);
            for (let i = 0; i < collapsedItem.length; i++) {
                if (currentAvailableWidth > collapsedItem[i].desiredWidth()) {
                    // print("-- collapsedItem", collapsedItem[i], collapsedItem[i].desiredWidth(), currentAvailableWidth);
                    collapsedItem[i].autoCollapsed = false;
                    currentAvailableWidth -= collapsedItem[i].desiredWidth();
                    collapsedItem.splice(i, 1);
                    i--;
                }
            }
            return;
        }
        let candidates = [];
        let traverse = (item, depth) => {
            for (let child of item.children) {
                if ((child.availableWidthThreshold != undefined && child.availableWidthThreshold >= grid.width) && !child.autoCollapsed) {
                    // print(" ".repeat(depth), "candidate", child.modelData, child.availableWidthThreshold, child.availableWidthThreshold != undefined, child, grid.width);
                    // print(" ".repeat(depth), "candidate", priority, child.priority, child.minWidth != undefined, child)
                    candidates.push(child);
                }
                if (child instanceof LayoutContainer) {
                    traverse(child, depth + 1);
                }
                // If child is marked as autoCollapsible and not expanded on request, gather priority and current width
            }
        };
        traverse(grid, 0);
        if (candidates.length == 0) {
            let [overflow, expanded] = root.computeOverflow();
            if (expanded.length > 1) {
                for (let idx = 1; idx < expanded.length; idx++) {
                    expanded[idx].collapsed = Qt.binding(() => expanded[idx].autoCollapsed);
                }
            }
            [overflow, expanded] = root.computeOverflow();
            if (overflow <= 0 && expanded.length > 0) {
                expanded[0].Layout.minimumWidth = Math.min(expanded[0].Layout.minimumWidth - overflow, expanded[0].minimumWidth);
                // print("Restore seized minWidth", overflow);
                return;
            }
            if (expanded.length == 1 && expanded[0].minimumWidth > overflow && expanded[0].fillWidth) {
                expanded[0].Layout.minimumWidth -= overflow;
            } else {
                console.error("Unable to find item to collapse!!", overflow, expanded);
            }
            return;
        }
        // print("=> candidate", candidates, root);
        candidates.sort((a, b) => {
            // TODO: Explore the candidate and pick on based on priority first, matching space (sufficient, the closest possible to what is needed)
            // print(`  a=${a.availableWidthThreshold}\tb=${b.availableWidthThreshold}`);
            return a.availableWidthThreshold - b.availableWidthThreshold;
        });
        // print("=> candidate", candidates, root);
        let neededWidth = -availableWidth;
        // print("candidates", neededWidth, candidates);
        while (candidates.length && neededWidth > 0) {
            let candidate = candidates.pop();
            candidate.autoCollapsed = true;
            neededWidth -= candidate.width - 20;
            collapsedItem.push(candidate);
            // print("-> candidate", candidate, candidate.width, neededWidth);
        }
        if (neededWidth > 0) {
            let [overflow, expanded] = root.computeOverflow();
            // if (!overflow) return;
            console.error("Still - Unable to find item to collapse!!", overflow, expanded);
            Qt.callLater(root.updateAvailableWidth);
        }
    // Save the list of item that have been hidden
    }

    Drag.dragType: Drag.Automatic
    Drag.mimeData: {
        let data = {
            "mixxx/player": group
        };
        const trackLocationUrl = currentTrack?.trackLocationUrl;
        if (trackLocationUrl)
            data["text/uri-list"] = trackLocationUrl.toString();

        return data;
    }
    Drag.supportedActions: Qt.CopyAction

    Component.onCompleted: {
        resetLayout();
    }
    onAvailableWidthChanged: root.updateLayout()
    onEditModeChanged: {
        if (editMode) {
            for (let item of collapsedItem) {
                item.autoCollapsed = false;
                item.collapsed = Qt.binding(() => item.autoCollapsed);
            }
            collapsedItem = [];
        }
        root.updateAvailableWidth();
        root.updateLayout();
    }

    Skin.SectionBackground {
        anchors.fill: parent
    }
    Mixxx.ControlProxy {
        id: trackLoadedControl

        group: root.group
        key: "track_loaded"
    }
    Skin.SectionBackground {
        anchors.fill: parent
    }
    ListModel {
        id: itemModel

        dynamicRoles: true
    }
    ListModel {
        id: minimizedItemModel

    }
    DelegateChooser {
        id: deckItemDelegate

        role: "type"

        DelegateChoice {
            roleValue: "info"

            LayoutItem {
                Layout.preferredHeight: root.minimized ? 28 : 56
                editOverlay.visible: false
                fillWidth: true

                DeckComponent.InfoBar {
                    id: infoBar

                    anchors.fill: parent
                    editMode: root.editMode
                    group: root.group
                    minimized: root.minimized
                    rightColumnWidth: 105

                    TapHandler {
                        onDoubleTapped: root.toggleFocus()
                    }
                }
            }
        }
        DelegateChoice {
            roleValue: "loop"

            LayoutItem {
                Layout.maximumWidth: 185
                editLabel.color: Theme.white
                editLabel.font.capitalization: Font.AllUppercase
                editLabel.text: "Loop"
                editOverlay.color: Theme.midGray
                fillWidth: true
                height: 92
                minimumWidth: 120
                objectName: "loop"

                DeckComponent.Loop {
                    anchors.fill: parent
                    group: root.group
                }
            }
        }
        DelegateChoice {
            roleValue: "beatjump"

            LayoutItem {
                Layout.maximumWidth: 120
                editLabel.color: Theme.white
                editLabel.font.capitalization: Font.AllUppercase
                editLabel.text: "Beatjump"
                editOverlay.color: Theme.midGray
                fillWidth: true
                height: 92
                minimumWidth: 120
                objectName: "beatjump"

                DeckComponent.BeatJump {
                    anchors.fill: parent
                    group: root.group
                }
            }
        }
        DelegateChoice {
            roleValue: "waveformOverview"

            LayoutItem {
                Layout.fillHeight: true
                blurRadius: 4
                editLabel.color: Theme.white
                editLabel.font.pixelSize: 14
                editLabel.text: "Waveform overview"
                editOverlay.color: Qt.alpha('black', 0.5)
                fillWidth: true
                objectName: "overview"

                DeckComponent.WaveformOverview {
                    anchors.fill: parent
                    currentTrack: root.currentTrack
                    group: root.group
                }
            }
        }
        DelegateChoice {
            roleValue: "fxAssign"

            LayoutItem {
                id: holder

                required property int index

                Layout.alignment: Qt.AlignHCenter
                editLabel.color: Theme.midGray
                editLabel.font.capitalization: Font.AllUppercase
                editLabel.text: "FX Assign"
                editOverlay.color: Theme.darkGray2
                implicitHeight: 35
                width: 135

                DeckComponent.FXAssign {
                    group: root.group
                }
            }
        }
        DelegateChoice {
            roleValue: "tempo"

            LayoutItem {
                Layout.fillHeight: true
                Layout.maximumWidth: 75
                blurRadius: 4
                editLabel.color: Theme.white
                editLabel.text: "Tempo"
                editOverlay.color: Qt.alpha('black', 0.5)
                minimumWidth: 65
                objectName: "rateSlider"

                DeckComponent.TempoColumn {
                    anchors.fill: parent
                    currentTrack: root.currentTrack
                    group: root.group
                }
            }
        }
        DelegateChoice {
            roleValue: "play"

            LayoutItem {
                editLabel.color: Theme.white
                editLabel.horizontalAlignment: Text.AlignHCenter
                editLabel.text: "Play\nButton"
                editOverlay.border.color: '#000000'
                editOverlay.border.width: 2
                editOverlay.color: Theme.darkGray2
                forcedMinimumWidth: true
                implicitHeight: root.minimized ? 32 : 60
                minimumWidth: 60
                objectName: "playButton"

                DeckComponent.PlayButton {
                    id: item

                    anchors.fill: parent
                    group: root.group
                    minimized: root.minimized
                }
            }
        }
        DelegateChoice {
            roleValue: "cue"

            LayoutItem {
                editLabel.color: Theme.white
                editLabel.horizontalAlignment: Text.AlignHCenter
                editLabel.text: "Cue\nButton"
                editOverlay.border.color: '#000000'
                editOverlay.border.width: 2
                editOverlay.color: Theme.darkGray2
                forcedMinimumWidth: true
                implicitHeight: root.minimized ? 32 : 60
                minimumWidth: 60
                objectName: "cueButton"

                DeckComponent.CueButton {
                    anchors.fill: parent
                    group: root.group
                    minimized: root.minimized
                }
            }
        }
        DelegateChoice {
            roleValue: "spinny"

            LayoutItem {
                Layout.alignment: Qt.AlignTop
                Layout.maximumWidth: 140
                editLabel.color: Theme.midGray
                editLabel.font.pixelSize: 14
                editLabel.text: "Spinny"
                editOverlay.color: "#BDBDBD"
                editOverlay.radius: height
                fillWidth: true
                implicitHeight: width
                minimumWidth: 140
                objectName: "spinny"

                DeckComponent.Spinny {
                    anchors.fill: parent
                    group: root.group
                }
            }
        }
        DelegateChoice {
            roleValue: "row"

            LayoutContainer {
                Layout.fillHeight: true
                disposition: GridLayout.LeftToRight
            }
        }
        DelegateChoice {
            roleValue: "column"

            LayoutContainer {
                Layout.fillWidth: true
                Layout.horizontalStretchFactor: 1
                disposition: GridLayout.TopToBottom
            }
        }
        DelegateChoice {
            roleValue: "toolbar"

            LayoutItem {
                Layout.minimumHeight: 22
                blurRadius: 4
                editLabel.color: Theme.white
                editLabel.font.pixelSize: 14
                editLabel.text: "Toolbar"
                editOverlay.color: Qt.alpha('black', 0.5)
                fillWidth: true
                objectName: "toolbar"

                DeckComponent.Toolbar {
                    anchors.fill: parent
                    group: root.group
                }
            }
        }
        DelegateChoice {
            roleValue: "hotcueAndStem"

            LayoutItem {
                blurRadius: 4
                editLabel.color: Theme.white
                editLabel.font.pixelSize: 14
                editLabel.text: "Hotcue & Stem"
                editOverlay.color: Qt.alpha('black', 0.5)
                fillWidth: true
                height: 92
                minimumWidth: 250
                objectName: "hotcueAndStem"

                DeckComponent.HotcueAndStem {
                    anchors.fill: parent
                    currentTrack: root.currentTrack
                    group: root.group
                }
            }
        }
    }
    ColumnLayout {
        id: grid

        anchors.fill: parent
        anchors.margins: 4
        visible: !root.minimized

        FadeBehavior on visible {
            fadeTarget: grid
        }

        onWidthChanged: {
            root.updateAvailableWidth();
        }

        Repeater {
            delegate: deckItemDelegate
            model: itemModel

            onItemAdded: (_, _) => {
                root.updateAvailableWidth();
                root.updateLayout();
            }
        }
    }
    ColumnLayout {
        id: minimizedGrid

        anchors.fill: parent
        anchors.margins: 4
        visible: root.minimized

        FadeBehavior on visible {
            fadeTarget: minimizedGrid
        }

        Repeater {
            delegate: deckItemDelegate
            model: minimizedItemModel
        }
    }
    Mixxx.PlayerDropArea {
        property var candidate: null

        function handleCardinalityEast(drag, modelRef, child, i, sourceIdx) {
            // print("handleCardinalityEast MOVE", JSON.stringify(drag.source.move), drag.source.beginDrag, modelRef, child, i, sourceIdx)
            let spacing = drag.source.beginDrag.x - child.x - child.width;
            child.x += drag.source.width + spacing;
            drag.source.beginDrag.x -= child.width + spacing;

            if (drag.source.move) {
                drag.source.move.child = i;
                drag.source.move.count++;
            } else {
                drag.source.move = {
                    ref: modelRef,
                    source: sourceIdx,
                    target: i,
                    count: 1
                };
            }
        }
        function handleCardinalityNorth(drag, modelRef, child, i, sourceIdx) {
            // print("handleCardinalityNorth MOVE", drag, modelRef, child, i, sourceIdx)
            let spacing = child.y - drag.source.beginDrag.y - drag.source.height;
            child.y = drag.source.beginDrag.y;
            drag.source.beginDrag.y += child.height + spacing;

            if (drag.source.move) {
                drag.source.move.source++;
            } else {
                drag.source.move = {
                    ref: modelRef,
                    source: i,
                    target: sourceIdx,
                    count: 1
                };
            }
        }
        function handleCardinalitySouth(drag, modelRef, child, i, sourceIdx) {
            // print("handleCardinalitySouth MOVE", drag, modelRef, child, i, sourceIdx)
            let spacing = drag.source.beginDrag.y - child.y - child.height;
            drag.source.beginDrag.y = child.y;
            child.y += drag.source.height + spacing;

            if (drag.source.move) {
                drag.source.move.target = i;
                drag.source.move.count++;
            } else {
                drag.source.move = {
                    ref: modelRef,
                    source: sourceIdx,
                    target: i,
                    count: 1
                };
            }
        }
        function handleCardinalityWest(drag, modelRef, child, i, sourceIdx) {
            // print("handleCardinalityWest MOVE", JSON.stringify(drag.source.move), drag.source.beginDrag, modelRef, child, i, sourceIdx)
            let spacing = child.x - drag.source.beginDrag.x - drag.source.width;
            child.x -= drag.source.width + spacing;
            drag.source.beginDrag.x += child.width + spacing;

            if (drag.source.move) {
                drag.source.move.source++;
            } else {
                drag.source.move = {
                    ref: modelRef,
                    source: i,
                    target: sourceIdx,
                    count: 1
                };
            }
        }
        function handleChild(i, child, sourceIdx, position) {
            // print("handleChild MOVE", drag.source.beginDrag, child, sourceIdx, position)
            let topParent = root.minimized ? minimizedGrid : grid;
            let itemArea = child.mapToItem(topParent, 0, 0, child.width, child.height);
            let sourceCenter = drag.source.parent.mapToItem(topParent, drag.source.beginDrag.x + drag.source.width / 2, drag.source.beginDrag.y + drag.source.height / 2);
            let actualCenter = drag.source.mapToItem(topParent, drag.source.width / 2, drag.source.height / 2);
            let currentCenter = Qt.point(itemArea.x + itemArea.width / 2, itemArea.y + itemArea.height / 2);

            let inBetween = (a, b, c) => (a < c && a < b && b <= c) || (a > c && a > b && b >= c);

            // if our center is between the beginDrag Center and the actuacenter
            // print(i, inBetween(sourceCenter.x, currentCenter.x, actualCenter.x), inBetween(sourceCenter.y, currentCenter.y, actualCenter.y))
            // if (position.x >= itemArea.x && position.x < itemArea.x + itemArea.width && position.y >= itemArea.y && position.y < itemArea.y + itemArea.height) {
            if (inBetween(sourceCenter.x, itemArea.x, actualCenter.x) || inBetween(sourceCenter.y, itemArea.y, actualCenter.y) || inBetween(sourceCenter.x, itemArea.x + itemArea.width, actualCenter.x) || inBetween(sourceCenter.y, itemArea.y + itemArea.height, actualCenter.y)) {
                // print(child, currentCenter, sourceCenter, actualCenter);

                // if (candidate == null || candidate.target != child) {
                // print("candidate", i, sourceIdx);
                let distance = Qt.point(Math.abs(sourceCenter.x - currentCenter.x), Math.abs(sourceCenter.y - currentCenter.y));

                let cardinality;
                if (distance.x >= distance.y) {
                    cardinality = sourceCenter.x > currentCenter.x ? Deck.Cardinality.East : Deck.Cardinality.West;
                } else {
                    cardinality = sourceCenter.y > currentCenter.y ? Deck.Cardinality.South : Deck.Cardinality.North;
                }
                candidate = {
                    target: child,
                    cardinality: cardinality,
                    completed: false
                };
                // }

                if (candidate.completed) {
                    return true;
                }
                // print("candidate competing", child);
                if (typeof drag.source.idxOffset == "undefined") {
                    Object.defineProperty(drag.source, "idxOffset", {
                        value: 0,
                        writable: true,
                        enumerable: true,
                        configurable: true
                    });
                }

                switch (candidate.cardinality) {
                case Deck.Cardinality.West:
                    candidate.completed = actualCenter.x + drag.source.width / 2 > currentCenter.x;
                    break;
                case Deck.Cardinality.North:
                    candidate.completed = drag.source.y + drag.source.height > currentCenter.y - parent.height / 2;
                    break;
                case Deck.Cardinality.East:
                    candidate.completed = actualCenter.x - drag.source.width / 2 < currentCenter.x;
                    break;
                case Deck.Cardinality.South:
                    candidate.completed = drag.source.y < currentCenter.y;
                    break;
                default:
                    console.error(`Unhandled cardinality value: '${candidate.cardinality}'`);
                    return true;
                }

                if (!candidate.completed) {
                    return true;
                }

                let delta = Qt.point(drag.source.beginDrag.x - child.x, drag.source.beginDrag.y - child.y);
                let currentParent = drag.source.parent;
                let reverse = [];
                while (currentParent != topParent) {
                    reverse.push(currentParent.parent.children.indexOf(currentParent));
                    currentParent = currentParent.parent;
                }
                let modelRef = root.minimized ? minimizedItemModel : itemModel;
                while (reverse.length > 0) {
                    modelRef = modelRef.get(reverse.pop()).items;
                }

                switch (candidate.cardinality) {
                case Deck.Cardinality.West:
                    handleCardinalityWest(drag, modelRef, child, i, sourceIdx);
                    drag.source.idxOffset++;
                    break;
                case Deck.Cardinality.East:
                    handleCardinalityEast(drag, modelRef, child, i, sourceIdx);
                    drag.source.idxOffset--;
                    break;
                case Deck.Cardinality.North:
                    handleCardinalityNorth(drag, modelRef, child, i, sourceIdx);
                    drag.source.idxOffset++;
                    break;
                case Deck.Cardinality.South:
                    handleCardinalitySouth(drag, modelRef, child, i, sourceIdx);
                    drag.source.idxOffset--;
                    break;
                }
                // print("candidate competed?", candidate.completed, child);
                return true;
            }
        }

        anchors.fill: parent
        group: root.group

        onEntered: {
            candidate = null;
        }
        onPositionChanged: drag => {
            if (drag.formats.includes("mixxx/player") || drag.formats.includes("text/uri-list")) {
                return;
            }

            let parentArea = drag.source.parent.mapToItem(grid, 0, 0, drag.source.parent.width, drag.source.parent.height);
            let position = Qt.point(drag.x, drag.y);
            if (position.x < parentArea.x || position.x >= parentArea.x + parentArea.width || position.y < parentArea.y || position.y > parentArea.y + parentArea.height) {
                candidate = null;
                return;
            }

            if (!drag.source.parent.itemsModel) {
                console.error(`No items list on the parent of ${drag.source} (${drag.source.parent}: ${drag.source.parent.itemsModel})`);
                candidate = null;
                return;
            }
            let sourceIdx = drag.source.parent.children.indexOf(drag.source);
            if (sourceIdx === -1) {
                console.error("Cannot find the source item in the parent's children");
                candidate = null;
                return;
            }
            let proceed = idx => {
                if (idx < 0 || idx >= drag.source.parent.children.length)
                    return false;
                let child = drag.source.parent.children[idx];
                if ((child instanceof LayoutItem) || (child instanceof LayoutContainer)) {
                    return handleChild(idx, child, drag.source.idxOffset ? sourceIdx + drag.source.idxOffset : sourceIdx, position);
                }
                return false;
            };
            // Always proceed with the closer neighbors first so the candidate range is set to the closer model item
            for (let i = 1; i < drag.source.parent.children.length; i++) {
                if (proceed(sourceIdx - i))
                    break;
                if (proceed(sourceIdx + i))
                    break;
            }
        }
    }

    component LayoutContainer: GridLayout {
        id: item

        property bool autoCollapsed: false
        property var availableWidthThreshold: typeof minWidth === 'number' ? minWidth : undefined
        property var beginDrag: null
        property bool collapsed: autoCollapsed
        property var disposition: GridLayout.TopToBottom
        property alias editOverlay: overlay
        readonly property var itemsModel: items
        property var move: null
        property bool selected: false

        function actualWidth() {
            return collapsed ? 20 : desiredWidth();
        }
        function complete() {
            if (item.move) {
                // print("LayoutContainer MOVE", item.move.ref, item.move.target, item.move.source, item.move.count);
                item.move.ref.move(item.move.target, item.move.source - item.move.count + 1, 1);
                if (item.idxOffset)
                    item.idxOffset = 0;
            }
            item.move = null;
        }

        // columnSpacing: 0
        // rowSpacing: 0

        function desiredWidth() {
            let width = 0;
            for (let child of item.children) {
                if (!child.desiredWidth)
                    continue;
                // print(" ==== desiredWidth", child, child.desiredWidth());
                width = (item.disposition == GridLayout.TopToBottom) ? Math.max(width, child.actualWidth()) : width + child.actualWidth();
                if (disposition == GridLayout.LeftToRight) {
                    width += columnSpacing;
                }
            }

            if (disposition == GridLayout.LeftToRight) {
                width -= columnSpacing;
            }
            // print(" ==== desiredWidth", width);
            return width;
        }

        Drag.active: mouseArea.drag.active
        Drag.hotSpot: Qt.point(width / 2, height / 2)
        Layout.minimumHeight: item.collapsed ? 20 : -1
        Layout.minimumWidth: item.collapsed ? 20 : -1
        columns: disposition == GridLayout.TopToBottom ? 1 : itemsModel?.rowCount() ?? 0

        // Temporary disabling - need a way to detect item once they have moved for a given cardinality, to allow moving back o the same drag
        // Current system allows either animation but no move back, or glitching moves
        // Behavior on x {
        //     SpringAnimation {
        //         id: xAnimation

        //         damping: 0.2
        //         duration: 50
        //         spring: 2

        //         onRunningChanged: {
        //             if (running)
        //                 return;
        //             item.complete();
        //         }
        //     }
        // }
        // Behavior on y {
        //     SpringAnimation {
        //         id: yAnimation

        //         damping: 0.2
        //         duration: 50
        //         spring: 2

        //         onRunningChanged: {
        //             if (running)
        //                 return;
        //             item.complete();
        //         }
        //     }
        // }

        // Layout.fillWidth: !content.active || fillWidth
        // Layout.horizontalStretchFactor: content.active || root.editMode ? Layout.fillWidth ? 5 : -1 : 1

        onCollapsedChanged: {
            // print("== onCollapsedChanged", repeater.count);
            for (let idx = 0; idx < repeater.count; idx++) {
                let child = repeater.itemAt(idx);
                // print("== onCollapsedChanged", collapsed, child.visible);
                child.visible = !collapsed;
            }
        }

        Repeater {
            id: repeater

            delegate: deckItemDelegate
            model: items

            onItemAdded: (_, _) => {
                root.updateAvailableWidth();
                root.updateLayout();
            }
        }
        Rectangle {
            Layout.fillHeight: true
            color: Qt.alpha(Theme.deckLoopBackgroundColor, 0.6)
            visible: item.collapsed
            width: 20

            // Label {
            //     id: collapsedLabel
            //     color: Theme.white
            //     width: rotation ? item.height : layoutItem.width - 20
            //     anchors.centerIn: parent
            //     text: labelItem.text
            //     wrapMode: Text.Wrap
            //     horizontalAlignment: Text.AlignHCenter
            //     rotation: collapseFontMetrics.advanceWidth(labelItem.text) > layoutItem.width - 20 ? 90 : 0
            //     transformOrigin: Item.Center
            //     FontMetrics {
            //         id: collapseFontMetrics
            //         font: collapsedLabel.font
            //     }
            // }
            Shape {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                antialiasing: true
                height: 12
                width: 12

                ShapePath {
                    fillColor: '#2B2B2B'
                    startX: 2
                    startY: 7
                    strokeColor: 'transparent'

                    PathLine {
                        x: 6
                        y: 3
                    }
                    PathLine {
                        x: 6
                        y: 11
                    }
                }
            }
            Shape {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                antialiasing: true
                height: 12
                width: 12

                ShapePath {
                    fillColor: '#2B2B2B'
                    startX: 6
                    startY: 3
                    strokeColor: 'transparent'

                    PathLine {
                        x: 11
                        y: 6
                    }
                    PathLine {
                        x: 6
                        y: 11
                    }
                }
            }
            TapHandler {
                enabled: item.collapsed

                onTapped: expandItem(item)
            }
        }
        Rectangle {
            id: overlay

            color: Qt.alpha(Theme.accentColor, 0.2)
            height: item.height
            objectName: visible ? "selectedGroupOverlay" : "groupOverlay"
            parent: root
            visible: root.editMode && selected
            width: item.width
            x: {
                visible + root.width + root.height + item.x + item.y; // Geometry binding
                let overlayRect = item.mapToItem(root, 0, 0);
                return overlayRect.x;
            }
            y: {
                visible + root.width + root.height + item.x + item.y; // Geometry binding
                let overlayRect = item.mapToItem(root, 0, 0);
                return overlayRect.y;
            }

            LayoutMouseArea {
                id: mouseArea

                anchors.fill: parent
                drag.target: item
                target: item

                Connections {
                    function onActiveChanged() {
                        if (mouseArea.drag.active)
                            return;
                        item.complete();
                    }

                    target: mouseArea.drag
                }
            }
        }
    }
    component LayoutItem: Item {
        id: layoutItem

        property bool autoCollapsed: false
        property var availableWidthThreshold: typeof minWidth === 'number' ? minWidth : undefined
        property var beginDrag: null
        property int blurRadius: 0
        property bool collapsed: autoCollapsed
        default property var contentChildren
        property alias editLabel: labelItem
        property alias editOverlay: overlayItem
        property bool fillWidth: false
        property bool forcedMinimumWidth: false
        property alias innerItem: content
        property int minimumWidth: -1
        property var move: null
        property int preferredWidth: -1

        function actualWidth() {
            return collapsed ? 20 : desiredWidth();
        }
        function complete() {
            if (layoutItem.move) {
                // print("LayoutContainer MOVE", layoutItem.move.ref, layoutItem.move.target, layoutItem.move.source, layoutItem.move.count);
                layoutItem.move.ref.move(layoutItem.move.target, layoutItem.move.source - layoutItem.move.count + 1, 1);
                if (layoutItem.idxOffset)
                    layoutItem.idxOffset = 0;
            }
            layoutItem.move = null;
        }
        function desiredWidth() {
            return minimumWidth > 0 ? minimumWidth : implicitWidth > 0 ? implicitWidth : 0;
        }

        Drag.active: mouseArea.drag.active
        Drag.hotSpot: Qt.point(width / 2, height / 2)
        Layout.fillWidth: !content.active || fillWidth
        Layout.horizontalStretchFactor: content.active || root.editMode ? Layout.fillWidth ? 5 : -1 : 1
        Layout.minimumWidth: forcedMinimumWidth || (content.active && !root.editMode) ? minimumWidth : 20
        Layout.preferredWidth: content.active ? preferredWidth : 20
        clip: true

        // Behavior on x {
        //     SpringAnimation {
        //         id: xAnimation

        //         damping: 0.2
        //         duration: 50
        //         spring: 2

        //         onRunningChanged: {
        //             if (running)
        //                 return;
        //             layoutItem.complete();
        //         }
        //     }
        // }
        // Behavior on y {
        //     SpringAnimation {
        //         id: yAnimation

        //         damping: 0.2
        //         duration: 50
        //         spring: 2

        //         onRunningChanged: {
        //             if (running)
        //                 return;
        //             layoutItem.complete();
        //         }
        //     }
        // }

        onCollapsedChanged: {
            // if (!autoCollapsed) return
            // Reset overwritten size
            Layout.minimumWidth = Qt.binding(() => content.active && !root.editMode ? minimumWidth : 20);
        }
        onWidthChanged: {
            if (Layout.maximumWidth == Infinity)
                return;
            // print("onWidthChanged", Layout.maximumWidth, implicitWidth, width, collapsed)
            if (Layout.maximumWidth <= width && collapsed) {
                collapsed = false;
                root.collapsedItem.splice(root.collapsedItem.indexOf(layoutItem), 1);
            }
        }

        Loader {
            id: content

            active: !collapsed
            anchors.fill: layoutItem

            sourceComponent: Component {
                Item {
                    children: layoutItem.contentChildren
                }
            }
        }
        Rectangle {
            anchors.fill: layoutItem
            color: Qt.alpha(Theme.deckLoopBackgroundColor, 0.6)
            visible: !content.active && !root.editMode

            Label {
                id: collapsedLabel

                anchors.centerIn: parent
                color: Theme.white
                horizontalAlignment: Text.AlignHCenter
                rotation: collapseFontMetrics.advanceWidth(labelItem.text) > layoutItem.width - 20 ? 90 : 0
                text: labelItem.text
                transformOrigin: Item.Center
                width: rotation ? layoutItem.height : layoutItem.width - 20
                wrapMode: Text.Wrap

                FontMetrics {
                    id: collapseFontMetrics

                    font: collapsedLabel.font
                }
            }
            Shape {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                antialiasing: true
                height: 12
                width: 12

                ShapePath {
                    fillColor: '#2B2B2B'
                    startX: 2
                    startY: 7
                    strokeColor: 'transparent'

                    PathLine {
                        x: 6
                        y: 3
                    }
                    PathLine {
                        x: 6
                        y: 11
                    }
                }
            }
            Shape {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                antialiasing: true
                height: 12
                width: 12

                ShapePath {
                    fillColor: '#2B2B2B'
                    startX: 6
                    startY: 3
                    strokeColor: 'transparent'

                    PathLine {
                        x: 11
                        y: 6
                    }
                    PathLine {
                        x: 6
                        y: 11
                    }
                }
            }
            TapHandler {
                enabled: layoutItem.collapsed

                onTapped: expandItem(layoutItem)
            }
        }
        MultiEffect {
            anchors.fill: layoutItem
            blur: root.editMode ? Math.min(1, layoutItem.blurRadius / 16) : 0
            source: content
            visible: root.editMode
        }
        Rectangle {
            id: overlayItem

            anchors.fill: layoutItem
            clip: true
            color: Qt.alpha("black", 0.4)
            objectName: "overlayItem"
            visible: root.editMode
            z: 90

            FadeBehavior on visible {
                fadeTarget: overlayItem
            }

            Text {
                id: labelItem

                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                visible: !!text.length
                wrapMode: Text.Wrap
            }
            LayoutMouseArea {
                id: mouseArea

                // enabled: overlayItem.visible
                anchors.fill: overlayItem
                drag.target: layoutItem
                target: layoutItem

                Connections {
                    function onActiveChanged() {
                        if (mouseArea.drag.active)
                            return;
                        layoutItem.complete();
                    }

                    target: mouseArea.drag
                }
            }
            Skin.Button {
                anchors.margins: 4
                anchors.right: parent.right
                anchors.top: parent.top
                implicitHeight: 18
                implicitWidth: implicitHeight
                visible: !!layoutItem?.parent?.parent?.itemsModel?.count

                contentItem: Item {
                    BinIcon {
                        anchors.centerIn: parent

                        transform: Scale {
                            xScale: 0.75
                            yScale: 0.75
                        }
                    }
                }

                onPressed: {
                    if (layoutItem.parent.itemsModel.count == 1) {
                        // If last child, just delete parent
                        // FIXME need to be recursive?
                        // print("layoutItem.parent.parent", layoutItem.parent.parent, layoutItem.parent.parent.itemsModel);
                        layoutItem.parent.parent.itemsModel.remove(layoutItem.parent.parent.children.indexOf(layoutItem.parent));
                    } else {
                        // Otherwise just the current child
                        layoutItem.parent.itemsModel.remove(layoutItem.parent.children.indexOf(layoutItem));
                    }
                }
            }
        }
    }
    component LayoutMouseArea: MouseArea {
        property Item target: parent

        function selectParent() {
            let current = target;
            let currentlySelected = 0;
            let nestedGroups = [];
            while (current != root) {
                if (current instanceof LayoutContainer) {
                    nestedGroups.push(current);
                    if (current.selected && !currentlySelected) {
                        currentlySelected = nestedGroups.length;
                    }
                }
                current = current.parent;
            }
            for (let i = 0; i < currentlySelected; i++) {
                nestedGroups[i].selected = false;
            }
            nestedGroups[currentlySelected].selected = true;
        }

        preventStealing: true

        onPressAndHold: () => {
            selectParent();
            if (!target.beginDrag) {
                target.beginDrag = Qt.point(target.x, target.y);
            }
            target.z = 100;
        }
        onPressed: event => {
            if (event.modifiers & Qt.ControlModifier) {
                selectParent();
            }

            if (!target.beginDrag) {
                target.beginDrag = Qt.point(target.x, target.y);
            }
            target.z = 100;
        }
        onReleased: event => {
            if (target.beginDrag) {
                target.x = target.beginDrag.x;
                target.y = target.beginDrag.y;
                target.beginDrag = null;
            }
            if (!(event.modifiers & Qt.ControlModifier) && target.selected) {
                target.selected = false;
            }

            target.z = 1;
        }
    }
}
