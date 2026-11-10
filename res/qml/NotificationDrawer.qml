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

Item {
    id: root

    property alias arrow: arrow
    property alias background: background
    property var facing: ActionPopup.Facing.Top
    property var focusedNotification: null

    height: notificationLoader.height + 20
    width: 500

    Skin.FadeBehavior on visible {
        fadeTarget: root
    }

    Component.onCompleted: {
        if (Mixxx.Core.notifications.length > 0) {
            root.focusedNotification = Mixxx.Core.notifications[0];
            root.visible = true;
        }
    }

    Item {
        id: background

        anchors.fill: root
        layer.enabled: true

        layer.effect: MultiEffect {
            shadowBlur: 0.8
            shadowColor: '#c0000000'
            shadowEnabled: true
        }

        Shape {
            id: arrow

            readonly property bool isPinned: pinTo.x != 0 || pinTo.y != 0
            property point pinTo: Qt.point(0, 0)

            implicitHeight: 20
            rotation: {
                switch (root.facing) {
                case ActionPopup.Facing.Right:
                    return 180;
                case ActionPopup.Facing.Bottom:
                    return 270;
                case ActionPopup.Facing.Top:
                    return 90;
                default:
                    return 0;
                }
            }
            transformOrigin: Item.Center

            states: [
                State {
                    name: "pinned"
                    when: arrow.isPinned

                    AnchorChanges {
                        anchors.bottom: undefined
                        anchors.left: undefined
                        anchors.right: undefined
                        anchors.top: undefined
                        anchors.verticalCenter: undefined
                        target: arrow
                    }
                    PropertyChanges {
                        target: arrow
                        x: arrow.pinTo.x
                        y: arrow.pinTo.y
                    }
                },
                State {
                    when: root.facing == ActionPopup.Facing.Bottom

                    AnchorChanges {
                        anchors.bottom: arrow.parent.bottom
                        target: arrow
                    }
                },
                State {
                    when: root.facing == ActionPopup.Facing.Left

                    AnchorChanges {
                        anchors.left: arrow.parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        target: arrow
                    }
                },
                State {
                    when: root.facing == ActionPopup.Facing.Right

                    AnchorChanges {
                        anchors.right: arrow.parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        target: arrow
                    }
                },
                State {
                    when: root.facing == ActionPopup.Facing.Top

                    AnchorChanges {
                        anchors.top: arrow.parent.top
                        target: arrow
                    }
                }
            ]

            ShapePath {
                fillColor: Theme.backgroundColor
                fillRule: ShapePath.OddEvenFill
                startX: 0
                startY: 10
                strokeColor: 'transparent'
                strokeWidth: 0

                PathLine {
                    x: 20
                    y: 0
                }
                PathLine {
                    x: 20
                    y: 20
                }
                PathLine {
                    x: 0
                    y: 10
                }
            }
        }
        Rectangle {
            anchors.bottomMargin: root.facing == ActionPopup.Facing.Bottom ? 20 : 0
            anchors.fill: parent
            anchors.leftMargin: root.facing == ActionPopup.Facing.Left ? 20 : 0
            anchors.rightMargin: root.facing == ActionPopup.Facing.Right ? 20 : 0
            anchors.topMargin: root.facing == ActionPopup.Facing.Top ? 20 : 0
            border.width: 0
            color: Theme.backgroundColor
            radius: 8
        }
    }
    Item {
        ColumnLayout {
            id: content

            anchors.bottomMargin: root.facing == ActionPopup.Facing.Bottom ? 20 : 0
            anchors.fill: parent
            anchors.leftMargin: root.facing == ActionPopup.Facing.Left ? 20 : 0
            anchors.rightMargin: root.facing == ActionPopup.Facing.Right ? 20 : 0
            anchors.topMargin: root.facing == ActionPopup.Facing.Top ? 20 : 0
            spacing: 2

            Loader {
                id: notificationLoader

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
                        implicitHeight: notificationList.height
                        width: 500

                        ListView {
                            id: notificationList

                            height: Math.min(180, contentHeight)
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
                                if (Mixxx.Core.notifications.length)
                                    return;
                                root.visible = false;
                            }
                        }
                        Rectangle {
                            id: overflowIndicator

                            anchors.bottom: parent.bottom
                            color: 'transparent'
                            height: 40
                            radius: 8
                            visible: notificationList.height < notificationList.contentHeight && notificationList.contentY + notificationList.height < notificationList.contentHeight
                            width: parent.width

                            gradient: Gradient {
                                orientation: Gradient.Vertical

                                GradientStop {
                                    color: Theme.darkGray
                                    position: 1
                                }
                                GradientStop {
                                    color: 'transparent'
                                    position: 0
                                }
                            }
                            Skin.FadeBehavior on visible {
                                duration: 500
                                fadeTarget: overflowIndicator
                            }
                        }
                    }
                }
            }
        }
    }

    component NotificationDelegate: Rectangle {
        id: delegate

        required property Mixxx.Notification notification

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
                            objectName: "notificationAction_" + modelData.label
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
