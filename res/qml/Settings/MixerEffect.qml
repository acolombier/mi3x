import ".." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import "../Theme"

import "./Controller/" as Components

Category {
    label: "Mixer & Effects"

    Rectangle {
        id: root

        function selectTab(tab) {
            console.log(tab);
        }

        anchors.fill: parent
        color: '#0E0E0E'
        radius: 5

        ColumnLayout {
            anchors.fill: parent

            RowLayout {
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.margins: 15
                    color: '#D9d9d9'
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    text: "Reloop Terminal Mix 2"
                }
            }
            RowLayout {
                Layout.margins: 15

                Text {
                    Layout.fillWidth: true
                    color: "#D9D9D9"
                    font.pixelSize: 14
                    text: "Mapping name"
                }
                RatioChoice {
                    options: ["soundcard", "network"]
                }
                Item {
                    Layout.preferredWidth: 70
                }
                Text {
                    Layout.fillWidth: true
                    color: "#D9D9D9"
                    font.pixelSize: 14
                    text: "Author"
                }
                RatioChoice {
                    options: ["44100 hz", "48000 hz", "96000 hz"]
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.margins: 6
                Layout.preferredHeight: 1
                color: '#626262'
            }
            Rectangle {
                id: designer

                // component rect: Rectangle {
                //     width: 20; height: 20
                //     color: "red"

                //     Drag.active: dragArea.drag.active
                //     Drag.hotSpot.x: 10
                //     Drag.hotSpot.y: 10

                //     MouseArea {
                //         id: dragArea
                //         anchors.fill: parent

                //         drag.target: parent
                //     }
                // }
                property var copiedItem: null
                property var defaultComponents: {}
                property var selectedItem: null

                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.margins: 8
                clip: true
                color: '#292929'
                focus: true

                Component.onCompleted: () => {
                    let obj = new Object();
                    obj[Mixxx.ControllerElement.Type.Button] = Qt.createComponent("Controller/Button.qml");
                    obj[Mixxx.ControllerElement.Type.Knob] = Qt.createComponent("Controller/Knob.qml");
                    obj[Mixxx.ControllerElement.Type.Encoder] = Qt.createComponent("Controller/Encoder.qml");
                    obj[Mixxx.ControllerElement.Type.Fader] = Qt.createComponent("Controller/Fader.qml");
                    obj[Mixxx.ControllerElement.Type.Zone] = Qt.createComponent("Controller/Zone.qml");

                    let comp = new Object();

                    for (let [type, value] of Object.entries(obj)) {
                        if (value.status === Component.Ready) {
                            comp[type] = value;
                        } else {
                            console.warn(value.errorString());
                        }
                    }

                    designer.defaultComponents = comp;
                    console.log(`created ${designer.defaultComponents}`);
                    controller.load();
                }
                Keys.onPressed: e => {
                    if ((e.key == Qt.Key_C) && (e.modifiers & Qt.ControlModifier) && designer.selectedItem) {
                        copiedItem = designer.selectedItem;
                        console.log(`copy ${designer.selectedItem}`);
                    } else if ((e.key == Qt.Key_V) && (e.modifiers & Qt.ControlModifier) && designer.copiedItem) {
                        copiedItem = designer.defaultComponents[copiedItem.type].createObject(controller, designer.copiedItem.duplicateProperty());
                        copiedItem.focus = true;
                        console.log(`paste ${designer.copiedItem}`);
                    } else {
                        console.log(`Pressed: ${e.key} (${designer.selectedItem}))`);
                    }
                }

                Rectangle {
                    id: toolbox

                    color: '#3F3F3F'
                    height: toolboxContent.implicitHeight + 10
                    radius: 4
                    visible: !lock.checked
                    width: 28

                    anchors {
                        bottom: lock.top
                        bottomMargin: 15
                        right: parent.right
                        rightMargin: 5
                    }
                    ColumnLayout {
                        id: toolboxContent

                        anchors.centerIn: parent

                        Repeater {
                            model: Object.keys(designer.defaultComponents)

                            Item {
                                id: holder

                                required property string modelData

                                Component.onCompleted: () => {
                                    let props = {
                                        attached: {
                                            v: holder.verticalCenter,
                                            h: holder.horizontalCenter
                                        }
                                    };
                                    if (Mixxx.ControllerElement.Type.Zone == modelData) {
                                        props = Object.assign({
                                            components: designer.defaultComponents,
                                            width: 20,
                                            height: 20
                                        }, props);
                                    }
                                    console.log(`creating ${modelData} ${props} ${designer.defaultComponents}`);
                                    let comp = designer.defaultComponents[modelData].createObject(holder, props);
                                    if (comp) {
                                        height = comp.height;
                                        width = comp.width;
                                    }
                                }
                            }
                        }
                    }
                }
                ColumnLayout {
                    anchors.fill: parent

                    Item {
                        id: canvas

                        function onItemSelected(item) {
                            console.log(item);
                            if (item instanceof Components.Base || item == null) {
                                console.log(`selected ${item}`);
                                designer.selectedItem = item;
                            } else if (item == null && designer.selectedItem != null) {
                                designer.selectedItem.focus = false;
                                designer.selectedItem = null;
                            }
                        }

                        Layout.fillHeight: true
                        Layout.fillWidth: true

                        Rectangle {
                            id: itemOverlay

                            anchors.fill: parent
                            color: 'transparent'
                            visible: !!designer.selectedItem
                            z: 200

                            MouseArea {
                                anchors.fill: parent

                                onPressed: {
                                    designer.selectedItem = null;
                                }
                            }
                            Repeater {
                                model: designer.selectedItem ? 1 : 0

                                Item {
                                    id: option

                                    height: propertyArea.height + 30
                                    width: 220
                                    x: designer.selectedItem ? designer.selectedItem.mapToItem(option, designer.selectedItem.width / 2, 0).x - 110 : 0
                                    y: designer.selectedItem ? designer.selectedItem.mapToItem(option, 0, designer.selectedItem.height).y : 0

                                    Item {
                                        id: content

                                        anchors.fill: parent
                                        height: propertyArea.height + 30
                                        visible: false

                                        Shape {
                                            id: arrow

                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.top: parent.top
                                            height: 15
                                            width: 16

                                            ShapePath {
                                                fillColor: "#242424"
                                                startX: 8
                                                startY: 0
                                                strokeColor: "transparent"

                                                PathLine {
                                                    x: 16
                                                    y: 15
                                                }
                                                PathLine {
                                                    x: 0
                                                    y: 15
                                                }
                                                PathLine {
                                                    x: 8
                                                    y: 0
                                                }
                                            }
                                        }
                                        Rectangle {
                                            id: propertyFrame

                                            color: '#242424'
                                            height: propertyArea.height
                                            radius: 8

                                            anchors {
                                                left: parent.left
                                                right: parent.right
                                                // bottom: parent.bottom
                                                top: arrow.bottom
                                            }
                                        }
                                    }
                                    DropShadow {
                                        id: effect

                                        anchors.fill: parent
                                        color: "#b0000000"
                                        horizontalOffset: 0
                                        radius: 8.0
                                        source: content
                                        verticalOffset: 0
                                    }
                                    Rectangle {
                                        id: propertyArea

                                        color: "transparent"

                                        anchors {
                                            left: content.left
                                            leftMargin: 4
                                            right: parent.right
                                            top: parent.top
                                            topMargin: 20
                                        }
                                        // height: lockedColumn.item ? lockedColumn.item.implicitHeight:0 + unlockedColumn.item ? unlockedColumn.item.implicitHeight:0

                                        Repeater {
                                            id: lockedColumn

                                            model: designer.selectedItem.locked ? 1 : 0
                                            width: propertyArea.width

                                            ColumnLayout {
                                                width: propertyArea.width - 8

                                                Component.onCompleted: {
                                                    propertyArea.height = implicitHeight + 12;
                                                }

                                                RowLayout {
                                                    Text {
                                                        Layout.fillWidth: true
                                                        color: "#D9D9D9"
                                                        font.pixelSize: 14
                                                        text: "Name"
                                                    }
                                                    Text {
                                                        color: "#8A8A8A"
                                                        font.pixelSize: 10
                                                        text: "Left deck"
                                                    }
                                                    Text {
                                                        color: "#D9D9D9"
                                                        font.pixelSize: 11
                                                        text: "Hotcue 6"
                                                    }
                                                }
                                                RowLayout {
                                                    Text {
                                                        Layout.fillWidth: true
                                                        color: "#D9D9D9"
                                                        font.pixelSize: 14
                                                        text: "Type"
                                                    }
                                                    Skin.ComboBox {
                                                        Layout.fillWidth: true
                                                        model: ["Push button", "Toggle",]
                                                    }
                                                }
                                                RowLayout {
                                                    Text {
                                                        color: "#D9D9D9"
                                                        font.pixelSize: 14
                                                        text: "Action"
                                                    }
                                                    Skin.ComboBox {
                                                        Layout.fillWidth: true
                                                        implicitWidth: 130
                                                        indicator.width: 20
                                                        model: ["Deck 1: Activate hotcue"]
                                                        spacing: 0
                                                    }
                                                }
                                                RowLayout {
                                                    Item {
                                                        Layout.fillWidth: true
                                                    }
                                                    Skin.Button {
                                                        activeColor: "#7D3B3B"
                                                        text: "Learn"
                                                    }
                                                }
                                            }
                                        }
                                        Repeater {
                                            id: unlockedColumn

                                            model: designer.selectedItem.locked ? 0 : 1

                                            ColumnLayout {
                                                Layout.margins: 4

                                                Component.onCompleted: {
                                                    propertyArea.height = implicitHeight;
                                                }

                                                RowLayout {
                                                    Text {
                                                        Layout.fillWidth: true
                                                        color: "#D9D9D9"
                                                        font.pixelSize: 14
                                                        text: "Label"
                                                    }
                                                    TextInput {
                                                        color: "#626262"
                                                        text: designer.selectedItem.label
                                                        width: 40
                                                    }
                                                }
                                                RowLayout {
                                                    Text {
                                                        Layout.fillWidth: true
                                                        color: "#D9D9D9"
                                                        font.pixelSize: 14
                                                        text: "Width"
                                                    }
                                                    SpinBox {
                                                        editable: true
                                                        stepSize: 1
                                                        textFromValue: function (value, locale) {
                                                            return `${value} mm`;
                                                        }
                                                        to: 2000
                                                        value: designer.selectedItem.widthInMm
                                                        valueFromText: function (text, locale) {
                                                            return text.split(' ')[0];
                                                        }

                                                        onValueModified: {
                                                            designer.selectedItem.width = value / designer.selectedItem.mmPerPixel;
                                                        }
                                                    }
                                                }
                                                RowLayout {
                                                    Text {
                                                        Layout.fillWidth: true
                                                        color: "#D9D9D9"
                                                        font.pixelSize: 14
                                                        text: "Height"
                                                    }
                                                    SpinBox {
                                                        editable: true
                                                        stepSize: 1
                                                        textFromValue: function (value, locale) {
                                                            return `${value} mm`;
                                                        }
                                                        to: 2000
                                                        value: designer.selectedItem.heightInMm
                                                        valueFromText: function (text, locale) {
                                                            return text.split(' ')[0];
                                                        }

                                                        onValueModified: {
                                                            designer.selectedItem.height = value / designer.selectedItem.mmPerPixel;
                                                        }
                                                    }
                                                }
                                                Repeater {
                                                    model: designer.selectedItem.hasOwnProperty("grid") ? 1 : 0

                                                    RowLayout {
                                                        Text {
                                                            Layout.fillWidth: true
                                                            color: "#D9D9D9"
                                                            font.pixelSize: 14
                                                            text: "Grid"
                                                        }
                                                        SpinBox {
                                                            editable: true
                                                            stepSize: 1
                                                            textFromValue: function (value, locale) {
                                                                return `${value} mm`;
                                                            }
                                                            to: 2000
                                                            value: designer.selectedItem.grid * designer.selectedItem.mmPerPixel
                                                            valueFromText: function (text, locale) {
                                                                return text.split(' ')[0];
                                                            }

                                                            onValueModified: {
                                                                designer.selectedItem.grid = value / designer.selectedItem.mmPerPixel;
                                                            }
                                                        }
                                                    }
                                                }
                                                RowLayout {
                                                    Text {
                                                        Layout.fillWidth: true
                                                        color: "#D9D9D9"
                                                        font.pixelSize: 14
                                                        text: "Align on grid"
                                                    }
                                                    RatioChoice {
                                                        options: ["on", "off"]
                                                        selected: options[designer.selectedItem.lockedOnGrid ? 0 : 1]

                                                        onSelectedChanged: {
                                                            designer.selectedItem.lockedOnGrid = selected == "on";
                                                        }
                                                    }
                                                }
                                                Repeater {
                                                    model: designer.selectedItem.hasOwnProperty("round") ? 1 : 0

                                                    RowLayout {
                                                        Text {
                                                            Layout.fillWidth: true
                                                            color: "#D9D9D9"
                                                            font.pixelSize: 14
                                                            text: "Round"
                                                        }
                                                        RatioChoice {
                                                            options: ["on", "off"]
                                                            selected: options[designer.selectedItem.round ? 0 : 1]

                                                            onSelectedChanged: {
                                                                designer.selectedItem.round = selected == "on";
                                                            }
                                                        }
                                                    }
                                                }
                                                Repeater {
                                                    model: designer.selectedItem.hasOwnProperty("vertical") ? 1 : 0

                                                    RowLayout {
                                                        Text {
                                                            Layout.fillWidth: true
                                                            color: "#D9D9D9"
                                                            font.pixelSize: 14
                                                            text: "Orientation"
                                                        }
                                                        RatioChoice {
                                                            options: ["horizontal", "vertical"]
                                                            selected: options[designer.selectedItem.vertical ? 0 : 1]

                                                            onSelectedChanged: {
                                                                designer.selectedItem.vertical = selected == "on";
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent

                            // propagateComposedEvents: true
                            onWheel: e => {
                                canvas.onItemSelected(null);
                                if (e.angleDelta.y < 0) {
                                    if (e.modifiers & Qt.ControlModifier) {
                                        controller.zoomFactor -= 0.1;
                                    } else if (e.modifiers & Qt.ShiftModifier) {
                                        controller.offset.x -= 20 / controller.zoomFactor;
                                    } else {
                                        controller.offset.y -= 20 / controller.zoomFactor;
                                    }
                                } else {
                                    if (e.modifiers & Qt.ControlModifier) {
                                        controller.zoomFactor += 0.1;
                                    } else if (e.modifiers & Qt.ShiftModifier) {
                                        controller.offset.x += 20 / controller.zoomFactor;
                                    } else {
                                        controller.offset.y += 20 / controller.zoomFactor;
                                    }
                                }
                                console.log(`wheel: ${e.angleDelta} ${Object.keys(controller.transform)} ${controller.zoomFactor} ${controller.offset} ${e.modifiers}`);
                            }

                            Components.Controller {
                                id: controller

                                property point offset: Qt.point(controller.width / 2, controller.height / 2)
                                property real zoomFactor: 1.6

                                anchors.centerIn: parent
                                components: designer.defaultComponents
                                height: 320
                                locked: lock.checked
                                width: 440
                                x: (parent.width - width) / 2
                                y: (parent.height - height) / 2

                                transform: Scale {
                                    xScale: controller.zoomFactor
                                    yScale: controller.zoomFactor

                                    origin {
                                        x: controller.offset.x
                                        y: controller.offset.y
                                        z: 0
                                    }
                                }

                                onSelected: item => canvas.onItemSelected(item)

                                Image {
                                    id: controllerVisual

                                    fillMode: Image.PreserveAspectCrop
                                    height: parent.height
                                    source: 'images/controller_mapping.png'
                                    width: parent.width
                                }
                                Rectangle {
                                    id: overlay

                                    anchors.fill: parent
                                    border.color: '#0E0E0E'
                                    border.width: 1
                                    // height: controllerVisual.height
                                    // width: controllerVisual.width
                                    color: '#b8aaaaaa'
                                }
                            }
                        }
                    }
                }
                Skin.Button {
                    id: lock

                    activeColor: Theme.white
                    checkable: true
                    implicitWidth: implicitHeight

                    contentItem: Item {
                        Shape {
                            anchors.centerIn: parent
                            antialiasing: true
                            height: 15
                            layer.enabled: true
                            layer.samples: 4
                            width: 13

                            ShapePath {
                                fillColor: 'transparent'
                                startX: 2
                                startY: 7.5
                                strokeColor: '#D9D9D9'

                                // PathSvg { path: "M2.01074 8.06097C2.01074 -1.35374 11.0594 -1.35378 11.0594 8.0614" }
                                PathQuad {
                                    controlX: 0
                                    controlY: 0
                                    x: 6.5
                                    y: 0
                                }
                                PathQuad {
                                    controlX: 15
                                    controlY: 0
                                    x: 11
                                    y: 7.5
                                }
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                color: '#D9D9D9'
                                height: 8
                                width: 13
                            }
                        }
                        // Rectangle {
                        //     color: 'red'
                        //     anchors.centerIn: parent
                        //     width: 10
                        //     height: 10
                        // }
                    }

                    // checked: true
                    onClicked: {
                        console.log("foo");
                        // Mixxx.PreferencesDialog.show();
                    }

                    anchors {
                        bottom: parent.bottom
                        bottomMargin: 5
                        right: parent.right
                        rightMargin: 5
                    }
                }
            }
        }
    }
}
