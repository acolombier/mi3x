import QtQuick 2.12

// Window-wide, grab-less MultiPointTouchArea that dispatches unclaimed touch
// and mouse presses to registered TouchClient objects. It sits at the bottom of
// the scene so anything that accepts input above it (buttons, library, popups,
// flickables, ...) keeps its events and never reaches the hub.
MultiPointTouchArea {
    id: hub

    // TouchClient objects that want to receive gestures.
    readonly property var clients: []
    // touchId -> { client: TouchClient }
    property var owners: ({})

    function clientAt(x, y) {
        for (let i = hub.clients.length - 1; i >= 0; --i) {
            const client = hub.clients[i];
            const item = client.sourceItem;
            if (!item || !client.gestureEnabled || !hub.isEffectivelyVisible(item)) {
                continue;
            }
            const local = item.mapFromItem(hub, x, y);
            if (local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height) {
                return client;
            }
        }
        return null;
    }
    function isEffectivelyVisible(item) {
        let node = item;
        while (node) {
            if (!node.visible) {
                return false;
            }
            node = node.parent;
        }
        return true;
    }
    function localOf(client, x, y) {
        return client.sourceItem.mapFromItem(hub, x, y);
    }
    function register(client) {
        if (hub.clients.indexOf(client) === -1) {
            hub.clients.push(client);
        }
    }
    function release(touchId) {
        delete hub.owners[touchId];
    }
    function releaseClient(client) {
        const stale = [];
        for (const key in hub.owners) {
            if (hub.owners[key].client === client) {
                stale.push(key);
            }
        }
        for (const key of stale) {
            delete hub.owners[key];
        }
    }
    function unregister(client) {
        const index = hub.clients.indexOf(client);
        if (index >= 0) {
            hub.clients.splice(index, 1);
        }
        hub.releaseClient(client);
    }

    // Touch-only gesture router. The mouse is handled by the mouse-only
    // DragHandler of the knob/fader instead; the mouse would otherwise behave
    // as a single synthetic touch point here, which breaks mouse drags.
    mouseEnabled: false

    onCanceled: points => {
        for (let i = 0; i < points.length; ++i) {
            const point = points[i];
            const owner = hub.owners[point.pointId];
            if (!owner) {
                continue;
            }
            delete hub.owners[point.pointId];
            owner.client.handleCancel(point.pointId);
        }
    }
    onPressed: points => {
        for (let i = 0; i < points.length; ++i) {
            const point = points[i];
            if (hub.owners[point.pointId]) {
                continue;
            }
            const client = hub.clientAt(point.x, point.y);
            if (!client || !client.acceptsGesture(point.pointId)) {
                continue;
            }
            hub.owners[point.pointId] = {
                client: client
            };
            const local = hub.localOf(client, point.x, point.y);
            client.handlePress(point.pointId, point.pointId !== -1, local.x, local.y);
        }
    }
    onReleased: points => {
        for (let i = 0; i < points.length; ++i) {
            const point = points[i];
            const owner = hub.owners[point.pointId];
            if (!owner) {
                continue;
            }
            delete hub.owners[point.pointId];
            const local = hub.localOf(owner.client, point.x, point.y);
            owner.client.handleRelease(point.pointId, local.x, local.y);
        }
    }
    onUpdated: points => {
        for (let i = 0; i < points.length; ++i) {
            const point = points[i];
            const owner = hub.owners[point.pointId];
            if (!owner) {
                continue;
            }
            const local = hub.localOf(owner.client, point.x, point.y);
            owner.client.handleMove(point.pointId, local.x, local.y);
        }
    }
}
