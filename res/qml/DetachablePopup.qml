import "." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import "Theme"
import "Settings" as Settings

Item {
    id: root

    property alias dialog: dialog

    // Used to show click interaction on the Window. Mainly relevant on automated testing
    property bool enableDiagnosticClick: false
    property alias loader: loader
    readonly property bool opened: popup.opened || dialog.opened
    property alias popup: popup

    function close() {
        if (popup.opened)
            popup.close();
        if (dialog.opened)
            dialog.close();
    }
    function open() {
        popup.open();
    }

    Loader {
        id: loader

        active: root.opened
        anchors.fill: parent
        asynchronous: true
        sourceComponent: contentItem
        visible: item !== null && status == Loader.Ready

        onLoaded: {
            if (!root.requestFocusSection)
                return;
            const group = loader.item.manager.findSettings(root.requestFocusSection);
            group?.activated();
            root.requestFocusSection = null;
        }

        // Accelerate the load of the setting popup after a specific delay
        Timer {
            id: timer

            // This delay could be tailored to the platform. FOr example, we could image Mixxx.Core exposing a performance score to help computing this: an old RPI/Android phone could use 2 second async, to ensure no impact of the audio engine, while a modern desktop likely doesn't need more than 250ms.
            interval: 500
            repeat: false
            running: root.opened

            onRunningChanged: {
                loader.asynchronous = running;
            }
        }
    }

    // Testing automation resources
    Rectangle {
        id: click

        color: clickDetector.clicked ? 'red' : 'green'
        radius: width / 2
        visible: opacity != 0 && root.enableDiagnosticClick

        NumberAnimation on height {
            from: 20
            running: clickDetector.clicked
            to: 0
        }
        NumberAnimation on opacity {
            from: 1
            running: clickDetector.clicked
            to: 0
        }
        NumberAnimation on width {
            from: 20
            running: clickDetector.clicked
            to: 0
        }
    }
    MouseArea {
        id: clickDetector

        property bool clicked: false

        anchors.fill: parent
        enabled: root.enableDiagnosticClick

        onPressed: mouse => {
            clicked = false;
            click.width = 20;
            click.height = 20;
            click.opacity = 1;
            click.x = Qt.binding(() => mouse.x - click.width / 2);
            click.y = Qt.binding(() => mouse.y - click.height / 2);
            clicked = true;
            mouse.accepted = false;
        }
    }
    Popup {
        id: popup

        focus: true
        height: root.height
        horizontalPadding: 20
        modal: true
        verticalPadding: 20
        width: root.width

        background: Rectangle {
            anchors.fill: parent
            color: Theme.darkGray2
            opacity: parent.radius < 0 ? Math.max(0.1, 1 + parent.radius / 8) : 1
            radius: 8

            BusyIndicator {
                anchors.centerIn: parent
                visible: loader.item == null || loader.status != Loader.Ready
            }
        }
        contentItem: Item {
            anchors.fill: parent
            objectName: opened ? "popupItem" : ""

            Item {
                id: popupContent

                anchors.fill: parent
                anchors.margins: 20
            }
            Skin.Button {
                id: detachButton

                activeColor: Theme.white
                anchors.right: closeButton.left
                anchors.rightMargin: 5
                anchors.top: closeButton.top
                text: "Detach"
                visible: !ApplicationWindow.window.isMobile

                onPressed: {
                    dialog.open();
                    popup.close();
                }
            }
            Skin.Button {
                id: closeButton

                activeColor: Theme.white
                anchors.margins: 10
                anchors.right: parent.right
                anchors.top: parent.top
                text: "✕"

                onPressed: {
                    root.close();
                }
            }
        }

        onAboutToHide: {
            loader.asynchronous = true;
        }
        onAboutToShow: {
            loader.parent = popupContent;
            loader.anchors.fill = popupContent;
        }
        onClosed: {
            Mixxx.Core.removeOpenedPopup(this);
        }
        onOpened: {
            Mixxx.Core.addOpenedPopup(this);
        }
    }
    Dialog {
        id: dialog

        focus: true
        height: root.height
        modal: false
        popupType: Popup.Window
        standardButtons: Dialog.NoButton
        title: "Settings"
        width: root.width

        background: Rectangle {
            anchors.fill: parent
            color: Theme.darkGray2
            opacity: parent.radius < 0 ? Math.max(0.1, 1 + parent.radius / 8) : 1
            radius: 8

            BusyIndicator {
                anchors.centerIn: parent
                visible: loader.item == null || loader.status != Loader.Ready
            }
        }
        contentItem: Item {
            anchors.fill: parent

            Item {
                id: dialogContent

                anchors.fill: parent
            }
            Skin.Button {
                id: attachButton

                activeColor: Theme.white
                anchors.right: parent.right
                anchors.top: parent.top
                text: "Attach"

                onPressed: {
                    popup.open();
                    dialog.close();
                }
            }
        }

        onAboutToShow: {
            loader.parent = dialogContent;
            loader.anchors.fill = dialogContent;
        }
    }
}
