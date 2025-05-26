import ".." as Skin
import Mixxx 1.0 as Mixxx
import Qt.labs.qmlmodels
import QtQml
import QtQuick
import QtQml.Models
import QtQuick.Layouts
import QtQuick.Controls 2.15
import QtQuick.Shapes 1.12
import "../Theme"

Rectangle {
    id: root

    readonly property var featureSelection: ItemSelectionModel {
    }
    required property var model

    color: Theme.backgroundColor

    Component.onCompleted: {
        root.model.activate(root.model.index(0, 0));
    }

    Rectangle {
        anchors.bottomMargin: 40
        anchors.fill: parent
        anchors.leftMargin: 7
        anchors.rightMargin: 15
        anchors.topMargin: 7
        color: Theme.sunkenBackgroundColor

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            ScrollView {
                Layout.fillHeight: true
                Layout.fillWidth: true

                TreeView {
                    id: featureView

                    // Used for testing
                    function getSelectedPath() {
                        return featureSelection.currentIndex.row;
                    }

                    Layout.fillWidth: true
                    clip: true
                    model: root.model
                    objectName: "featureTree"
                    selectionModel: featureSelection

                    delegate: FocusScope {
                        id: treeItem

                        readonly property bool canAddTrack: capabilities & Mixxx.LibraryAbstractSource.Capability.AddTrack
                        readonly property bool canCreate: capabilities & Mixxx.LibraryAbstractSource.Capability.Create
                        required property int column
                        readonly property bool current: row === treeView.currentRow
                        required property int depth
                        required property bool expanded
                        required property int hasChildren
                        required property var icon
                        readonly property real indentation: 40
                        readonly property var index: treeView.index(row, column)

                        // Rotate indicator when expanded by the user
                        // (requires TreeView to have a selectionModel)
                        property Animation indicatorAnimation: NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutQuart
                            from: expanded ? 0 : 90
                            property: "rotation"
                            target: indicator
                            to: expanded ? 90 : 0
                        }
                        required property bool isTreeNode
                        required property string itemName
                        required property string label
                        readonly property real padding: 5
                        required property int row

                        // Assigned to by TreeView:
                        required property TreeView treeView

                        implicitHeight: depth == 0 ? 42 : 35
                        implicitWidth: treeView.width
                        objectName: `index${row}`

                        TableView.onPooled: indicatorAnimation.complete()
                        TableView.onReused: if (current)
                            indicatorAnimation.start()
                        onExpandedChanged: indicator.rotation = expanded ? 90 : 0

                        Rectangle {
                            id: background

                            anchors.fill: parent
                            color: row == 0 ? Theme.midGray : depth == 0 ? Theme.darkGray2 : 'transparent'

                            MouseArea {
                                id: rowMouseArea

                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                anchors.fill: parent
                                hoverEnabled: true

                                onClicked: event => {
                                    let index = treeView.index(row, column);
                                    treeView.model.activate(index);
                                    if (isTreeNode && hasChildren && (!expanded || current)) {
                                        treeView.toggleExpanded(row);
                                    }
                                    treeView.selectionModel.setCurrentIndex(index, ItemSelectionModel.NoUpdate);
                                    event.accepted = true;
                                }
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: current ? Theme.midGray : 'transparent'
                            }
                            Item {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.leftMargin: 10 + 15 * depth
                                anchors.right: parent.right
                                anchors.top: parent.top
                                width: 25

                                Repeater {
                                    id: lineIcon

                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    model: !!icon ? 1 : 0

                                    Image {
                                        height: 25
                                        source: icon
                                        visible: depth == 0 && icon
                                        width: 25
                                    }
                                }
                                Label {
                                    id: indicator

                                    Layout.preferredWidth: indicator.implicitWidth
                                    color: Theme.textColor
                                    objectName: "indicator"
                                    text: "▶"
                                    visible: isTreeNode && hasChildren

                                    anchors {
                                        left: parent.left
                                        verticalCenter: lineIcon.bottom
                                    }
                                }
                                Label {
                                    id: labelItem

                                    anchors.left: parent.left
                                    anchors.leftMargin: depth == 0 && row == 0 ? 10 : 34
                                    anchors.verticalCenter: parent.verticalCenter
                                    clip: true
                                    color: Theme.textColor
                                    font.pixelSize: 14
                                    font.weight: depth == 0 ? Font.Bold : Font.Medium
                                    objectName: "label"
                                    text: label
                                }
                                Item {
                                    id: newItem

                                    height: parent.height
                                    objectName: "newItem"
                                    visible: (rowMouseArea.containsMouse || popup.opened || treeItem.current) && isTreeNode && depth == 0 && canCreate
                                    width: 30

                                    anchors {
                                        right: parent.right
                                        // rightMargin: 10
                                        verticalCenter: parent.verticalCenter
                                    }
                                    Rectangle {
                                        anchors.fill: parent

                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal

                                            GradientStop {
                                                color: Theme.sunkenBackgroundColor
                                                position: 1
                                            }
                                            GradientStop {
                                                color: 'transparent'
                                                position: 0
                                            }
                                        }
                                    }
                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        border.color: Theme.white
                                        border.width: 2
                                        color: 'transparent'
                                        height: 20
                                        radius: 20
                                        width: 20

                                        Shape {
                                            anchors.fill: parent
                                            anchors.margins: 4

                                            ShapePath {
                                                capStyle: ShapePath.RoundCap
                                                fillColor: Theme.white
                                                startX: 6
                                                startY: 0
                                                strokeWidth: 2

                                                PathLine {
                                                    x: 6
                                                    y: 12
                                                }
                                                PathLine {
                                                    x: 6
                                                    y: 8
                                                }
                                            }
                                            ShapePath {
                                                capStyle: ShapePath.RoundCap
                                                fillColor: Theme.white
                                                startX: 0
                                                startY: 6
                                                strokeWidth: 2

                                                PathLine {
                                                    x: 12
                                                    y: 6
                                                }
                                                PathLine {
                                                    x: 8
                                                    y: 6
                                                }
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor

                                            onPressed: {
                                                popup.x = parent.width;
                                                popup.y = parent.height / 2 - popup.height / 2;
                                                popup.open();
                                                popup.forceActiveFocus(Qt.PopupFocusReason);
                                            }
                                        }
                                        Skin.ActionPopup {
                                            id: popup

                                            readonly property var feature: featureView.model.get(treeItem.index)
                                            property var lastError: null

                                            function submit() {
                                                let result = popup.feature.create(newItemName.input.text);
                                                if (result == Mixxx.LibraryAbstractSource.ItemCreateResult.Ok) {
                                                    newItemName.input.text = "";
                                                    popup.close();
                                                    return;
                                                }
                                                popup.lastError = result;
                                                newItemName.input.forceActiveFocus();
                                            }

                                            contentItem.objectName: "createFeaturePopup"
                                            focus: true
                                            padding: 6

                                            SequentialAnimation on x {
                                                running: popup.lastError != null

                                                NumberAnimation {
                                                    duration: 1000
                                                    easing.type: Easing.OutQuad
                                                    to: popup.parent.width + 20
                                                }
                                                NumberAnimation {
                                                    duration: 1000
                                                    easing.type: Easing.OutQuad
                                                    to: popup.parent.width // Bounce up
                                                }
                                            }

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                color: Theme.white
                                                font.pixelSize: 14
                                                font.weight: Font.Bold
                                                text: qsTr("New %1").arg(itemName)
                                            }
                                            Skin.InputField {
                                                id: newItemName

                                                readonly property bool hasError: popup.lastError != null

                                                Layout.fillWidth: true
                                                Layout.margins: 4
                                                Layout.preferredHeight: 36
                                                background.border.color: hasError ? 'red' : null
                                                focus: true
                                                objectName: "name"

                                                input.onAccepted: popup.submit()
                                                input.onTextEdited: {
                                                    popup.lastError = null;
                                                }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 36

                                                Skin.ActionButton {
                                                    Layout.fillWidth: true
                                                    label.text: qsTr("Cancel")
                                                    objectName: "cancel"

                                                    onPressed: {
                                                        newItemName.input.text = "";
                                                        popup.close();
                                                    }
                                                }
                                                Skin.ActionButton {
                                                    Layout.fillWidth: true
                                                    category: Skin.ActionButton.Action
                                                    label.text: qsTr("Create")
                                                    objectName: "create"
                                                    opacity: !popup.lastError && newItemName.input.text ? 1 : 0.4

                                                    onPressed: popup.submit()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
