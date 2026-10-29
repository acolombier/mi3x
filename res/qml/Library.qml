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
                focusOutTarget: browsingView
            }
        }
    }

    // One side of the split track list: tapping it makes it the active
    // sidebar, the inactive side dims.
    component ActiveTrackList: LibraryComponent.TrackList {
        focus: true
        opacity: root.activeSidebar == sidebar ? 1 : 0.6

        TapHandler {
            onTapped: {
                root.activeSidebar = parent.sidebar;
            }
        }
    }
}
