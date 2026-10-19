import QtQml
import QtQuick
import QtQml.Models
import QtQuick.Layouts
import QtQuick.Controls 2.15
import QtQuick.Shapes 1.12
import QtQuick.Effects
import Mixxx 1.0 as Mixxx
import "Theme"

Popup {
    id: root

    enum Facing {
        Left,
        Top,
        Right,
        Bottom
    }

    default property alias children: content.children
    property variant facing: ActionPopup.Facing.Left

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    leftInset: 0
    margins: 0
    padding: 0
    width: 200

    background: Item {
        Item {
            id: content3

            anchors.fill: parent

            Shape {
                anchors.bottom: root.facing == ActionPopup.Facing.Bottom ? parent.bottom : undefined
                anchors.left: root.facing == ActionPopup.Facing.Left ? parent.left : undefined
                anchors.right: root.facing == ActionPopup.Facing.Right ? parent.right : undefined
                anchors.top: root.facing == ActionPopup.Facing.Top ? parent.top : undefined
                anchors.verticalCenter: parent.verticalCenter
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
        MultiEffect {
            anchors.fill: parent
            shadowBlur: 0.1
            shadowColor: "#80000000"
            shadowEnabled: true
            source: content3
        }
    }
    contentItem: Item {
        ColumnLayout {
            id: content

            anchors.bottomMargin: root.facing == ActionPopup.Facing.Bottom ? 20 : 0
            anchors.fill: parent
            anchors.leftMargin: root.facing == ActionPopup.Facing.Left ? 20 : 0
            anchors.rightMargin: root.facing == ActionPopup.Facing.Right ? 20 : 0
            anchors.topMargin: root.facing == ActionPopup.Facing.Top ? 20 : 0
            spacing: 2
        }
    }

    onClosed: {
        Mixxx.Core.removeOpenedPopup(this);
    }
    onOpened: {
        Mixxx.Core.addOpenedPopup(this);
    }
}
