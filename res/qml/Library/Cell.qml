import QtQuick
import QtQuick.Layouts
import Mixxx 1.0 as Mixxx
import "." as LibraryComponent
import "../Theme"

Rectangle {
    id: root

    required property bool selected
    required property var view

    color: selected ? Theme.accentColor : (row % 2 == 0 ? Theme.sunkenBackgroundColor : Theme.backgroundColor)

    TapHandler {
        id: tapHandler

        acceptedButtons: Qt.LeftButton | Qt.RightButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        dragThreshold: view.dragThreshold
        // FIXME: this is a workaround on Qt bug. See core proxy for details
        enabled: !Mixxx.Core.hasPopup

        onDoubleTapped: (eventPoint, button) => {
            if (button === Qt.RightButton)
                return;
            view.selectionModel.selectRow(row);
            view.loadSelectedTrackIntoNextAvailableDeck(false);
        }
        onPressedChanged: {
            if (!pressed)
                return;
            if (!selected || point.modifiers)
                view.selectionModel.selectRow(row, point.modifiers);
            if (point.pressedButtons === Qt.RightButton) {
                view.contextMenu.popup(parent, point.pressPosition);
            }
        }
    }
    TapHandler {
        id: touchScreenTapHandler

        acceptedDevices: PointerDevice.TouchScreen | PointerDevice.Stylus
        dragThreshold: view.dragThreshold
        // FIXME: this is a workaround on Qt bug. See core proxy for details
        enabled: !Mixxx.Core.hasPopup

        onDoubleTapped: (eventPoint, button) => {
            view.selectionModel.selectRow(row);
            view.loadSelectedTrackIntoNextAvailableDeck(false);
        }
        onLongPressed: {
            view.selectionModel.selectRow(row);
            view.contextMenu.popup(parent, 0, 0);
        }
        onTapped: (eventPoint, button) => {
            view.selectionModel.selectRow(row);
        }
    }
}
