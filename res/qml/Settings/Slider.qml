import QtQuick 2.12
import QtQuick.Effects
import QtQuick.Controls
import "../Theme"

Item {
    id: root

    readonly property int decimalFactor: Math.pow(10, decimals)
    property int decimals: 0
    property int margins: 7
    property list<double> markers: []
    property double max: markers.length ? markers[markers.length - 1] : 1
    property double min: markers.length ? markers[0] : 0
    property bool showTextInput: true
    property alias slider: control
    property alias suffix: textInputSection.suffix
    property double value: 0
    property double wheelStep: 1

    function ratioToValue(ratio) {
        const bounds = valueBounds();
        const intervalCount = bounds.length - 1;
        if (intervalCount <= 0) {
            return bounds[0];
        }
        const clampedRatio = Math.max(0, Math.min(1, ratio));
        const scaled = clampedRatio * intervalCount;
        const lower = Math.min(Math.floor(scaled), intervalCount - 1);
        return bounds[lower] + (scaled - lower) * (bounds[lower + 1] - bounds[lower]);
    }
    function serialize() {
        return JSON.stringify({
            max: root.max,
            min: root.min,
            markers: root.markers
        });
    }
    function setValue(value) {
        root.value = value;
        const ratio = valueToRatio(root.value);
        if (Math.abs(control.value - ratio) > 1e-9) {
            control.value = ratio;
        }
    }
    function textFromValue(value, locale) {
        return Number(Math.round(value * decimalFactor) / decimalFactor).toLocaleString(locale, 'f', root.decimals);
    }
    function valueBounds() {
        if (!root.markers?.length) {
            return [root.min, root.max];
        }
        const bounds = [...root.markers];
        if (root.max > bounds[bounds.length - 1]) {
            bounds.push(root.max);
        }
        return bounds;
    }
    function valueFromText(text, locale) {
        return Math.round(Number.fromLocaleString(locale, text) * decimalFactor) / decimalFactor;
    }
    function valueToRatio(value) {
        const bounds = valueBounds();
        const intervalCount = bounds.length - 1;
        if (intervalCount <= 0) {
            return 0;
        }
        const clampedValue = Math.max(bounds[0], Math.min(bounds[intervalCount], value));
        let interval = 0;
        while (interval < intervalCount - 1 && clampedValue > bounds[interval + 1]) {
            ++interval;
        }
        const delta = bounds[interval + 1] - bounds[interval];
        if (delta === 0) {
            return interval / intervalCount;
        }
        return (interval + (clampedValue - bounds[interval]) / delta) / intervalCount;
    }

    height: control.orientation == Qt.Horizontal ? 30 : 100
    width: control.orientation == Qt.Horizontal ? 100 : 30

    Component.onCompleted: {
        setValue(root.value);
    }

    MouseArea {
        anchors.fill: root

        onWheel: mouse => {
            if (mouse.angleDelta.y < 0) {
                setValue(Math.max(root.min, root.value - root.wheelStep));
            } else if (mouse.angleDelta.y > 0) {
                setValue(Math.min(root.max, root.value + root.wheelStep));
            }
        }
    }
    Slider {
        id: control

        anchors.bottom: orientation == Qt.Vertical ? (root.showTextInput ? textInputSection.top : root.bottom) : undefined
        anchors.horizontalCenter: orientation == Qt.Horizontal ? undefined : root.horizontalCenter
        anchors.left: orientation == Qt.Horizontal ? root.left : undefined
        anchors.right: orientation == Qt.Horizontal ? (root.showTextInput ? textInputSection.left : root.right) : undefined
        anchors.top: orientation == Qt.Horizontal ? undefined : root.top
        anchors.verticalCenter: orientation == Qt.Horizontal ? root.verticalCenter : undefined
        bottomInset: orientation == Qt.Vertical ? 0 : undefined
        bottomPadding: orientation == Qt.Vertical ? root.margins : undefined
        from: 0
        leftInset: orientation == Qt.Horizontal ? 0 : undefined
        leftPadding: orientation == Qt.Horizontal ? 0 : undefined
        rightInset: orientation == Qt.Horizontal ? 0 : undefined
        rightPadding: orientation == Qt.Horizontal ? root.margins : undefined
        to: 1
        topInset: orientation == Qt.Vertical ? 0 : undefined
        topPadding: orientation == Qt.Vertical ? 0 : undefined

        background: Rectangle {
            anchors.centerIn: control
            color: 'green'
            height: control.availableHeight
            width: control.availableWidth

            Rectangle {
                anchors.horizontalCenter: control.orientation == Qt.Horizontal ? undefined : parent.horizontalCenter
                anchors.verticalCenter: control.orientation == Qt.Horizontal ? parent.verticalCenter : undefined
                color: "#181818"
                height: control.orientation == Qt.Horizontal ? 4 : parent.height
                radius: 2
                width: control.orientation == Qt.Horizontal ? parent.width : 4
            }
            Repeater {
                id: delegate

                anchors.fill: parent
                anchors.leftMargin: 7
                anchors.topMargin: 7
                model: valueBounds().length

                Item {
                    required property int index
                    readonly property var modelData: !markers?.length ? "" : index < markers.length ? `${markers[index]}${textInputSection.suffix}` : null

                    anchors.horizontalCenter: control.orientation == Qt.Horizontal ? undefined : parent.horizontalCenter
                    anchors.verticalCenter: control.orientation == Qt.Horizontal ? parent.verticalCenter : undefined
                    x: control.orientation == Qt.Horizontal ? parent.width * (index / (delegate.count - 1)) : -4
                    y: control.orientation == Qt.Vertical ? parent.height * ((delegate.count - index - 1) / (delegate.count - 1)) - height / 2 : -4

                    Rectangle {
                        id: mark

                        color: Qt.alpha(Theme.white, 0.25)
                        height: control.orientation == Qt.Horizontal ? 11 : 1
                        visible: modelData != null
                        width: control.orientation == Qt.Horizontal ? 1 : 11

                        anchors {
                            horizontalCenter: control.orientation == Qt.Horizontal ? undefined : parent.horizontalCenter
                            verticalCenter: control.orientation == Qt.Horizontal ? parent.verticalCenter : undefined
                        }
                    }
                    Text {
                        id: label

                        color: Qt.alpha(Theme.white, 0.25)
                        font.pixelSize: 9
                        text: modelData ?? ""
                        visible: modelData != null

                        anchors {
                            horizontalCenter: control.orientation == Qt.Horizontal ? mark.left : undefined
                            left: control.orientation == Qt.Horizontal ? undefined : mark.right
                            leftMargin: 4
                            top: control.orientation == Qt.Horizontal ? mark.bottom : undefined
                            topMargin: 4
                            verticalCenter: control.orientation == Qt.Horizontal ? undefined : mark.verticalCenter
                        }
                    }
                }
            }
        }
        handle: Item {
            anchors.horizontalCenter: control.orientation == Qt.Horizontal ? undefined : control.horizontalCenter
            anchors.verticalCenter: control.orientation == Qt.Horizontal ? control.verticalCenter : undefined
            height: 14
            objectName: "handler"
            width: 14
            x: control.orientation == Qt.Horizontal ? control.leftPadding + control.visualPosition * (control.availableWidth) - width / 2 : 0
            y: control.orientation == Qt.Horizontal ? 0 : control.topPadding + control.visualPosition * (control.availableHeight) - height / 2

            Rectangle {
                id: handle

                anchors.fill: parent
                color: root.enabled ? Theme.accentColor : Theme.lightGray
                radius: 7

                border {
                    color: "#0E2A54"
                    width: 1
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: 7

                gradient: Gradient {
                    GradientStop {
                        color: Qt.rgba(0, 0, 0, 0.25)
                        position: 0.0
                    }
                    GradientStop {
                        color: "transparent"
                        position: 0.4
                    }
                }
            }
            MultiEffect {
                anchors.fill: parent
                shadowBlur: 0.1
                shadowColor: Qt.alpha(Theme.darkGray, 0.25)
                shadowEnabled: true
                source: handle
            }
        }

        onValueChanged: {
            root.setValue(ratioToValue(control.value));
        }
    }
    FocusScope {
        id: textInputSection

        property string suffix: ""

        anchors.bottom: control.orientation == Qt.Horizontal ? undefined : root.bottom
        anchors.horizontalCenter: control.orientation == Qt.Horizontal ? undefined : root.horizontalCenter
        anchors.leftMargin: 17
        anchors.margins: 4
        anchors.right: control.orientation == Qt.Horizontal ? root.right : undefined
        anchors.topMargin: 17
        height: 30
        visible: root.showTextInput
        width: fontMetrics.advanceWidth + 8

        Rectangle {
            id: backgroundInput

            anchors.fill: parent
            anchors.margins: 4
            color: Theme.darkGray2
            radius: 4

            border {
                color: "#353535"
                width: 1
            }
        }
        MultiEffect {
            anchors.fill: backgroundInput
            shadowBlur: 0.15
            shadowColor: Theme.darkGray
            shadowEnabled: true
            source: backgroundInput
        }
        Item {
            anchors.fill: parent
            anchors.margins: 4

            TextInput {
                id: valueInput

                anchors.left: parent.left
                anchors.margins: 3
                anchors.right: inputField.left
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(acceptableInput ? Theme.white : Theme.warningColor, root.enabled ? 1 : 0.5)
                focus: true
                horizontalAlignment: TextInput.AlignRight
                text: textFromValue(root.value, control.locale)

                validator: DoubleValidator {
                    bottom: Math.min(root.min, root.max)
                    decimals: root.decimals
                    notation: DoubleValidator.StandardNotation
                    top: Math.max(root.min, root.max)
                }

                onAccepted: {
                    root.setValue(valueFromText(text, control.locale));
                }
            }
            Text {
                id: inputField

                anchors.margins: textInputSection.suffix.length > 0 ? 10 : 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(Theme.white, root.enabled ? 1 : 0.5)
                text: textInputSection.suffix

                TextMetrics {
                    id: fontMetrics

                    font.family: inputField.font.family
                    text: `${control.to} ${parent.text}`
                }
            }
        }
    }
}
