import Mixxx 1.0 as Mixxx

Mixxx.ControlProxy {
    enum WidgetKind {
        None,
        Searchbar,
        Sidebar,
        LibraryView,
        ContextMenu
    }

    group: "[Library]"
    key: "focused_widget"
}
