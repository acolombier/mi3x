import "MidnightDark" as Skin
import "MidnightDark/Theme" as Theme
import Mixxx 1.0 as Mixxx
import QtQuick

Mixxx.Skin {
    // Here are some example of what to expect
    name: "Midnight Dark"
    version: "1.0"
    description: "A new way of using Mixxx"
    // This would replace the naive QML singleton, such that it can still be declared purely in QML, but the backend handles which palette is live
    colorPalettes: [
        // MidnightDark.Palettes.Default,
        // MidnightDark.Palettes.Bright,
        // MidnightDark.Palettes.HighContrast,
    ]
    // The following could be used to help filtering available themes (e.g a small smartphone screen would skip incompatible skins) and help with initial/reset geometry
    defaultHeight: 1008
    defaultWidth: 1792
    minimumWidth: 680
    minimumHeight: 300
    loader: Component {
        Rectangle {
            id: splash

            property bool ready: false

            anchors.fill: parent
            color: Theme.Theme.backgroundColor

            states: [
                State {
                    when: splash.ready

                    PropertyChanges {
                        logo.opacity: 1
                        logo.y: parent.height / 2 - logo.height / 2
                        text.opacity: 1
                    }
                },
                State {
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
                y: splash.height / 2

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
                color: Theme.Theme.lightGray3
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
    }

    main: Component {
        Skin.Main {
        }
    }
}
