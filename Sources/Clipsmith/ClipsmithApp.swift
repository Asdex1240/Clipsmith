import SwiftUI

@main
struct ClipsmithApp: App {
    @NSApplicationDelegateAdaptor(DockActivatingAppDelegate.self) private var appDelegate
    @State private var store = ProjectStore(project: Project(name: localized("project.untitled")))
    @State private var library = MediaLibrary()
    @State private var player = PlayerController()
    private let thumbnails = CachedThumbnailGenerator()

    var body: some Scene {
        WindowGroup("Clipsmith") {
            ContentView(store: store, library: library, player: player, thumbnails: thumbnails)
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
