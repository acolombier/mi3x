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
            objectName: "browsingView"

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
                    SplitView.preferredHeight: trackListSplitView.height * 0.5
                    SplitView.preferredWidth: trackListSplitView.width * 0.5
                    model: libraryLeftSources
                }
                Loader {
                    SplitView.preferredHeight: trackListSplitView.height * 0.5
                    SplitView.preferredWidth: trackListSplitView.width * 0.5
                    active: splitViewButton.checked
                    asynchronous: true
                    objectName: "rightTrackListLoader"
                    opacity: status == Loader.Ready ? 1 : 0
                    visible: splitViewButton.checked

                    sourceComponent: Component {
                        ActiveTrackList {
                            model: libraryRightSources
                            objectName: "rightTrackList"
                        }
                    }
                }
            }
            Column {
                id: tracklistMenu

                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.top: parent.top
                objectName: "tracklistMenu"
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
                    objectName: "splitViewButton"

                    onCheckedChanged: {
                        if (checked) {
                            let rightSidebar = libraryRightSources.sidebar;
                            rightSidebar.activate(rightSidebar.index(sidebarTree.currentSelectedIndex?.top ?? 0, 0));
                            root.activeSidebar = rightSidebar;
                        } else {
                            root.activeSidebar = libraryLeftSources.sidebar;
                        }
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
                objectName: "searchPane"
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
