import SwiftUI

@main
struct ClipsmithApp: App {
    @NSApplicationDelegateAdaptor(DockActivatingAppDelegate.self) private var appDelegate
    @State private var store: ProjectStore
    @State private var library = MediaLibrary()
    @State private var player: PlayerController
    @State private var previewer: TimelinePreviewer
    private let thumbnails = CachedThumbnailGenerator()

    init() {
        let store = ProjectStore(project: Project(name: localized("project.untitled")))
        let player = PlayerController()
        _store = State(initialValue: store)
        _player = State(initialValue: player)
        _previewer = State(initialValue: TimelinePreviewer(store: store, player: player))
    }

    var body: some Scene {
        WindowGroup("Clipsmith") {
            ContentView(store: store, library: library, player: player, previewer: previewer, thumbnails: thumbnails)
                .frame(minWidth: 1100, minHeight: 700)
        }
    }
}

final class DockActivatingAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
