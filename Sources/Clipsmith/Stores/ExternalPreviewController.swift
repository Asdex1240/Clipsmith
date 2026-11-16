import AppKit
import Observation

@MainActor
@Observable
final class ExternalPreviewController {
    private static let aboveMenuBar = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)

    private(set) var activeDisplay: ExternalDisplay?
    @ObservationIgnored private let monitor: DisplayMonitor
    @ObservationIgnored private let makeContentView: () -> NSView
    @ObservationIgnored private var window: NSWindow?
    @ObservationIgnored private var screenObserver: NSObjectProtocol?

    init(monitor: DisplayMonitor, makeContentView: @escaping () -> NSView) {
        self.monitor = monitor
        self.makeContentView = makeContentView
        monitor.onDisplaysChange = { [weak self] in self?.displaysDidChange() }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeScreenNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.hideIfTheEditorCoversThePreview() }
        }
    }

    var candidates: [ExternalDisplay] {
        PreviewDisplayTargets.candidates(among: monitor.displays, editorDisplayID: editorDisplayID)
    }

    var isAvailable: Bool {
        isShowing || !candidates.isEmpty
    }

    var isShowing: Bool {
        activeDisplay != nil
    }

    func toggle() {
        if isShowing {
            hide()
            return
        }
        guard let display = candidates.first else { return }
        show(on: display)
    }

    func show(on display: ExternalDisplay) {
        guard let screen = monitor.screen(for: display) else { return }
        let window = self.window ?? makeWindow()
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
        self.window = window
        activeDisplay = display
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        activeDisplay = nil
    }

    private var editorDisplayID: UInt32? {
        let editor = NSApp.windows.first { $0 !== window && $0.isVisible && $0.canBecomeMain }
        return editor?.screen.flatMap(DisplayMonitor.displayID(of:))
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.level = Self.aboveMenuBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = makeContentView()
        return window
    }

    private func hideIfTheEditorCoversThePreview() {
        guard let activeDisplay, editorDisplayID == activeDisplay.id else { return }
        hide()
    }

    private func displaysDidChange() {
        guard let activeDisplay else { return }
        guard PreviewDisplayTargets.isConnected(activeDisplay, among: monitor.displays) else {
            hide()
            return
        }
        show(on: activeDisplay)
    }
}
