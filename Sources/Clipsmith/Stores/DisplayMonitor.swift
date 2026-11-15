import AppKit
import Observation

@MainActor
@Observable
final class DisplayMonitor {
    private static let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")

    private(set) var displays: [ExternalDisplay] = []
    @ObservationIgnored var onDisplaysChange: (() -> Void)?
    @ObservationIgnored private var observer: NSObjectProtocol?

    init() {
        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensDidChange() }
        }
    }

    func screen(for display: ExternalDisplay) -> NSScreen? {
        NSScreen.screens.first { Self.displayID(of: $0) == display.id }
    }

    static func displayID(of screen: NSScreen) -> UInt32? {
        (screen.deviceDescription[screenNumberKey] as? NSNumber)?.uint32Value
    }

    private func screensDidChange() {
        refresh()
        onDisplaysChange?()
    }

    private func refresh() {
        displays = NSScreen.screens.compactMap { screen in
            guard let id = Self.displayID(of: screen) else { return nil }
            return ExternalDisplay(id: id, name: screen.localizedName)
        }
    }
}
