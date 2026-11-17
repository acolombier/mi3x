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
        Skin.StartupScreen {
            id: startupScreen

            anchors.fill: parent
            progress: {
                print("Skin.StartupScreen", Mixxx.Core.ready, parent, parent.opacity, parent.mainLoader.progress)
                // FIXME add a Q_GADGET for Mixxx.Core.initialization including progress and label
                if (!Mixxx.Core.ready) {
                    return Mixxx.Core.initializationProgress;
                } else if (parent.opacity < 1) {
                    return 100;
                } else {
                    return 65 + Math.round(parent.mainLoader.progress * 34);
                }
            }
        }
    }

    main: Component {
        Skin.MainWindow {
        }
    }
}
