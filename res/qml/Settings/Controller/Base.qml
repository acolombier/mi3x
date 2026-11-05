import QtQuick
import Mixxx 1.0 as Mixxx

Mixxx.ControllerElement {
    id: root

    property var attached: null
    property bool drageable: true
    property real heightInMm: Math.round(height * mmPerPixel)
    property string label: ""
    property bool locked: false
    property bool lockedOnGrid: true
    property real mmPerPixel: 0.5
    property bool resizeable: false
    readonly property bool resizing: bottomHandle.drag.active || topHandle.drag.active || leftHandle.drag.active || rightHandle.drag.active
    property int rulersSize: 15
    property real widthInMm: Math.round(width * mmPerPixel)

    signal duplicated
    signal selected(var item)

    // states: [
    //     State {
    //         when: root.Drag.active && attached != undefined
    //         AnchorChanges {
    //             target: root
    //             anchors {
    //                 verticalCenter: undefined
    //                 horizontalCenter: undefined
    //             }
    //         }
    //     },
    //     State {
    //         when: !root.Drag.active && attached == undefined
    //         PropertyChanges {
    //             target: root
    //             x: { Math.round(root.x / 10) * 10 }
    //             y: { Math.round(root.y / 10) * 10 }
    //         }
    //     }
    // ]

    function duplicateProperty(props) {
        if (props === undefined)
            props = {};
        return Object.assign({
            x: root.x + 10,
            y: root.y + 10,
            // properties: Object.assign(properties, {}),
            width: width,
            height: height
        }, props);
    }

    Drag.dragType: Drag.Automatic
    Drag.mimeData: {
        "demo/type": root.type
    }
    Drag.supportedActions: attached ? Qt.CopyAction : Qt.MoveAction

    onLockedChanged: {
        for (let child of children) {
            child.locked = locked;
        }
    }

    anchors {
        horizontalCenter: attached ? attached.h : undefined
        verticalCenter: attached ? attached.v : undefined
    }
    DragHandler {
        id: dragHandler

        enabled: !root.locked

        onActiveChanged: {
            if (!parent.drageable || parent.locked) {
                return;
            } else if (active) {
                parent.focus = false;
                let tl = parent.mapToGlobal(0, 0);
                let br = parent.mapToGlobal(parent.width, parent.height);
                let ratio = (br.x - tl.x) / parent.width;
                parent.Drag.hotSpot.x = mouseArea.mouseX * ratio;
                parent.Drag.hotSpot.y = mouseArea.mouseY * ratio;
                parent.grabToImage(function (result) {
                    parent.Drag.imageSource = result.url;
                    parent.Drag.active = true;
                }, Qt.size(parent.width * ratio, parent.height * ratio));
                console.log("attached", root.attached);
                if (!root.attached) {
                    root.visible = false;
                }
            } else {
                // parent.Drag.active = false
                // root.visible = true
                parent.focus = true;
            }
        }
    }
    MouseArea {
        id: mouseArea

        acceptedButtons: Qt.LeftButton | Qt.RightButton
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: false

        onClicked: mouse => {
            console.log("locked", root.locked);
            if (mouse.button == Qt.RightButton && root.drageable && !root.locked) {
                parent.destroy();        // destroy component
                return;
            } else if (root.focus || root.locked) {
                root.selected(root);
            } else if (!root.attached) {
                root.focus = true;
                root.z = 50;
            }
            mouse.accepted = false;
        }
        onDoubleClicked: {
            if (!root.locked) {
                root.duplicated();
            }
        }

        drag {
            filterChildren: true
            threshold: 1
        }
        Rectangle {
            anchors.fill: parent
            color: 'transparent'

            border {
                color: "steelblue"
                width: !root.attached && root.focus && !root.locked ? root.resizeable ? 2 : 1 : 0
            }
        }
    }
    Handle {
        id: leftHandle

        anchors.horizontalCenter: parent.left
        anchors.verticalCenter: parent.verticalCenter
        resizerCallback: p => {
            console.log("RESIZE", p);
            root.width -= p.x;
            root.x += p.x;
        }
        targetElement: root
    }
    Handle {
        id: rightHandle

        anchors.horizontalCenter: parent.right
        anchors.verticalCenter: parent.verticalCenter
        resizerCallback: p => {
            root.width += p.x;
        }
        targetElement: root
    }
    Handle {
        id: topHandle

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: 5
        axis: Drag.YAxis
        cursor: Qt.SizeVerCursor
        resizerCallback: p => {
            root.height -= p.y;
            root.y += p.y;
        }
        targetElement: root
    }
    Handle {
        id: bottomHandle

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.bottom
        axis: Drag.YAxis
        cursor: Qt.SizeVerCursor
        resizerCallback: p => {
            root.height += p.y;
        }
        targetElement: root
    }

    // onWidthChanged:{
    //     root.properties = Object.assign({
    //         "Width": `${Math.round(width*mmPerPixel)} mm`
    //     }, root.properties)
    // }

    component Handle: Rectangle {
        id: delegate

        property var axis: Drag.XAxis
        property var cursor: Qt.SizeHorCursor
        property alias drag: resizer.drag
        // anchors.horizontalCenter: parent.right
        // anchors.verticalCenter: parent.verticalCenter

        required property var resizerCallback
        required property var targetElement

        color: resizer.pressed ? "red" : "steelblue"
        height: rulersSize
        radius: rulersSize
        visible: targetElement.resizeable && !targetElement.locked && !targetElement.attached && targetElement.focus
        width: rulersSize
        z: 100

        MouseArea {
            id: resizer

            property var origin: null

            anchors.fill: parent
            cursorShape: delegate.cursor
            hoverEnabled: true

            onPositionChanged: {
                if (pressed) {
                    let tl = root.mapToGlobal(0, 0);
                    let br = root.mapToGlobal(root.width, root.height);
                    let ratio = (br.x - tl.x) / root.width;
                    resizerCallback(Qt.point(mouseX - origin.x, mouseY - origin.y));
                }
            }
            onPressedChanged: {
                console.log("pressed", pressed);
                origin = pressed ? Qt.point(mouseX, mouseY) : null;
            }

            drag {
                axis: delegate.axis
                target: parent
                threshold: 1
            }
        }
        border {
            color: "black"
            width: resizer.containsMouse ? 1 : 0
        }
    }
}
