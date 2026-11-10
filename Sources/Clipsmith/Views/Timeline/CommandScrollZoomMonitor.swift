import SwiftUI
import AppKit

/// Calls `onZoom` with the scroll delta while command is held and the pointer is over this view.
struct CommandScrollZoomMonitor: NSViewRepresentable {
    let onZoom: (Double) -> Void

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.onZoom = onZoom
        return view
    }

    func updateNSView(_ view: MonitorView, context: Context) {
        view.onZoom = onZoom
    }

    static func dismantleNSView(_ view: MonitorView, coordinator: ()) {
        view.stop()
    }

    @MainActor
    final class MonitorView: NSView {
        var onZoom: (Double) -> Void = { _ in }
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                nonisolated(unsafe) let scrollEvent = event
                let handled = MainActor.assumeIsolated { self?.handle(scrollEvent) ?? false }
                return handled ? nil : event
            }
        }

        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        private func handle(_ event: NSEvent) -> Bool {
            guard event.modifierFlags.contains(.command),
                  event.window === window,
                  bounds.contains(convert(event.locationInWindow, from: nil)) else { return false }
            let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.scrollingDeltaX
            guard delta != 0 else { return true }
            onZoom(Double(delta))
            return true
        }
    }
}
