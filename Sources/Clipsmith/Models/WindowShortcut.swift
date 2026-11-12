import Foundation

struct WindowShortcut: Identifiable, Equatable {
    let titleKey: String
    let keys: String

    var id: String { titleKey }
}

enum WindowShortcuts {
    static let all: [WindowShortcut] = [
        WindowShortcut(titleKey: "menu.new", keys: "⌘N"),
        WindowShortcut(titleKey: "menu.open", keys: "⌘O"),
        WindowShortcut(titleKey: "menu.save", keys: "⌘S"),
        WindowShortcut(titleKey: "menu.saveAs", keys: "⇧⌘S"),
        WindowShortcut(titleKey: "menu.undo", keys: "⌘Z"),
        WindowShortcut(titleKey: "menu.redo", keys: "⇧⌘Z"),
        WindowShortcut(titleKey: "export.open", keys: "⌘E"),
        WindowShortcut(titleKey: "toolbar.sidebar", keys: "⌥⌘1"),
        WindowShortcut(titleKey: "toolbar.inspector", keys: "⌥⌘2"),
        WindowShortcut(titleKey: "menu.shortcuts", keys: "⌘/"),
    ]
}
