import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Shapes 1.12
import QtQuick.Window 2.12

Item {
    id: root

    property string color: "white"
    property alias control: control
    required property string group
    required property string key

    Mixxx.ControlProxy {
        id: control

        group: root.group
        key: root.key
    }
}
