import SwiftUI

@main
struct ClipsmithApp: App {
    @NSApplicationDelegateAdaptor(DockActivatingAppDelegate.self) private var appDelegate
    @State private var project = Project(name: String(localized: "project.untitled", bundle: .module))

    var body: some Scene {
        WindowGroup("Clipsmith") {
            ContentView(project: $project)
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
