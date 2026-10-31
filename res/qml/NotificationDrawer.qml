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

        Component {
            id: focusedItem

            NotificationDelegate {
                id: focused

                color: Theme.backgroundColor
                layer.enabled: true
                notification: root.focusedNotification

                layer.effect: MultiEffect {
                    shadowBlur: 0.8
                    shadowColor: '#c0000000'
                    shadowEnabled: true
                }
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
    }

    Component.onCompleted: {
        if (Mixxx.Core.notifications) {
            root.focusedNotification = Mixxx.Core.notifications[0];
            root.open();
        }
    }

    component NotificationDelegate: Rectangle {
        id: delegate

        required property var notification

        function isLevel(level) {
            return (notification.flags & level) == level;
        }

        color: 'transparent'
        implicitHeight: notificationGrid.height + 10
        width: 500

        GridLayout {
            id: notificationGrid

            columns: 2
            width: parent.width

            Item {
                readonly property color color: {
                    if (delegate.isLevel(Mixxx.Notification.Flags.Warn)) {
                        return '#ded600';
                    }
                    if (delegate.isLevel(Mixxx.Notification.Flags.Error)) {
                        return '#FF9A9A';
                    }
                    if (delegate.isLevel(Mixxx.Notification.Flags.Critical)) {
                        return '#ff2f2f';
                    }
                    return '#9AEDFF';
                }

                Layout.fillHeight: true
                Layout.minimumWidth: 60
                Layout.rowSpan: 3

                Rectangle {
                    anchors.centerIn: parent
                    color: Qt.alpha(parent.color, 0.3)
                    height: width
                    radius: width / 2
                    width: 30

                    Text {
                        anchors.fill: parent
                        color: '#ffffff'
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        text: {
                            if (delegate.isLevel(Mixxx.Notification.Flags.Warn) || delegate.isLevel(Mixxx.Notification.Flags.Error)) {
                                return '!';
                            }
                            if (delegate.isLevel(Mixxx.Notification.Flags.Critical)) {
                                return '!!';
                            }
                            return '?';
                        }
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
                text: notification?.text
                verticalAlignment: Text.AlignBottom
                wrapMode: Text.WrapAnywhere
            }
            ScrollingText {
                id: detailViewport

                Layout.fillWidth: true
                color: delegate.color
                visible: notification?.details.length > 0
                wrap: notification.flags & Mixxx.Notification.Flags.Wrap ? Text.Wrap : Text.NoWrap

                text {
                    color: '#656565'
                    font.pixelSize: 13
                    text: notification?.details
                }
            }
            RowLayout {
                Layout.rightMargin: 5

                Item {
                    Layout.fillWidth: true
                }
                Repeater {
                    model: notification.buttons

                    Item {
                        required property var modelData

                        Layout.bottomMargin: 5
                        Layout.preferredHeight: 15
                        Layout.preferredWidth: button.implicitWidth
                        Layout.rightMargin: 0

                        Skin.Button {
                            id: button

                            activeColor: Theme.white
                            implicitWidth: Math.max(52, fontMetrics.advanceWidth + 8)
                            text: modelData.label

                            onClicked: modelData.invoke()
                        }
                        TextMetrics {
                            id: fontMetrics

                            font: button.font
                            text: button.text
                        }
                    }
                }
            }
        }
    }
}
