import "." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme"

Popup {
    id: root

    required property var deckMapping

    closePolicy: Popup.NoAutoClose
    height: editDeckAction.height + topPadding + bottomPadding
    width: editDeckAction.width + leftPadding + rightPadding

    background: Rectangle {
        color: Theme.deckLoopBackgroundColor
        radius: 6
    }
    contentItem: Item {
        implicitHeight: editDeckAction.height + 10
        implicitWidth: editDeckAction.width + 10

        RowLayout {
            id: editDeckAction

            anchors.centerIn: parent

            Skin.FormButton {
                id: actionButtonCancel

                activeColor: "#999999"
                backgroundColor: "#3F3F3F"
                text: "Cancel"

                onPressed: {
                    for (let idx in root.deckMapping) {
                        let deck = root.deckMapping[idx];
                        if (!deck?.visible)
                            continue;
                        let previousLayout = Mixxx.Config.getDeckLayout(idx);
                        if (!previousLayout) {
                            deck.resetLayout();
                        } else {
                            deck.normalModel.clear();
                            deck.normalModel.append(JSON.parse(previousLayout));
                        }
                    }
                    root.close();
                }
            }
            Skin.FormButton {
                id: actionButtonReset

                activeColor: "#999999"
                backgroundColor: "#3F3F3F"
                text: "Reset"
                visible: {
                    root.opened; // Implicit binding to update when opening
                    return Array(4).fill().map((_, i) => Mixxx.Config.getDeckLayout(i)).reduce((acc, config) => acc || !!config, false);
                }

                onPressed: {
                    ApplicationWindow.window.requestDeckLayoutReset();
                    root.close();
                }
            }
            Skin.FormButton {
                id: actionButtonSave

                activeColor: "#999999"
                backgroundColor: enabled ? "#3a60be" : "#3F3F3F"
                text: "Save"

                onPressed: {
                    for (let idx in root.deckMapping) {
                        let deck = root.deckMapping[idx];
                        if (!deck?.visible)
                            continue;

                        Mixxx.Config.setDeckLayout(idx, JSON.stringify(deck.serializeModel(deck.normalModel)));
                        root.close();
                    }
                }
            }
        }
    }
}
