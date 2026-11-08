import "." as Skin
import Mixxx 1.0 as Mixxx
import Qt.labs.qmlmodels
import QtQml
import QtQuick
import QtQml.Models
import QtQuick.Controls 2.15
import QtQuick.Effects
import QtQuick.Shapes 1.6
import "Theme"
import "Library" as LibraryComponent

Item {
    id: root

    property var activeSidebar: libraryLeftSources.sidebar
    property var activeTracklist: libraryMainView

    onActiveSidebarChanged: {
        if (!root.activeSidebar?.tracklist)
            return;

        searchPane.clearAllCriteria();
        searchPane.textField.text = root.activeSidebar.tracklist.search;
        searchPane.tryConvertToFieldToken();
    }

    Connections {
        function onTracklistChanged() {
            searchPane.clearAllCriteria();
            searchPane.textField.text = root.activeSidebar.tracklist.search;
            searchPane.tryConvertToFieldToken();
        }

        target: root.activeSidebar
    }
    LibraryComponent.SourceTree {
        id: libraryLeftSources

    }
    LibraryComponent.SourceTree {
        id: libraryRightSources

    }
    LibraryComponent.Control {
        id: libraryControl

        onFocusWidgetChanged: {
            if (focusWidget && focusWidget != Skin.FocusedWidgetControl.WidgetKind.Searchbar && searchPane.activated) {
                searchPane.deactivateSearch();
            }

            switch (focusWidget) {
            case Skin.FocusedWidgetControl.WidgetKind.LibraryView:
                root.activeTracklist.view.forceActiveFocus();
                break;
            case Skin.FocusedWidgetControl.WidgetKind.Sidebar:
                sidebarTree.view.forceActiveFocus();
                break;
            case Skin.FocusedWidgetControl.WidgetKind.Searchbar:
                searchPane.activateSearch();
                break;
            }
        }
        onLibraryMoveVertical: offset => {
            root.activeTracklist.view.selectionModel.moveSelectionVertical(offset);
        }
        onLibraryScrollVertical: offset => {
            root.activeTracklist.view.selectionModel.scrollSelectionVertical(offset);
        }
        onLoadSelectedTrack: (group, play) => {
            root.activeTracklist.view.loadSelectedTrack(group, play);
        }
        onLoadSelectedTrackIntoNextAvailableDeck: play => {
            root.activeTracklist.view.loadSelectedTrackIntoNextAvailableDeck(play);
        }
        onSidebarActivate: offset => {
            sidebarTree.activate(offset);
        }
        onSidebarMoveVertical: offset => {
            sidebarTree.moveSelectionVertical(offset);
        }
        onSidebarScrollVertical: offset => {
            sidebarTree.scrollSelectionVertical(offset);
        }

        Connections {
            function containsFocusedItem(item) {
                let focused = root.Window.activeFocusItem;
                while (focused) {
                    if (focused == item)
                        return true;
                    focused = focused.parent;
                }
                return false;
            }
            function onActiveFocusItemChanged() {
                print("onActiveFocusItemChanged", root.Window.activeFocusItem);
                if (!root.Window.activeFocusItem || libraryControl.focusWidget == Skin.FocusedWidgetControl.WidgetKind.ContextMenu)
                    return;

                if (containsFocusedItem(root.activeTracklist)) {
                    libraryControl.focusWidget = Skin.FocusedWidgetControl.WidgetKind.LibraryView;
                } else if (containsFocusedItem(sidebarTree)) {
                    libraryControl.focusWidget = Skin.FocusedWidgetControl.WidgetKind.Sidebar;
                } else if (containsFocusedItem(searchPane)) {
                    libraryControl.focusWidget = Skin.FocusedWidgetControl.WidgetKind.Searchbar;
                }
            }

            target: root.Window.window
        }
    }
    SplitView {
        id: librarySplitView

        anchors.fill: parent
        orientation: Qt.Horizontal

        handle: Skin.SplitViewHandle {
            id: librarySplitHandle

            containmentMask: Item {
                height: librarySplitView.height
                width: 8
                x: (librarySplitHandle.width - width) / 2
            }
        }

        SplitView {
            id: sideBarSplitView

            SplitView.maximumWidth: 550
            SplitView.minimumWidth: 150
            SplitView.preferredWidth: root.width * 0.15
            orientation: Qt.Vertical

            handle: Skin.SplitViewHandle {
                id: sideBarSplitHandle

                dotColumns: 3

                containmentMask: Item {
                    height: 8
                    width: sideBarSplitView.width
                    x: (sideBarSplitHandle.width - width) / 2
                }
            }

            LibraryComponent.Browser {
                id: sidebarTree

                SplitView.fillHeight: true
                SplitView.minimumHeight: 200
                SplitView.preferredHeight: 500
                model: root.activeSidebar
            }
            Skin.PreviewDeck {
                id: previewDeck

                SplitView.maximumHeight: 200
                SplitView.minimumHeight: 100
                SplitView.preferredHeight: 100
            }
        }
        Item {
            id: browsingView

            SplitView.fillHeight: true
            SplitView.minimumHeight: 200
            SplitView.preferredWidth: root.width * 0.75

            SplitView {
                id: trackListSplitView

                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: tracklistMenu.left
                anchors.top: parent.top
                focus: true
                orientation: root.width < 800 ? Qt.Vertical : Qt.Horizontal

                handle: Skin.SplitViewHandle {
                    id: trackListSplitHandle

                    dotColumns: root.width < 800 ? 3 : 1

                    containmentMask: Item {
                        height: root.width < 800 ? 8 : librarySplitView.height
                        width: root.width < 800 ? sideBarSplitView.width : 8
                        x: (trackListSplitHandle.width - width) / 2
                    }
                }

                ActiveTrackList {
                    id: libraryMainView

                    SplitView.fillHeight: true
                    SplitView.fillWidth: true
                    focus: true
                    model: libraryLeftSources
                }
                Item {
                    SplitView.fillHeight: true
                    clip: true
                    implicitWidth: splitViewButton.checked ? trackListSplitView.width * 0.5 : 0
                    visible: implicitWidth > 0

                    Behavior on implicitWidth {
                        NumberAnimation {
                            id: librarySplitViewAnimation

                            duration: 1000
                            easing.type: Easing.OutElastic

                            onRunningChanged: {
                                if (running) {
                                    libraryMainView.inhibitColumnWidth = libraryMainView.view.width;
                                } else {
                                    libraryMainView.inhibitColumnWidth = 0;
                                }
                                if (running || !splitViewButton.checked) {
                                    librarySplitViewLoader.active = false;
                                    return;
                                }
                                if (splitViewButton.checked) {
                                    let rightSidebar = libraryRightSources.sidebar;
                                    rightSidebar.activate(rightSidebar.index(sidebarTree.currentSelectedIndex?.top ?? 0, 0));
                                    librarySplitViewLoader.active = true;
                                }
                            }
                        }
                    }

                    BusyIndicator {
                        anchors.centerIn: parent
                        visible: librarySplitViewLoader.item == null || librarySplitViewLoader.status != Loader.Ready
                    }
                    Loader {
                        id: librarySplitViewLoader

                        active: false
                        anchors.fill: parent
                        asynchronous: true
                        objectName: "rightTrackListLoader"
                        visible: active && item !== null && status == Loader.Ready

                        Binding on asynchronous {
                            delayed: true
                            value: !splitViewButton.checked || timeout.running
                        }
                        sourceComponent: Component {
                            ActiveTrackList {
                                inhibitColumnWidth: trackListSplitView.width * 0.5 - 17
                                model: libraryRightSources
                                objectName: "rightTrackList"

                                Component.onCompleted: root.activeSidebar = libraryRightSources.sidebar
                            }
                        }

                        // Accelerate the load of the split view after a specific delay
                        Timer {
                            id: timeout

                            // This delay could be tailored to the platform. For example, we could image Mixxx.Core exposing a performance score to help computing this: an old RPI/Android phone could use 2 second async, to ensure no impact of the audio engine, while a modern desktop likely doesn't need more than 250ms.
                            interval: 1500
                            repeat: false
                            running: splitViewButton.checked
                        }
                    }
                }
            }
            Column {
                id: tracklistMenu

                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.top: parent.top
                padding: 4
                spacing: 11
                width: 36

                Skin.Button {
                    id: splitViewButton

                    activeColor: Theme.white
                    checkable: true
                    icon.height: 16
                    icon.source: "images/splitview.svg"
                    icon.width: 16
                    implicitWidth: implicitHeight

                    onCheckedChanged: {
                        root.activeSidebar = checked ? libraryRightSources.sidebar : libraryLeftSources.sidebar;
                    }
                }
                Item {
                    height: historyButton.implicitWidth
                    width: historyButton.implicitHeight

                    Skin.Button {
                        id: historyButton

                        activeColor: Theme.white
                        checkable: true
                        text: "HISTORY"

                        transform: Rotation {
                            angle: 90
                            origin.x: historyButton.height / 2
                            origin.y: historyButton.height / 2
                        }
                    }
                }
                Item {
                    height: prepButton.implicitWidth
                    width: prepButton.implicitHeight

                    Skin.Button {
                        id: prepButton

                        activeColor: Theme.white
                        checkable: true
                        implicitWidth: 82
                        text: "PREPARATION"

                        transform: Rotation {
                            angle: 90
                            origin.x: prepButton.height / 2
                            origin.y: prepButton.height / 2
                        }
                    }
                }
            }
            MultiEffect {
                anchors.fill: searchPane
                shadowBlur: 0.25
                shadowColor: '#66000000'
                shadowEnabled: true
                shadowVerticalOffset: 2
                source: searchPane
            }
            LibraryComponent.SearchPane {
                id: searchPane

                activeSidebar: root.activeSidebar

                onActivatedChanged: {
                    if (!activated)
                        activeTracklist.view.forceActiveFocus();
                }
            }
        }
    }

    // One side of the split track list: tapping it makes it the active
    // sidebar, the inactive side dims.
    component ActiveTrackList: LibraryComponent.TrackList {
        opacity: root.activeSidebar == sidebar ? 1 : 0.6

        TapHandler {
            onTapped: {
                root.activeSidebar = parent.sidebar;
            }
        }
    }
}
