import QtQuick
import QtQuick.Controls
import QtQuick.Window

// A Menu whose content item is addressable by spix for E2E testing: the
// content ListView is named "<menuName>" ("_Sub<depth>" for nested menus)
// while open, and exposes serialisedDump()/setMenuIndex() so step
// definitions can inspect and keyboard-navigate the menu (see
// src/test/behave/steps/). Menus render in the window Overlay, so spix
// addresses them from the window root ("mainWindow/<menuName>").
Menu {
    id: control

    readonly property int depth: {
        // May be null when the tree is getting tore down
        return parent instanceof MenuItem ? parent?.menu?.depth + 1 : 0;
    }

    // Spix objectName of the root menu's content item. Nested menus derive
    // their name from the root menu of their tree, so only the root needs
    // this set to a distinct value.
    property string menuName: "menu"
    readonly property Menu rootMenu: {
        let menu = control;
        while (menu.depth > 0) {
            menu = menu?.parent?.menu;
        }
        return menu;
    }

    function dumpTree(recursive) {
        let d = {
            count: this.contentItem.count,
            currentIndex: this.contentItem.currentIndex,
            items: Array(this.contentItem.count).fill().map((_, i) => {
                let item = this.contentItem.itemAtIndex(i);
                let m = recursive ? menuAt(i) : null;
                return Object.assign({
                    objectName: item?.objectName,
                    text: item?.text
                }, m ? {
                    menu: m.dumpTree()
                } : {});
            })
        };
        return d;
    }

    contentItem: ListView {
        function serialisedDump() {
            return JSON.stringify(control.dumpTree(false));
        }
        function setMenuIndex(i) {
            control.currentIndex = i;
        }

        clip: true
        currentIndex: control.currentIndex
        implicitHeight: contentHeight
        interactive: Window.window ? contentHeight + control.topPadding + control.bottomPadding > control.height : false
        model: control.contentModel
        objectName: (activeFocus || !depth) && opened ? !depth ? control.menuName : `${control.rootMenu.menuName}_Sub${depth}` : null

        ScrollIndicator.vertical: ScrollIndicator {
        }
    }

    onOpenedChanged: {
        for (let i = 0; i < contentItem.count; i++) {
            if (!contentItem?.itemAtIndex(i))
                continue;
            contentItem.itemAtIndex(i).objectName = "menuItem" + i;
        }
    }
}
