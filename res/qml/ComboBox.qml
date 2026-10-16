import "." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Shapes
import QtQuick.Effects
import "Theme"

ComboBox {
    id: root

    property bool clip: false
    property list<var> footerItems: []
    property int popupMaxItem: 6
    property alias popupWidth: popupItem.width

    signal activateFooter(int index)

    implicitHeight: 24
    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset, implicitContentWidth + leftPadding + rightPadding)
    leftPadding: 4
    rightPadding: 6

    background: Rectangle {
        id: background

        border.color: '#000000'
        border.width: 1
        color: '#232323'
        implicitHeight: root.implicitHeight
        radius: 4
    }
    // MultiEffect {
    //     anchors.fill: parent
    //     source: background
    //     shadowEnabled: true
    //     shadowColor: "#40000000"
    //     shadowBlur: 0.06
    // }
    // }
    contentItem: Text {
        clip: root.clip
        color: Theme.deckTextColor
        elide: root.clip ? Text.ElideNone : Text.ElideRight
        font: root.font
        leftPadding: 5
        rightPadding: root.indicator.width + root.spacing
        text: root.displayText
        verticalAlignment: Text.AlignVCenter
    }
    delegate: ItemDelegate {
        id: itemDlgt

        required property int index

        highlighted: root.highlightedIndex === this.index
        objectName: root.objectName ? root.objectName + "_option_" + index : ""
        padding: 4
        text: root.textAt(this.index)
        verticalPadding: 8
        width: popupItem.width

        background: Rectangle {
            border.color: itemDlgt.highlighted ? Theme.deckLineColor : "transparent"
            border.width: 1
            color: "transparent"
            radius: 5
        }
        contentItem: Text {
            color: Theme.deckTextColor
            elide: Text.ElideRight
            font: root.font
            text: itemDlgt.text
            verticalAlignment: Text.AlignVCenter
        }
    }
    indicator: Item {
        height: 24
        width: height
        x: root.mirrored ? root.padding : root.width - width - root.padding
        y: root.topPadding

        Rectangle {
            color: root.background.border.color
            width: 1

            anchors {
                bottom: parent.bottom
                left: parent.left
                top: parent.top
            }
        }
        Canvas {
            id: canvas

            readonly property real radius: 3

            function roundTriangle(ctx, w, h, inset) {
                const p = [
                    {
                        x: 0,
                        y: 0
                    },
                    {
                        x: w,
                        y: 0
                    },
                    {
                        x: w / 2,
                        y: h
                    }
                ];

                ctx.beginPath();

                for (let i = 0; i < 3; ++i) {
                    const a = p[(i + 2) % 3];
                    const b = p[i];
                    const c = p[(i + 1) % 3];

                    const abx = a.x - b.x, aby = a.y - b.y;
                    const cbx = c.x - b.x, cby = c.y - b.y;

                    const lab = Math.hypot(abx, aby);
                    const lcb = Math.hypot(cbx, cby);

                    const ux = abx / lab, uy = aby / lab;
                    const vx = cbx / lcb, vy = cby / lcb;

                    const angle = Math.acos(ux * vx + uy * vy);
                    const r = inset * Math.tan(angle / 2);

                    const s = {
                        x: b.x + ux * inset,
                        y: b.y + uy * inset
                    };
                    const e = {
                        x: b.x + vx * inset,
                        y: b.y + vy * inset
                    };

                    if (i === 0)
                        ctx.moveTo(s.x, s.y);
                    else
                        ctx.lineTo(s.x, s.y);

                    ctx.arcTo(b.x, b.y, e.x, e.y, r);
                }

                ctx.closePath();
            }

            anchors.centerIn: parent
            anchors.topMargin: 2
            contextType: "2d"
            height: 12
            width: 12

            onPaint: {
                context.reset();
                roundTriangle(context, width, height, radius);
                context.fillStyle = Qt.alpha(Theme.midGray3, root.enabled ? 1 : 0.3);

                context.fill();
            }

            Connections {
                function onPressedChanged() {
                    canvas.requestPaint();
                }
                function onVisibleChanged() {
                    canvas.requestPaint();
                }

                target: root
            }
        }
    }
    popup: Popup {
        id: popupItem

        readonly property bool reversed: {
            // Geometry binding
            root.Window.contentItem.height + opened;
            print(contentItem.mapToItem(root.Window.contentItem, 0, 0, 0, 0), root.mapToItem(root.Window.contentItem, 0, 0, 0, 0));
            return contentItem.mapToItem(root.Window.contentItem, 0, 0, 0, 0).y < root.mapToItem(root.Window.contentItem, 0, 0, 0, 0).y;
        }

        height: root.contentItem.height * (Math.min(root.popupMaxItem, Math.max(root.count, 1)) + 1)
        padding: 0
        width: root.width
        x: root.width - width
        y: root.height - 4

        background: Item {
        }
        contentItem: Item {
            Item {
                id: content

                anchors.fill: parent
                layer.enabled: true

                layer.effect: MultiEffect {
                    shadowBlur: 0.1
                    shadowColor: "#000000"
                    shadowEnabled: true
                }

                Shape {
                    id: listIndicator

                    property int multiSamplingLevel: Mixxx.Config.multiSamplingLevel

                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.top: parent.top
                    antialiasing: true
                    height: 10
                    layer.enabled: multiSamplingLevel > 1
                    layer.samples: multiSamplingLevel
                    width: 16

                    states: State {
                        when: popupItem.reversed

                        AnchorChanges {
                            anchors.bottom: content.bottom
                            anchors.top: undefined
                            target: listIndicator
                        }
                    }
                    transform: Rotation {
                        angle: popupItem.reversed ? 180 : 0
                        origin.x: listIndicator.width / 2
                        origin.y: listIndicator.height / 2
                    }

                    ShapePath {
                        capStyle: ShapePath.RoundCap
                        fillColor: Theme.embeddedBackgroundColor
                        fillRule: ShapePath.WindingFill
                        startX: listIndicator.width / 2
                        startY: 0
                        strokeColor: Theme.embeddedBackgroundColor
                        strokeWidth: 2

                        PathLine {
                            x: listIndicator.width
                            y: listIndicator.height
                        }
                        PathLine {
                            x: 0
                            y: listIndicator.height
                        }
                        PathLine {
                            x: listIndicator.width / 2
                            y: 0
                        }
                    }
                }
                Skin.EmbeddedBackground {
                    anchors.bottom: popupItem.reversed ? listIndicator.top : parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: popupItem.reversed ? parent.top : listIndicator.bottom
                    clip: true

                    ListView {
                        anchors.fill: parent
                        bottomMargin: 0
                        clip: true
                        currentIndex: root.highlightedIndex
                        leftMargin: 0
                        model: root.popup.visible ? root.delegateModel : null
                        objectName: root.objectName ? root.objectName + "_popupList" : ""
                        rightMargin: 0
                        topMargin: 0

                        ScrollIndicator.vertical: ScrollIndicator {
                        }
                        footer: Item {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: childrenRect.height

                            Repeater {
                                model: root.footerItems

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    color: "transparent"
                                    height: root.contentItem.height
                                    y: index * height

                                    Item {
                                        anchors.fill: parent
                                        anchors.margins: 6

                                        Text {
                                            anchors.bottom: parent.bottom
                                            anchors.top: parent.top
                                            color: Theme.deckTextColor
                                            elide: Text.ElideRight
                                            font: root.font
                                            text: modelData.text
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        Text {
                                            anchors.bottom: parent.bottom
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            color: Theme.deckTextColor
                                            font.pixelSize: 16
                                            text: modelData?.suffix || ''
                                        }
                                    }
                                    MouseArea {
                                        id: footerItemMouseArea

                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor

                                        onPressed: {
                                            root.activateFooter(index);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        onClosed: {
            Mixxx.Core.removeOpenedPopup(this);
        }
        onOpened: {
            Mixxx.Core.addOpenedPopup(this);
        }
    }
}
