import QtQuick
import QtQuick.Layouts
import Mixxx 1.0 as Mixxx
import "." as LibraryComponent
import "../Theme"

Rectangle {
    id: root

    required property bool selected
    property alias track: trackData

    function pooled() {
        dragHandler.initialPosition = null;
        dummyHandler.Drag.imageSource = "";
    }

    color: selected ? Theme.accentColor : (row % 2 == 0 ? Theme.sunkenBackgroundColor : Theme.backgroundColor)

    LibraryComponent.Track {
        id: trackData

        anchors.fill: parent
        view: TableView.view
    }
    Loader {
        id: dragImageSource

        active: false
        asynchronous: true
        visible: false

        sourceComponent: Component {
            Item {
                id: item

                readonly property bool loaded: waveformOverview.status != Mixxx.WaveformOverview.Status.Loading && waveformOverview.status != Mixxx.WaveformOverview.Status.Null && (cover.status != Image.Loading)
                readonly property var trackData: track.view.model?.getTrackByRow(row)

                clip: true
                height: dummyHandler.Drag.imageSourceSize.height
                width: dummyHandler.Drag.imageSourceSize.width

                onLoadedChanged: {
                    item.grabToImage(result => {
                        dummyHandler.Drag.imageSource = result.url;
                        dragImageSource.active = false;
                    }, dummyHandler.Drag.imageSourceSize);
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 5
                    color: Theme.sunkenBackgroundColor
                    radius: 12

                    RowLayout {
                        anchors.fill: parent

                        Image {
                            id: cover

                            Layout.fillHeight: true
                            Layout.preferredWidth: 75
                            asynchronous: false
                            fillMode: Image.PreserveAspectCrop
                            height: 75
                            smooth: true
                            source: cover_art ?? "../../images/icons/128x128/apps/mixxx.png"
                            width: 75
                        }
                        ColumnLayout {
                            Layout.fillHeight: true
                            Layout.fillWidth: true

                            Text {
                                color: Theme.textColor
                                text: trackData?.title ?? 'Unknown title'
                            }
                            Text {
                                color: Theme.midGray
                                text: trackData?.artist ?? 'Unknown artist'
                            }
                            Mixxx.WaveformOverview {
                                id: waveformOverview

                                Layout.fillWidth: true
                                channels: Mixxx.WaveformOverview.Channels.LeftChannel
                                colorHigh: Theme.white
                                colorLow: Theme.green
                                colorMid: Theme.blue
                                implicitHeight: 30
                                implicitWidth: 30
                                renderer: Mixxx.WaveformOverview.Renderer.Filtered
                                trackId: track_id
                            }
                        }
                    }
                    Rectangle {
                        width: 20

                        gradient: Gradient {
                            orientation: Gradient.Horizontal

                            GradientStop {
                                color: Theme.darkGray
                                position: 1
                            }
                            GradientStop {
                                color: 'transparent'
                                position: 0
                            }
                        }

                        anchors {
                            bottom: parent.bottom
                            right: parent.right
                            top: parent.top
                        }
                    }
                }
            }
        }
    }
    // Use an invisible item to handle the drag. Because our drag is async, we need an item that can move (due to Drag.Automatic) temporarily, till the drag is correctly initialized
    Item {
        id: dummyHandler

        Drag.dragType: Qt.platform.os === "android" ? Drag.None : Drag.Automatic
        Drag.imageSourceSize: Qt.size(290, 85)
        Drag.mimeData: {
            "text/uri-list": file_url.toString(),
            "text/plain": file_url.toString()
        }
        Drag.supportedActions: Qt.CopyAction
        anchors.fill: parent

        Binding on Drag.active {
            delayed: true
            value: dragHandler.active && dummyHandler.Drag.imageSource.toString().length > 0
        }

        DragHandler {
            id: dragHandler

            property var initialPosition: null

            // Excluding other pointing devices when not selected as they are clashing with the library scroll
            acceptedDevices: selected ? PointerDevice.AllDevices : PointerDevice.Mouse | PointerDevice.TouchPad
            dragThreshold: root.track.dragThreshold

            onActiveChanged: {
                if (active && !initialPosition) {
                    root.track.view?.selectionModel.selectRow(row);
                    initialPosition = Qt.point(root.x, root.y);
                }
                if (active && !dragImageSource.active && dummyHandler.Drag.imageSource.toString().length == 0) {
                    dragImageSource.active = true;
                }
            }
        }
    }
    Connections {
        function onActiveChanged() {
            if (dummyHandler.Drag.active) {
                root.x = dragHandler.initialPosition.x;
                root.y = dragHandler.initialPosition.y;
            } else {
                // Unfortunately, the grab pixmap is only short lived and cannot be cached long term
                dummyHandler.Drag.imageSource = "";
            }
        }

        target: dummyHandler.Drag
    }
    Rectangle {
        id: border

        color: Theme.darkGray2
        width: 1

        anchors {
            bottom: parent.bottom
            right: parent.right
            top: parent.top
        }
    }
}
