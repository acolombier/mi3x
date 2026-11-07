import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls
import QtQuick.Window 2.12

Popup {
    id: hud

    property int axis: 0
    readonly property real fill: Mixxx.MathUtils.clamp(value, 0, 1)
    property color fillColor: "#01dcfc"
    property Item sourceItem
    property double value: 0

    background: null
    closePolicy: Popup.NoAutoClose
    enabled: false
    height: axis === 0 ? 20 : 148
    objectName: "valueHud"
    padding: 4
    spacing: 14
    width: axis === 0 ? 148 : 20
    x: {
        if (!sourceItem || !sourceItem.Window.contentItem) {
            return 0;
        }
        const scenePos = sourceItem.mapToItem(null, 0, 0);
        const windowWidth = sourceItem.Window.contentItem.width;

        if (axis !== 1) {
            return (sourceItem.width - width) / 2;
        } else if (scenePos.y - hud.width - spacing >= 0) {
            return -(hud.width + spacing);
        } else {
            return sourceItem.width + spacing;
        }
    }
    y: {
        if (!sourceItem || !sourceItem.Window.contentItem) {
            return 0;
        }
        const scenePos = sourceItem.mapToItem(null, 0, 0);
        const windowWidth = sourceItem.Window.contentItem.width;

        if (axis === 1) {
            return (sourceItem.height - height) / 2;
        } else if (scenePos.y - hud.height - spacing >= 0) {
            return -(hud.height + spacing);
        } else {
            return sourceItem.height + spacing;
        }
    }

    Rectangle {
        id: track

        anchors.fill: parent
        color: "#5A5A5A"
        radius: 5
        visible: hud.axis != -1

        Rectangle {
            id: fill

            property real fillLength: Math.max(0, ((hud.axis === 0 ? parent.width : parent.height) - 4) * hud.fill)

            color: hud.fillColor
            height: hud.axis === 0 ? parent.height - 4 : fillLength
            radius: 3
            width: hud.axis === 0 ? fillLength : parent.width - 4
            x: 2
            y: hud.axis === 0 ? 2 : parent.height - fillLength - 2
        }
    }
}
