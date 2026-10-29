import "." as Skin
import Mixxx 1.0 as Mixxx
import Mixxx.Controls 1.0 as MixxxControls
import QtQuick 2.12
import QtQuick.Controls
import QtQuick.Window 2.12
import "Theme"

ApplicationWindow {
    id: root

    readonly property int designHeight: 1008
    readonly property int designWidth: 1792

    // Used to show click interaction on the Window. Mainly relevant on automated testing
    property bool enableDiagnosticClick: false
    readonly property bool isMobile: Qt.platform.os === "android" || Qt.platform.os === "ios"

    // Window-wide gesture router, reachable from anywhere via
    // Window.window.touchHub. It lives at the bottom of the scene so it only
    // sees presses that nothing else accepted.
    readonly property alias touchHub: touchHubArea

    color: Theme.backgroundColor
    height: isMobile ? Screen.height : designHeight
    minimumHeight: isMobile ? 0 : 300
    minimumWidth: isMobile ? 0 : 680
    objectName: "mainWindow"
    visible: true
    width: isMobile ? Screen.width : designWidth

    Component.onCompleted: {
        Mixxx.Core.clearOpenedPopup();
    }

    Connections {
        function onReadyChanged() {
            root.visibility = Mixxx.Config.configStartInFullscreenKey || isMobile ? Window.FullScreen : Window.Windowed;
        }

        target: Mixxx.Core
    }
    MixxxControls.TouchHub {
        id: touchHubArea

        anchors.fill: parent
        z: -1
    }
    Loader {
        id: content

        active: Mixxx.Core.ready
        anchors.fill: parent
        asynchronous: true

        sourceComponent: Component {
            MainWindow {
                enableDiagnosticClick: root.enableDiagnosticClick
            }
        }

        onStatusChanged: {
            if (status === Loader.Error) {
                console.error("Failed to load the Mixxx main window");
                Qt.quit();
            } else if (status === Loader.Ready) {
                // Keep the loader synchronous going forward so all UI operation such as layout
                // invalidation won't induce weird visual artifacts or delays.
                content.asynchronous = false;
            }
        }
    }
    Rectangle {
        id: splash

        property bool ready: false

        anchors.fill: parent
        color: Theme.backgroundColor
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 500
                easing.type: Easing.InOutQuad
            }
        }
        states: [
            State {
                when: splash.ready && content.status != Loader.Ready

                PropertyChanges {
                    logo.opacity: 1
                    logo.y: root.height / 2 - logo.height / 2
                    text.opacity: 1
                }
            },
            State {
                when: content.status == Loader.Ready && content.active

                PropertyChanges {
                    splash.opacity: 0
                }
            }
        ]

        Component.onCompleted: {
            ready = true;
        }

        Image {
            id: logo

            anchors.horizontalCenter: parent.horizontalCenter
            // height: 64
            opacity: 0
            source: "qrc:/images/mixxx-icon-logo-symbolic.svg"
            y: root.height / 2

            Behavior on opacity {
                NumberAnimation {
                    duration: 1500
                    easing.type: Easing.InOutQuad
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: 1500
                    easing.type: Easing.InOutQuad
                }
            }
        }
        Text {
            id: text

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 20
            color: Theme.lightGray3
            font.pixelSize: 12
            opacity: 0
            text: "DJ your way"
            y: logo.y + logo.height * 2

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: 1000
                    }
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.InOutQuad
                    }
                }
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
}
