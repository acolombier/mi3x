import ".." as Skin
import "." as LibraryComponent
import Mixxx 1.0 as Mixxx
import Qt.labs.qmlmodels
import QtQml
import QtQuick
import QtQml.Models
import QtQuick.Layouts
import QtQuick.Controls 2.15
import "../Theme"

Rectangle {
    id: root

    // Display labels of every column in model order, as a JSON array. Exposed
    // for the E2E test harness: unlike a header delegate, this also covers
    // columns that are hidden and therefore have no delegate to read ``index``
    // from.
    readonly property string columnLabels: {
        if (!root.sidebar) {
            return "[]";
        }
        const columns = root.sidebar.tracklist?.columns;
        let labels = [];
        for (let i = 0; i < columns?.length; i++) {
            labels.push(columns[i].label);
        }
        return JSON.stringify(labels);
    }
    property bool columnRestorePending: false
    // Disable the dynamic column width provider and force computation based on an arbitrary width. This can be useful to temporary limit layout recomputation, for example during a transitional state such as animation
    property int inhibitColumnWidth: 0
    required property var model
    property var movedColumn: new Object()
    property var sidebar: model.sidebar
    readonly property alias view: view
    property bool viewStateApplyScheduled: false
    property bool viewStateRestorePending: false

    function applyColumnOrder(order) {
        view.clearColumnReordering();
        root.movedColumn = new Object();
        let current = [];
        for (let i = 0; i < order.length; i++)
            current.push(i);
        for (let target = 0; target < order.length; target++) {
            const logical = order[target];
            const from = current.indexOf(logical);
            if (from < 0 || from === target)
                continue;
            view.moveColumn(from, target);
            current.splice(from, 1);
            current.splice(target, 0, logical);
        }
    }
    function applyColumnState(state) {
        if (!view.model)
            return;
        const columns = view.model.columns;
        const savedColumns = state?.columns ?? [];
        let persisted = [];
        for (let i = 0; i < columns.length; i++) {
            const saved = savedColumns[columns[i].persistenceKey];
            if (!saved)
                continue;
            persisted.push({
                "logical": i,
                "visual": saved.index
            });
        }
        persisted.sort((a, b) => a.visual - b.visual);
        let order = persisted.map(entry => entry.logical);
        for (let i = 0; i < columns.length; i++) {
            if (!order.includes(i))
                order.push(i);
        }
        root.applyColumnOrder(order);
        // Explicit widths outlive model changes, so clear any width inherited
        // from another library source before restoring this source's state.
        view.clearColumnWidths();
        view.cachedColumnWidth = Object();
        for (let i = 0; i < view.model.columns.length; i++) {
            const column = view.getColumn(i);
            if (!column)
                continue;
            const columnState = savedColumns[column.persistenceKey];
            if (!columnState)
                continue;
            if (columnState.width !== undefined) {
                view.setColumnWidth(i, columnState.width);
            }
            column.display = columnState.display;
        }
        view.forceLayout();
    }
    function applyDeferredViewState() {
        viewStateApplyScheduled = false;
        if (!viewStateRestorePending || columnRestorePending || !view.model)
            return;
        const state = view.model.loadState(view.model.objectName);
        if (root.applyViewState(state))
            viewStateRestorePending = false;
    }
    function applySort() {
        if (!view?.model || horizontalHeader.sortingColumn < 0)
            return;
        view.model.sort(horizontalHeader.sortingColumn, horizontalHeader.sortingOrder);
    }
    function applyViewState(state) {
        if (!view.model || !view.selectionModel)
            return false;
        const selectionModel = view.selectionModel;
        if (selectionModel.model !== view.model)
            return false;
        const rowCount = view.model.rowCount();
        let savedSelections = [];
        if (state?.selections !== undefined && state?.selections !== null)
            savedSelections = Array.from(state.selections);
        savedSelections = savedSelections.filter(row => row >= 0 && row < rowCount);
        let currentRow = state?.currentRow ?? -1;
        if (!(currentRow >= 0 && currentRow < rowCount))
            currentRow = savedSelections.length > 0 ? savedSelections[0] : -1;
        selectionModel.clear();
        if (currentRow >= 0) {
            selectionModel.select(view.model.index(currentRow, 0), ItemSelectionModel.Rows | ItemSelectionModel.Select | ItemSelectionModel.Clear | ItemSelectionModel.Current);
        }
        for (const row of savedSelections) {
            if (row === currentRow)
                continue;
            selectionModel.select(view.model.index(row, 0), ItemSelectionModel.Rows | ItemSelectionModel.Select);
        }
        const savedTopRow = state?.topRow;
        if (savedTopRow >= 0 && rowCount > 0) {
            const topRow = Math.min(savedTopRow, rowCount - 1);
            view.positionViewAtRow(topRow, TableView.AlignTop);
        }
        return true;
    }
    function columnState() {
        let columns = {};
        if (view.model) {
            for (let i = 0; i < view.model.columns.length; i++) {
                const column = view.getColumn(i);
                if (!column)
                    continue;
                const explicitWidth = view.explicitColumnWidth(i);
                columns[column.persistenceKey] = {
                    "index": i,
                    "display": column.display,
                    "width": explicitWidth
                };
            }
        }
        let selections = [];
        let currentRow = -1;
        if (view.selectionModel) {
            for (const index of view.selectionModel.selectedIndexes) {
                if (!selections.includes(index.row))
                    selections.push(index.row);
            }
            selections.sort((a, b) => a - b);
            currentRow = view.selectionModel.currentIndex.row;
            if (currentRow < 0 && selections.length > 0)
                currentRow = selections[0];
        }
        return {
            "columns": columns,
            "selections": selections,
            "currentRow": currentRow,
            "topRow": view.topRow
        };
    }

    // Restore the library columns to their default order, width and visibility
    // state. Used by the E2E test harness to reset state between scenarios
    // that share a running Mixxx instance, without a full QML reload.
    function resetColumns() {
        view.clearColumnReordering();
        root.movedColumn = new Object();
        for (let i = 0; i < view.model.columns.length; i++) {
            const data = view.getColumn(i);
            view.setColumnWidth(i, data.preferredWidth);
            data.display = Mixxx.TrackListColumn.Display.Auto;
        }
        view.forceLayout();
    }
    function restoreState() {
        if ((!columnRestorePending && !viewStateRestorePending) || !view.model)
            return;
        const state = view.model.loadState(view.model.objectName);
        const columnCount = view.model.columns.length;
        if (columnRestorePending && view.columns > 0 && view.columns === columnCount) {
            columnRestorePending = false;
            root.applyColumnState(state);
        }
        if (viewStateRestorePending && !columnRestorePending) {
            const rowCount = view.model.rowCount();
            const savedTopRow = state?.topRow ?? 0;
            const topRow = rowCount > 0 ? Math.min(Math.max(savedTopRow, 0), rowCount - 1) : 0;
            const rowsReady = rowCount === 0 || (view.rows > topRow && view.isRowLoaded(view.topRow));
            if (rowsReady && !viewStateApplyScheduled) {
                viewStateApplyScheduled = true;
                Qt.callLater(root.applyDeferredViewState);
            }
        }
    }
    function saveState() {
        if (view.model)
            view.model.saveState(view.model.objectName, root.columnState());
    }
    function scheduleColumnRestore() {
        columnRestorePending = true;
        viewStateRestorePending = true;
        Qt.callLater(root.restoreState);
    }

    // Title, artist, BPM, key text and location of the track model row as a
    // JSON object string, for the E2E test harness
    function trackDataForRow(row) {
        const track = view.model ? view.model.getTrackByRow(row) : null;
        if (!track) {
            return "{}";
        }
        return JSON.stringify({
            title: track.title,
            artist: track.artist,
            bpm: Math.round(track.bpm),
            key: track.keyText,
            location: track.trackLocationUrl.toString().replace(/^file:\/\//, "")
        });
    }

    // Displayed title of the track model row, for the E2E test harness
    function trackTitleForRow(row) {
        const track = view.model ? view.model.getTrackByRow(row) : null;
        return track ? track.title : "";
    }

    color: Theme.darkGray
    objectName: "trackList"

    Component.onCompleted: root.scheduleColumnRestore()
    Component.onDestruction: root.saveState()
    onInhibitColumnWidthChanged: {
        if (!inhibitColumnWidth)
            view.forceLayout();
        view.cachedColumnWidth = Object();
    }

    Connections {
        function onTracklistAboutToChange(model) {
            if (view.model === model)
                root.saveState();
        }

        target: root.sidebar
    }
    Mixxx.ControlProxy {
        id: librarySortColumnCO

        group: "[Library]"
        key: "sort_column"
    }
    Mixxx.ControlProxy {
        id: librarySortOrderCO

        group: "[Library]"
        key: "sort_order"
    }
    Menu {
        id: columnSelectionMenu

        contentItem.objectName: "columnPickerMenu"

        MenuItem {
            implicitHeight: 25
            text: "Reset layout"

            onTriggered: {
                root.resetColumns();
            }
        }
        MenuSeparator {
        }
        Instantiator {
            property int readyCount: 0

            model: root.sidebar.tracklist?.columns

            delegate: MenuItem {
                required property var index

                implicitHeight: 25

                contentItem: CheckBox {
                    property var data: view.getColumn(index)

                    checked: (!view.columnShouldAutoHide(data) || data?.display == Mixxx.TrackListColumn.Display.Show) && data?.display != Mixxx.TrackListColumn.Display.Hide
                    implicitHeight: 20
                    text: data?.label ? qsTr(data?.label) : ""

                    Keys.onDownPressed: {
                        columnSelectionMenu.currentIndex = Mixxx.MathUtils.positiveModulo(columnSelectionMenu.currentIndex + 1, columnSelectionMenu.count);
                        columnSelectionMenu.forceActiveFocus();
                    }
                    Keys.onSpacePressed: checked = !checked
                    Keys.onUpPressed: {
                        columnSelectionMenu.currentIndex = Mixxx.MathUtils.positiveModulo(columnSelectionMenu.currentIndex - 1, columnSelectionMenu.count);
                        columnSelectionMenu.forceActiveFocus();
                    }
                    onCheckedChanged: {
                        if (!columnSelectionMenu.opened)
                            return;
                        if (!view.columnShouldAutoHide(data) === checked) {
                            data.display = Mixxx.TrackListColumn.Display.Auto;
                        } else {
                            data.display = checked ? Mixxx.TrackListColumn.Display.Show : Mixxx.TrackListColumn.Display.Hide;
                        }
                        let currentExplicitWidth = view.explicitColumnWidth(index);
                        if (data.display == Mixxx.TrackListColumn.Display.Hide) {
                            if (currentExplicitWidth > 0) {
                                data.preferredWidth = currentExplicitWidth;
                            }
                            view.setColumnWidth(index, 0);
                        } else if (data.display != Mixxx.TrackListColumn.Display.Hide) {
                            view.setColumnWidth(index, data.preferredWidth);
                        }
                        view.forceLayout();
                    }

                    indicator {
                        implicitHeight: 14
                        implicitWidth: 14
                    }
                }

                onActiveFocusChanged: {
                    if (activeFocus) {
                        contentItem.forceActiveFocus();
                    }
                }
                onTriggered: {
                    contentItem.checked = !contentItem.checked;
                }
            }

            onObjectAdded: (index, object) => {
                if (readyCount >= root.sidebar.tracklist?.columns.length)
                    return;
                readyCount += 1;
            }
            onObjectRemoved: (index, object) => {
                if (readyCount <= 0)
                    return;
                readyCount -= 1;
            }
            onReadyCountChanged: {
                if (readyCount !== root.sidebar.tracklist?.columns.length)
                    return;
                for (let action = columnSelectionMenu.itemAt(2); action; action = columnSelectionMenu.itemAt(2)) {
                    columnSelectionMenu.removeItem(action);
                }
                for (let i = 0; i < readyCount; i++) {
                    columnSelectionMenu.insertItem(2 + i, objectAt(i));
                }
            }
        }
        Connections {
            function onColumnMoved(logicalId, oldId, newId) {
                let previousName = columnSelectionMenu.actionAt(logicalId).data.label;
                columnSelectionMenu.actionAt(newId).data = view.model.columns[logicalId];
            }

            target: view
        }
    }
    HorizontalHeaderView {
        id: horizontalHeader

        readonly property int sortingColumn: {
            for (let i = 0; i < root.sidebar.tracklist?.columns.length; i++) {
                let columns = view.getColumn(i);
                if (columns.sortColumn == librarySortColumnCO.value)
                    return i;
            }
            return -1;
        }
        readonly property var sortingOrder: librarySortOrderCO.value == 1 ? Qt.AscendingOrder : Qt.DescendingOrder

        anchors.left: parent.left
        anchors.margins: 5
        anchors.right: parent.right
        anchors.top: parent.top
        clip: true
        movableColumns: true
        objectName: "columnHeader"
        syncView: view

        delegate: Item {
            id: column

            required property string display
            required property int index
            readonly property var spec: view.getColumn(index)

            implicitHeight: columnName.contentHeight + 5
            implicitWidth: columnName.contentWidth + 5
            objectName: display

            TapHandler {
                acceptedButtons: Qt.LeftButton

                onLongPressed: {
                    columnSelectionMenu.popup(root);
                }
                onTapped: {
                    let column = view.getColumn(index);
                    if (librarySortColumnCO.value == column.sortColumn) {
                        librarySortOrderCO.value = !librarySortOrderCO.value;
                    } else {
                        librarySortOrderCO.value = 1;
                        librarySortColumnCO.value = column.sortColumn;
                    }
                }
            }
            TapHandler {
                acceptedButtons: Qt.RightButton

                onTapped: (eventPoint, button) => {
                    columnSelectionMenu.popup(root, parent.mapToItem(root, eventPoint.position));
                }
            }
            Text {
                id: columnName

                anchors.fill: parent
                anchors.leftMargin: 15
                color: Theme.textColor
                elide: Text.ElideRight
                font.capitalization: Font.Capitalize
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignLeft
                text: column.spec?.columnType == Mixxx.TrackListColumn.ColumnType.AlbumArt ? "" : display
                verticalAlignment: Text.AlignVCenter
            }
            Item {
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    leftMargin: 8
                    top: parent.top
                }
                Label {
                    id: sortIndicator

                    anchors.centerIn: parent
                    color: "red"
                    elide: Text.ElideRight
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.buttonFontPixelSize
                    horizontalAlignment: Text.AlignRight
                    rotation: horizontalHeader.sortingOrder == Qt.AscendingOrder ? 90 : -90
                    text: "▶"
                    verticalAlignment: Text.AlignVCenter
                    visible: horizontalHeader.sortingColumn == index
                }
            }
            Rectangle {
                id: columnResizer

                color: Theme.darkGray2
                width: 1

                anchors {
                    bottom: parent.bottom
                    right: parent.right
                    top: parent.top
                }
                MouseArea {
                    id: columnResizeHandler

                    anchors.fill: parent
                    cursorShape: Qt.SizeHorCursor
                    preventStealing: true

                    onMouseXChanged: {
                        if (drag.active) {
                            column.width += mouseX;
                            view.setColumnWidth(index, column.width);
                        }
                    }

                    drag {
                        axis: Drag.XAxis
                        target: parent
                        threshold: 2
                    }
                }
            }
        }

        onSortingColumnChanged: root.applySort()
        onSortingOrderChanged: root.applySort()
    }
    LibraryComponent.DragChip {
        anchors.fill: view
        view: root.view
    }
    TableView {
        id: view

        property var cachedColumnWidth: Object()
        property var contextMenu: LibraryComponent.ContextMenu {
            capabilities: root.sidebar.tracklist ? root.sidebar.tracklist.getCapabilities() : Mixxx.LibraryTrackListModel.Capability.None
            crates: root.model.crate
            playlists: root.model.playlist
            view: root.view
        }
        readonly property var dragThreshold: 20

        function columnShouldAutoHide(column, viewWidth) {
            return column?.display == Mixxx.TrackListColumn.Display.Auto && column?.autoHideWidth > 0 && column?.autoHideWidth > (viewWidth ?? root.width);
        }

        // E2E test function
        function currentlyActiveModel() {
            return view.model.sourceModel.objectName;
        }
        function getColumn(index) {
            return model.columns[root.movedColumn[index] !== undefined ? root.movedColumn[index] : index];
        }
        function innerColumnWidthProvider(column, viewWidth) {
            const columnDef = getColumn(column);
            let explicitWidth = explicitColumnWidth(column);
            if (explicitWidth == -1) {
                explicitWidth = columnDef.preferredWidth;
            }
            if (columnDef.display == Mixxx.TrackListColumn.Display.Hide || view.columnShouldAutoHide(columnDef, viewWidth)) {
                return 0;
            }
            if (explicitWidth != -1) {
                return explicitWidth;
            }
            if (model == null) {
                return 0;
            }

            let usedWidth = 0;
            let dynamicColumnCount = 0;
            for (let c = 0; c < model.columns.length; c++) {
                const columnDef = getColumn(c);
                if (columnDef.display == Mixxx.TrackListColumn.Display.Hide || view.columnShouldAutoHide(columnDef, viewWidth)) {
                    continue;
                }
                let explicitWidth = explicitColumnWidth(c);
                if (explicitWidth == -1) {
                    explicitWidth = columnDef.preferredWidth;
                }

                if (explicitWidth >= 0) {
                    usedWidth += explicitWidth;
                } else if (explicitWidth != 0) {
                    dynamicColumnCount += columnDef.fillSpan || 1;
                }
            }
            const span = columnDef.fillSpan || 1;
            return span * (viewWidth - usedWidth) / dynamicColumnCount;
        }
        function loadSelectedTrack(group, play) {
            const urls = this.selectionModel.selectedTrackUrls();
            if (urls.length == 0)
                return;

            Mixxx.PlayerManager.getPlayer(group).loadTrackFromLocationUrl(urls[0], play);
        }
        function loadSelectedTrackIntoNextAvailableDeck(play) {
            const urls = this.selectionModel.selectedTrackUrls();
            if (urls.length == 0)
                return;

            Mixxx.PlayerManager.loadLocationUrlIntoNextAvailableDeck(urls[0], play);
        }

        // Only allow library scrolling with a drag on touchscreen
        acceptedButtons: Qt.NoButton
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 5
        anchors.right: parent.right
        anchors.top: horizontalHeader.bottom
        clip: true
        columnWidthProvider: function (column) {
            if (root.inhibitColumnWidth > 0) {
                if (view.cachedColumnWidth[column] === undefined) {
                    view.cachedColumnWidth[column] = innerColumnWidthProvider(column, root.inhibitColumnWidth);
                }
                return view.cachedColumnWidth[column];
            }
            return innerColumnWidthProvider(column, view.width);
        }
        keyNavigationEnabled: false
        model: root.sidebar.tracklist
        objectName: "trackTableView"
        pointerNavigationEnabled: false
        reuseItems: true
        rowHeightProvider: () => 30
        selectionBehavior: TableView.SelectRows

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AlwaysOn
        }
        delegate: DelegateChooser {
            role: "columnType"

            DelegateChoice {
                roleValue: Mixxx.TrackListColumn.ColumnType.AlbumArt

                Rectangle {
                    required property url cover_art
                    required property color decoration

                    color: decoration
                    implicitHeight: 30

                    Image {
                        anchors.fill: parent
                        asynchronous: true
                        clip: true
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        source: cover_art
                    }
                }
            }
            DelegateChoice {
                roleValue: Mixxx.TrackListColumn.ColumnType.Overview

                Mixxx.WaveformOverview {
                    id: waveformOverview

                    channels: Mixxx.WaveformOverview.Channels.LeftChannel
                    colorHigh: Theme.white
                    colorLow: Theme.green
                    colorMid: Theme.blue
                    implicitHeight: 30
                    implicitWidth: 30
                    renderer: Mixxx.WaveformOverview.Renderer.Filtered
                    trackId: track_id
                    // FIXME we need a way to cancel ongoing request when the item gets pooled
                }
            }
            DelegateChoice {
                Cell {
                    color: selected ? Theme.accentColor : (row % 2 == 0 ? Theme.sunkenBackgroundColor : Theme.backgroundColor)
                    objectName: "trackRow_" + row
                    view: TableView.view

                    // Pooled items remains parented and set with their previous property, meaning
                    // that Spix, used for testing, may accidentally picked a pooled, now stale item.
                    TableView.onPooled: {
                        objectName = "";
                    }
                    TableView.onReused: {
                        objectName = Qt.binding(() => "trackRow_" + row);
                    }

                    Text {
                        anchors.fill: parent
                        color: Theme.textColor
                        elide: Text.ElideRight
                        font.pixelSize: 14
                        text: display ?? ""
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
        selectionModel: ItemSelectionModel {
            function moveSelectionVertical(value) {
                if (value == 0)
                    return;

                const selected = this.selectedIndexes;
                const oldRow = (selected.length == 0) ? 0 : selected[0].row;
                this.selectRow(oldRow + value);
            }
            function scrollSelectionVertical(value) {
                if (value == 0)
                    return;

                const nb_row_per_page = parseInt(view.height / view.rowHeightProvider());
                this.moveSelectionVertical(nb_row_per_page * value);
            }
            function selectRow(row, modifiers) {
                const rowCount = this.model.rowCount();
                if (rowCount == 0) {
                    this.clear();
                    return;
                }
                const newRow = Mixxx.MathUtils.positiveModulo(row, rowCount);
                const currentRows = Array.from(new Set(selectedIndexes.map(i => i.row)));
                const newIndex = this.model.index(newRow, 0);

                let flags = ItemSelectionModel.Rows;
                if (!modifiers) {
                    flags |= ItemSelectionModel.Select | ItemSelectionModel.Clear | ItemSelectionModel.Current;
                } else if (modifiers & Qt.ControlModifier) {
                    flags |= this.isSelected(newIndex) ? ItemSelectionModel.Deselect : ItemSelectionModel.Select;
                }
                if (!(modifiers & Qt.ShiftModifier) || currentRows.length == 0) {
                    this.select(newIndex, flags);
                } else {
                    if (Math.max(...currentRows) < newRow) {
                        for (let i = Math.max(...currentRows) + 1; i <= newRow; i++) {
                            const newIndex = this.model.index(i, 0);
                            this.select(newIndex, ItemSelectionModel.Rows | ItemSelectionModel.Select);
                        }
                    } else {
                        for (let i = Math.max(...currentRows); i >= newRow; i--) {
                            const newIndex = this.model.index(i, 0);
                            this.select(newIndex, ItemSelectionModel.Rows | ItemSelectionModel.Select);
                        }
                    }
                }
                if (!view.isRowLoaded(newRow)) {
                    view.positionViewAtRow(newRow, TableView.Visible | TableView.AlignVCenter);
                }
            }
            function selectedFirstTrack() {
                if (!selectedIndexes)
                    return null;
                return this.model.getTrackByRow(selectedIndexes[0].row);
            }
            function selectedTrackUrls() {
                return this.selectedIndexes.map(index => {
                    return this.model.getUrl(index.row);
                });
            }
            function selectedTracks() {
                return Array.from(new Set(selectedIndexes.map(i => i.row))).map(row => this.model.getTrackByRow(row));
            }

            model: view.model
            objectName: "selectionModel"

            onModelChanged: {
                if (root.viewStateRestorePending)
                    root.restoreState();
            }
        }

        Keys.onDownPressed: this.selectionModel.moveSelectionVertical(1)
        Keys.onEnterPressed: this.loadSelectedTrackIntoNextAvailableDeck(false)
        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_PageUp:
                this.selectionModel.scrollSelectionVertical(-1);
                break;
            case Qt.Key_PageDown:
                this.selectionModel.scrollSelectionVertical(1);
                break;
            }
        }
        Keys.onReturnPressed: this.loadSelectedTrackIntoNextAvailableDeck(false)
        Keys.onUpPressed: this.selectionModel.moveSelectionVertical(-1)
        onColumnMoved: (logicalIndex, oldVisualIndex, newVisualIndex) => {
            let order = [];
            const columnCount = view.model ? view.model.columns.length : 0;
            for (let i = 0; i < columnCount; i++)
                order.push(root.movedColumn[i] !== undefined ? root.movedColumn[i] : i);
            let from = order.indexOf(logicalIndex);
            if (from < 0)
                from = oldVisualIndex;
            if (from < 0 || from >= order.length)
                return;
            order.splice(from, 1);
            order.splice(newVisualIndex, 0, logicalIndex);
            const movedColumn = new Object();
            for (let i = 0; i < order.length; i++)
                movedColumn[i] = order[i];
            root.movedColumn = movedColumn;
        }
        onColumnsChanged: root.restoreState()
        onLayoutChanged: root.restoreState()
        onModelChanged: {
            root.scheduleColumnRestore();
            root.applySort();
        }
        onRowsChanged: root.restoreState()

        TapHandler {
            onTapped: {
                view.forceActiveFocus();
            }
        }
    }
}
