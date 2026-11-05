# Skin System — Design Notes

> *Work in progress draft!*

## Concept

A skin is a **pure QML data package**. The core shell (`res/qml/main.qml`) is fixed software — splash, settings popup, dev tools, touch hub — and never changes per skin. Skins are discovered, validated, and switched at runtime; the application logo/theme/layout all live inside the skin package.

## Why

- Pure manifest approach
- Strongly typed and validated "for free"
- All fancy OOP from QML, allowing inheritance from "base" theme for example
- Reactive - allowing dynamic logic (e.g different loader showing near XMas) at the skin level

## Anatomy of a skin

```text
res/qml/skins/
├── MidnightDark.qml          # manifest (entry point)
└── MidnightDark/             # Skin folder - name irrelevant
    ├── Main.qml              # skin root UI example, entrypoint leaves in the manifest as a QmlComponent
    ├── Theme/                # skin-local palette singleton (qmldir-registered)
    ├── <components>          # Button, Deck, Library, ... — all skin-scoped
    └── images/
```

**Manifest** (`skins/<Name>.qml`) — a plain QML file whose root object is `Mixxx.Skin`:

```qml
import "MidnightDark" as Skin
import Mixxx 1.0 as Mixxx

Mixxx.Skin {
    main: Component { Skin.Main { } }    // the skin's root UI
    // loader: Component { ... }         // loading placeholder shown while the main component loads

    // Planned metadata (pure QML, no sidecar formats):
    // name, description, colorPalettes[], version
    // defaultWidth/defaultHeight, minimumWidth/minimumHeight
    //   — used for skin filtering (e.g. small-screen devices) and reset geometry
}
```

### API Snapshot

The current WIP manifest already sketches a suggested `Mixxx.Skin` API in comments:

```qml
import "MidnightDark" as Skin
import Mixxx 1.0 as Mixxx
import QtQuick

Mixxx.Skin {
    /* Here are some example of what to expect
    name: "Midnight Dark"
    version: "1.0"
    description: "A new way of using Mixxx"
    // This would replace the naive QML singleton, such that it can still be declared purely in QML, but the backend handles which palette is live
    colorPalettes: [
        MidnightDark.Palettes.Default,
        MidnightDark.Palettes.Bright,
        MidnightDark.Palettes.HighContrast,
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
    */

    main: Component {
        Skin.Main {
        }
    }
}
```

## Loading pipeline

1. **Discovery**: `QmlCoreServices` scans `qml/skins/` (resource path, could also add user folder) and extract each a skin manifest asynchronous. It can live reload new themes, and the design is fully compatible with the AutoReloader (both manifest and skin components)
2. **Validation**: on component ready, the C++ layer checks the root object **is** a `Mixxx.Skin`; non-conforming files are rejected with warnings.
3. **Registry**: validated skins are stored in a registry; the active one is exposed as `Mixxx.Core.selectedSkin` (notifies `selectedSkinChanged`). Setting will later allow changing live the active skin.
4. **Shell binding**: the stateless shell hosts a single `Loader`:
   `sourceComponent: Mixxx.Core.selectedSkin?.main`, active once `Mixxx.Core.ready`, loaded async with a splash/`loader` placeholder, then flipped to synchronous so layout work causes no visual artifacts.

## Design rules

- **Shell ↔ skin contract**: skins talk to core only through `Mixxx.*` singletons (`Core`, `Config`, `ControlProxy`, …) and the `Mixxx.Skin` type. The shell imports the skin only to host `main`.
- **Theming is skin-local**: each skin ships its own `Theme` singleton + assets, registered via a local `qmldir` and reached by relative import. We could later introduce global palette to allow customizing the setting appearance
- **Everything visual is skin data**: components under the skin folder are skin-scoped (`import … as Skin`); there is no shared UI fallback outside skins. However, skin can reference other component to extend or alias (e.g other theme they are forking from, or reusing base component used in setting view)
