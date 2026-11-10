import ".." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import Mixxx.Controls 1.0 as MixxxControls

Skin.EmbeddedText {
    id: root

    property alias control: control

    text: control.value

    MixxxControls.TrackTime {
        id: control

        mode: Mixxx.Config.controlTimeFormat
    }
}
