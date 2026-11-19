import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import Mixxx 1.0 as Mixxx
import "." as LibraryComponent
import "../Theme"

// Use an invisible item to handle the drag. Because our drag is async, we need an item that can move (due to Drag.Automatic) temporarily, till the drag is correctly initialized
Item {
    id: root

    readonly property var tracks: Array.from(new Set(view.selectionModel.selectedIndexes.map(i => i.row))).map(row => view.model.getTrackByRow(row)) ?? []
    readonly property var urlLists: root.tracks.map(track => track.trackLocationUrl.toString())
    required property var view

    Drag.dragType: Drag.Automatic
    Drag.imageSourceSize: Qt.size(290, 85)
    Drag.mimeData: {
        "text/uri-list": urlLists,
        "text/plain": urlLists.join("\n")
    }
    Drag.supportedActions: Qt.CopyAction
    enabled: !ApplicationWindow.window.isMobile

    Binding on Drag.active {
        delayed: true
        value: dragHandler.active && root.Drag.imageSource.toString().length > 0
    }

    Component {
        id: singleTrack

        Item {
            id: item

            property var trackData: root.tracks[0]

            clip: true
            height: root.Drag.imageSourceSize.height
            width: root.Drag.imageSourceSize.width

            TrackChip {
                id: singleTrack

                anchors.fill: parent
                anchors.margins: 15
                trackData: item.trackData

                onReadyChanged: {
                    item.grabToImage(result => {
                        root.Drag.imageSource = result.url;
                        dragImageSource.active = false;
                    }, root.Drag.imageSourceSize);
                }
            }
            MultiEffect {
                // clip: true
                anchors.fill: singleTrack
                shadowBlur: 0.5
                shadowColor: '#d0000000'
                shadowEnabled: true
                shadowScale: 1.04
                source: singleTrack
            }
        }
    }
    Component {
        id: multipleTrack

        Item {
            id: item

            height: root.Drag.imageSourceSize.height
            width: root.Drag.imageSourceSize.width

            Repeater {
                id: trackRepeater

                property int readyCount: 0

                model: root.tracks

                onModelChanged: {
                    readyCount = 0;
                }
                onReadyCountChanged: {
                    if (readyCount != count)
                        return;
                    item.grabToImage(result => {
                        root.Drag.imageSource = result.url;
                        dragImageSource.active = false;
                    }, root.Drag.imageSourceSize);
                }

                Item {
                    id: singleTrack

                    required property int index
                    required property var modelData

                    height: root.Drag.imageSourceSize.height - 30
                    width: root.Drag.imageSourceSize.width - 30
                    x: 15
                    y: 15

                    transform: Rotation {
                        angle: singleTrack.index * (10 / root.tracks.length) - 5
                        origin.x: singleTrack.width / 2
                        origin.y: singleTrack.height / 2
                    }

                    TrackChip {
                        id: content

                        anchors.fill: parent
                        trackData: modelData

                        onReadyChanged: {
                            trackRepeater.readyCount++;
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.darkGray4
                            opacity: 0.6
                            radius: content.radius
                        }
                    }
                    MultiEffect {
                        anchors.fill: parent
                        shadowBlur: 0.5
                        shadowColor: '#d0000000'
                        shadowEnabled: true
                        source: content
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                color: Theme.buttonNormalColor
                font.pixelSize: 16
                font.weight: Font.DemiBold
                text: `${root.tracks.length} tracks`
            }
        }
    }
    Loader {
        id: dragImageSource

        active: false
        asynchronous: true
        sourceComponent: root.tracks.length == 1 ? singleTrack : multipleTrack
        visible: false
    }
    DragHandler {
        id: dragHandler

        property var initialPosition: null

        // Excluding other pointing devices when not selected as they are clashing with the library scroll
        // acceptedDevices: selected ? PointerDevice.AllDevices : PointerDevice.Mouse | PointerDevice.TouchPad
        acceptedDevices: PointerDevice.AllDevices
        dragThreshold: view.dragThreshold

        // // FIXME: this is a workaround on Qt bug. See core proxy for details
        // enabled: !Mixxx.Core.hasPopup

        onActiveChanged: {
            if (active && !initialPosition) {
                initialPosition = Qt.point(root.x, root.y);
            }
            if (active && !dragImageSource.active && root.Drag.imageSource.toString().length == 0) {
                dragImageSource.active = true;
            }
        }
    }
    Connections {
        function onActiveChanged() {
            if (root.Drag.active) {
                root.x = dragHandler.initialPosition.x;
                root.y = dragHandler.initialPosition.y;
            } else {
                // Unfortunately, the grab pixmap is only short lived and cannot be cached long term
                root.Drag.imageSource = "";
            }
        }

        target: root.Drag
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

    component TrackChip: Rectangle {
        id: chip

        readonly property bool ready: waveformOverview.status != Mixxx.WaveformOverview.Status.Loading && waveformOverview.status != Mixxx.WaveformOverview.Status.Null && (cover.status != Image.Loading)
        required property var trackData

        clip: true
        color: Theme.sunkenBackgroundColor
        radius: 12

        RowLayout {
            id: contentLayout

            anchors.fill: parent
            visible: false

            Item {
                Layout.fillHeight: true
                Layout.preferredWidth: 75

                Image {
                    id: cover

                    asynchronous: false
                    fillMode: Image.PreserveAspectCrop
                    height: chip.height
                    smooth: true
                    source: trackData?.coverArtUrl ?? "../../images/icons/128x128/apps/mixxx.png"
                    verticalAlignment: Image.AlignVCenter
                    width: 75
                }
            }
            ColumnLayout {
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

                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    channels: Mixxx.WaveformOverview.Channels.LeftChannel
                    colorHigh: Theme.white
                    colorLow: Theme.green
                    colorMid: Theme.blue
                    renderer: Mixxx.WaveformOverview.Renderer.Filtered
                    trackId: trackData?.id
                }
            }
        }
        OpacityMask {
            anchors.fill: chip
            maskSource: chip
            source: contentLayout
        }
        Rectangle {
            bottomRightRadius: parent.radius
            topRightRadius: parent.radius
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
