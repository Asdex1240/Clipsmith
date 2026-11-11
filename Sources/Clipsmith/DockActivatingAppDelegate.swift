import SwiftUI

final class DockActivatingAppDelegate: NSObject, NSApplicationDelegate {
    var shouldAllowTermination: (() -> Bool)?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if shouldAllowTermination?() ?? true { return .terminateNow }
        return .terminateCancel
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
