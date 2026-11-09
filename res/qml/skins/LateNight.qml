import "../../skins/LateNightQML/" as Skin
import Mixxx 1.0 as Mixxx
import QtQuick

Mixxx.Skin {
    // Here are some example of what to expect
    name: "LateNight"
    version: "1.0"
    description: "The historic Mixxx theme"
    // This would replace the naive QML singleton, such that it can still be declared purely in QML, but the backend handles which palette is live
    colorPalettes: [
        // MidnightDark.Palettes.Default,
        // MidnightDark.Palettes.Bright,
        // MidnightDark.Palettes.HighContrast,
    ]
    // The following could be used to help filtering available themes (e.g a small smartphone screen would skip incompatible skins) and help with initial/reset geometry
    defaultHeight: 1008
    defaultWidth: 1792
    minimumWidth: 680
    minimumHeight: 300
    loader: Component {
        Rectangle {
            Text {
                text: "Loading..."
            }
        }
    }

    main: Component {
        Skin.MainWindow {
        }
    }
}
