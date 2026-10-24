import QtQuick
import QtQuick.Layouts
import Mixxx 1.0 as Mixxx
import "." as LibraryComponent
import "../Theme"

Rectangle {
    id: root

    readonly property alias dragImage: dragImageSource
    required property bool selected
    property alias track: trackData

    Drag.dragType: Qt.platform.os === "android" ? Drag.None : Drag.Automatic
    Drag.mimeData: {
        "text/uri-list": file_url.toString(),
        "text/plain": file_url.toString()
    }
    Drag.supportedActions: Qt.CopyAction
    color: selected ? Theme.accentColor : (row % 2 == 0 ? Theme.sunkenBackgroundColor : Theme.backgroundColor)

    LibraryComponent.Track {
        id: trackData

        anchors.fill: parent
        view: TableView.view
    }
    Item {
        id: dragImageSource

        height: 85
        visible: false
        width: 190

        Rectangle {
            color: Theme.sunkenBackgroundColor
            radius: 12

            anchors {
                bottom: parent.bottom
                left: parent.left
                margins: 5
                right: parent.right
                top: parent.top
            }
            RowLayout {
                anchors.fill: parent

                Image {
                    id: cover

                    Layout.fillHeight: true
                    Layout.preferredWidth: cover_art ? 75 : 0
                    asynchronous: true
                    clip: true
                    fillMode: Image.PreserveAspectFit
                    source: cover_art ?? ""
                }
                ColumnLayout {
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    // Text {
                    //     color: Theme.textColor
                    //     text: track ? track.title : 'Unknown title'
                    // }
                    // Text {
                    //     color: Theme.midGray
                    //     text: track ? track.artist : 'Unknown artist'
                    // }
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
    DragHandler {
        id: dragHandler

        // enabled: false
        enabled: Qt.platform.os !== "android" && !Mixxx.Core.hasPopup

        onActiveChanged: {
            root.Drag.imageSource = cover_art ?? "";
            // FIXME: Regression since merge with upstream in https://github.com/acolombier/mi3x/pull/43. Disabling on Windows, which will prevent drag-n-drop to player
            root.Drag.active = Qt.platform.os !== "windows" && active;
            if (active) {
                trackData.view.selectionModel.selectRow(row);
                //         dragImageSource.grabToImage(function(result) {
                //             console.log(`dragHandler: ${result}`)
                //             parent.Drag.imageSource = result.url
                //             parent.Drag.active = true
                //         }, Qt.size(dragImageSource.width, dragImageSource.height))
                //     } else {
                //         parent.Drag.active = false
            }
        }
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
