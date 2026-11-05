import QtQuick
import QtQuick.Shapes
import "."
import Mixxx 1.0 as Mixxx

Base {
    id: root

    property var childrenToAdd: new Array()
    property var components: {}
    property int grid: 10

    function createComponent(comp, prop) {
        let e = comp.createObject(root, prop);
        e.selected.connect(e => {
            root.selected(e);
        });
        e.duplicated.connect(() => {
            root.createComponent(comp, e.duplicateProperty());
        });
        return e;
    }
    function duplicateProperty(props) {
        if (props === undefined)
            props = {};
        let duplicatedElements = new Array();
        for (let e of root.children) {
            let newElement = root.components[e.type].createObject(undefined, e.duplicateProperty({
                x: e.x,
                y: e.y
            }));
            newElement.connect(item => {
                root.selected(item);
            });
            newElement.duplicated.connect(() => {
                root.components[newElement.type].createObject(undefined, newElement.duplicateProperty());
            });
            duplicatedElements.push(newElement);
        }
        props = Object.assign(root.properties(), props);
        props.childrenToAdd = duplicatedElements;
        print("seed", JSON.stringify(props));
        return props;
    }
    function load(children) {
        for (let child of children) {
            let childChildren = child.children;
            if (child.type == Mixxx.ControllerElement.Type.Zone) {
                child.components = root.components;
                delete child.children;
            }
            let e = root.createComponent(root.components[child.type], child);
            if (childChildren) {
                e.load(childChildren);
            }
        }
    }

    resizeable: !root.attached
    type: Mixxx.ControllerElement.Zone

    Component.onCompleted: () => {
        if (root.childrenToAdd)
            for (let e of root.childrenToAdd) {
                e.setParent(root);
            }
        root.childrenToAdd = {};
    }
    onGridChanged: {
        let tl = parent.mapToGlobal(0, 0);
        let br = parent.mapToGlobal(parent.width, parent.height);
        let normalisedGrid = (br.x - tl.x) / parent.width * grid;
        for (let e of root.children) {
            if (!e.lockedOnGrid)
                continue;
            e.x = Math.round(e.x / normalisedGrid) * normalisedGrid;
            e.y = Math.round(e.y / normalisedGrid) * normalisedGrid;
        }
    }

    Shape {
        // anchors.fill: parent
        ShapePath {
            dashPattern: [1, 4]
            fillColor: '#40d9d9d9'
            startX: 0
            startY: 0
            strokeColor: "#222222"
            strokeStyle: ShapePath.DashLine
            strokeWidth: 1

            PathLine {
                x: root.width
                y: 0
            }
            PathLine {
                x: root.width
                y: root.height
            }
            PathLine {
                x: 0
                y: root.height
            }
            PathLine {
                x: 0
                y: 0
            }
        }
    }
    DropArea {
        id: zone

        anchors.fill: parent

        onDropped: e => {
            e.source.visible = true;
            let tl = parent.mapToGlobal(0, 0);
            let br = parent.mapToGlobal(parent.width, parent.height);
            let ratio = (br.x - tl.x) / parent.width;
            let origin = Qt.point(e.x - e.source.Drag.hotSpot.x / ratio, e.y - e.source.Drag.hotSpot.y / ratio);
            if (e.source.lockedOnGrid) {
                origin.x = Math.round(origin.x / (root.grid * ratio)) * root.grid * ratio;
                origin.y = Math.round(origin.y / (root.grid * ratio)) * root.grid * ratio;
            }
            if (e.formats.includes("demo/type") && e.supportedActions & Qt.CopyAction) {
                const sourceComponent = e.getDataAsString("demo/type");
                root.createComponent(root.components[sourceComponent], e.source.duplicateProperty({
                    x: origin.x,
                    y: origin.y
                }));
                e.accept(Qt.CopyAction);
                return;
            } else if (e.source.parent instanceof Zone && e.source.parent != root) {
                e.source.setParent(root);
                e.source.x = origin.x;
                e.source.y = origin.y;
                e.accept(Qt.MoveAction);
            } else if (e.source instanceof Base) {
                e.source.x = origin.x;
                e.source.y = origin.y;
                e.accept(Qt.MoveAction);
            }
        }
    }
}
