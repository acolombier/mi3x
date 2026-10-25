import "." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Window 2.12
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import "Theme"

Skin.ActionPopup {
    id: root

    property var focusedNotification: null

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    facing: ActionPopup.Facing.Top
    height: (focusedNotification ? focusedItem.implicitHeight : Math.min(180, listItem.height) + bottomInset + topInset) + 20
    topPadding: 20
    width: 500

    contentItem: Loader {
        sourceComponent: root.focusedNotification ? focusedItem : listItem
    }

    Component {
        id: focusedItem

        NotificationDelegate {
            id: focused

            color: 'red'

            // layer.enabled: true
            // layer.effect: MultiEffect {
            //     shadowBlur: 0.8
            //     shadowColor: '#c0000000'
            //     shadowEnabled: true
            // }
            notification: root.focusedNotification
        }
    }
    Component {
        id: listItem

        Item {
            clip: true
            implicitHeight: notificationList.contentHeight
            width: 500

            ListView {
                id: notificationList

                height: contentHeight
                model: Mixxx.Core.notifications
                width: parent.width

                delegate: Item {
                    required property int index
                    required property var modelData

                    height: inner.height
                    width: ListView.view.width

                    NotificationDelegate {
                        id: inner

                        notification: modelData
                        width: parent.width
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        color: 'black'
                        height: 2
                        visible: index != notificationList.count - 1
                        width: parent.width
                    }
                }

                onCountChanged: {
                    if (count)
                        return;
                    root.close();
                }
            }
        }
    }

    component NotificationDelegate: Rectangle {
        id: delegate

        required property var notification

        color: 'transparent'
        implicitHeight: notificationGrid.height + 10
        width: 500

        GridLayout {
            id: notificationGrid

            columns: 2
            width: parent.width

            Item {
                Layout.fillHeight: true
                Layout.minimumWidth: 60
                Layout.rowSpan: 3

                Rectangle {
                    anchors.centerIn: parent
                    color: Qt.alpha('#FF9A9A', 0.3)
                    height: width
                    radius: width / 2
                    width: 30

                    Text {
                        anchors.fill: parent
                        color: '#ffffff'
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        text: '!'
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.minimumHeight: 25
                color: '#FFFFFF'
                font.pixelSize: 13
                font.weight: Font.DemiBold
                text: notification.text
                verticalAlignment: Text.AlignBottom
                wrapMode: Text.WrapAnywhere
            }
            Item {
                id: detailViewport

                Layout.fillWidth: true
                clip: true
                implicitHeight: scrollingText.implicitHeight
                visible: notification.details.length > 0

                Text {
                    id: scrollingText

                    readonly property var maxScrollingOffset: Math.min(0, detailViewport.width - scrollingText.width)

                    color: '#656565'
                    font.pixelSize: 13
                    text: notification.details

                    // x: detailViewport.width
                    // y: (detailViewport.height - height) / 2

                    // NumberAnimation on x {
                    //     running: scrollingText.width > scrollingText.parent.width
                    //     from: detaildetailViewport.width
                    //     to: -scrollingText.width
                    //     duration: 8000
                    //     loops: Animation.Infinite
                    // }
                    SequentialAnimation {
                        id: tickerAnimation

                        loops: Animation.Infinite
                        running: true // scrollingText.width > scrollingText.parent.width

                        // 1. Let the beginning be read
                        PauseAnimation {
                            duration: 1000
                        }

                        // 2. Scroll slowly to reveal the end
                        NumberAnimation {
                            duration: Math.max(2500, (scrollingText.width - detailViewport.width) * 25)
                            easing.type: Easing.Linear
                            property: "x"
                            target: scrollingText
                            to: scrollingText.maxScrollingOffset
                        }

                        // 3. Keep the end visible
                        PauseAnimation {
                            duration: 1000
                        }

                        // 4. Fade out
                        NumberAnimation {
                            duration: 350
                            easing.type: Easing.InOutQuad
                            property: "opacity"
                            target: scrollingText
                            to: 0
                        }

                        // 5. Reset position and opacity
                        PropertyAction {
                            property: "x"
                            target: scrollingText
                            value: 0
                        }
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.InOutQuad
                            property: "opacity"
                            target: scrollingText
                            to: 1
                        }
                    }
                }
                Rectangle {
                    id: leftGradient

                    color: 'transparent'
                    opacity: scrollingText.x == 0 ? 0 : 1
                    width: 10

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            color: delegate.color
                            position: 0
                        }
                        GradientStop {
                            color: 'transparent'
                            position: 1
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 500
                        }
                    }

                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        top: parent.top
                    }
                }
                Rectangle {
                    id: rightGradient

                    color: 'transparent'
                    opacity: scrollingText.x == scrollingText.maxScrollingOffset ? 0 : 1
                    width: 10

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            color: delegate.color
                            position: 1
                        }
                        GradientStop {
                            color: 'transparent'
                            position: 0
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 500
                        }
                    }

                    anchors {
                        bottom: parent.bottom
                        right: parent.right
                        top: parent.top
                    }
                }
            }
            RowLayout {
                Item {
                    Layout.fillWidth: true
                }
                Repeater {
                    model: notification.buttons

                    Item {
                        required property var modelData

                        Layout.preferredHeight: 15
                        Layout.preferredWidth: button.implicitWidth
                        Layout.rightMargin: 10

                        Skin.Button {
                            id: button

                            activeColor: Theme.white
                            text: modelData.label

                            onClicked: modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
