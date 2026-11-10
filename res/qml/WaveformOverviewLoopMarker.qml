import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import "Theme"

Item {
    id: root

    required property string group

    visible: loopIn.value > 0 && loopIn.value < loopOut.value

    Mixxx.ControlProxy {
        id: trackSamplesControl

        group: root.group
        key: "track_samples"
    }
    Mixxx.ControlProxy {
        id: loopEnabled

        group: root.group
        key: "loop_enabled"
    }
    Mixxx.ControlProxy {
        id: loopIn

        group: root.group
        key: "loop_start_position"
    }
    Mixxx.ControlProxy {
        id: loopOut

        group: root.group
        key: "loop_end_position"
    }
    Rectangle {
        color: Qt.alpha('green', loopEnabled.value ? 0.6 : 0.2)
        height: parent.height
        width: {
            const totalSamples = trackSamplesControl.value;
            return ((totalSamples > 0) ? root.width * (loopOut.value / totalSamples) : 0) - x;
        }
        x: {
            const totalSamples = trackSamplesControl.value;
            return (totalSamples > 0) ? root.width * (loopIn.value / totalSamples) : 0;
        }
    }
}
