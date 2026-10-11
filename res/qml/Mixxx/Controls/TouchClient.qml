import QtQuick 2.12
import QtQuick.Window 2.12

// Per-widget gesture client. Unlike the old self-contained MultiPointTouchArea
// it does not process input itself; a window-wide TouchHub feeds it with the
// presses that fall through to the bottom of the scene.
Item {
    id: client

    readonly property bool active: gestureActive
    property int activeTouchId: -1
    property int axis: -1
    readonly property bool axisLocked: axis >= 0
    property bool fromTouch: false
    property bool gestureActive: false
    property bool gestureEnabled: true
    property var hub: Window.window ? Window.window.touchHub : null
    property point lastPos
    property point position
    property point pressPos
    property Item sourceItem
    property real tapMaxDisplacement: 10

    signal gestureCancelled
    signal movedAt(real dx, real dy, real x, real y)
    signal pressedAt(real x, real y)
    signal releasedAt(real x, real y)

    function acceptsGesture(touchId) {
        // The first finger keeps authority over the widget until it lifts.
        return !gestureActive;
    }
    function clearGesture() {
        gestureActive = false;
        pressPos = Qt.point(0, 0);
        lastPos = Qt.point(0, 0);
        position = Qt.point(0, 0);
        axis = -1;
        fromTouch = false;
        activeTouchId = -1;
    }
    function handleCancel(touchId) {
        if (!gestureActive) {
            return;
        }
        client.gestureCancelled();
        client.clearGesture();
    }
    function handleMove(touchId, x, y) {
        if (!gestureActive || touchId !== activeTouchId) {
            return;
        }
        const dx = x - lastPos.x;
        const dy = y - lastPos.y;
        position = Qt.point(x, y);
        lastPos = position;
        if (axis < 0) {
            const tx = position.x - pressPos.x;
            const ty = position.y - pressPos.y;
            if (Math.max(Math.abs(tx), Math.abs(ty)) > tapMaxDisplacement) {
                axis = (Math.abs(tx) >= Math.abs(ty)) ? 0 : 1;
            }
        }
        client.movedAt(dx, dy, x, y);
    }
    function handlePress(touchId, isTouch, x, y) {
        activeTouchId = touchId;
        fromTouch = isTouch;
        position = Qt.point(x, y);
        pressPos = position;
        lastPos = position;
        axis = -1;
        // Emitted before the active state becomes visible so consumers can
        // capture their baseline (root.value) while the value bindings are
        // still inactive and unpoisoned.
        client.pressedAt(x, y);
        gestureActive = true;
    }
    function handleRelease(touchId, x, y) {
        if (!gestureActive || touchId !== activeTouchId) {
            return;
        }
        client.releasedAt(x, y);
        client.clearGesture();
    }

    Component.onCompleted: {
        if (client.hub) {
            client.hub.register(client);
        }
    }
    Component.onDestruction: {
        if (client.hub) {
            client.hub.unregister(client);
        }
    }
    onGestureEnabledChanged: {
        if (!gestureEnabled && gestureActive) {
            if (client.hub) {
                client.hub.release(client.activeTouchId);
            }
            client.handleCancel(client.activeTouchId);
        }
    }
    onHubChanged: {
        if (client.hub) {
            client.hub.register(client);
        }
    }
}
