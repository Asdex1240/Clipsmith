import AppKit

final class CursorHidingView: NSView {
    private static let hideDelayInSeconds = ControlsVisibility.hideDelayInSeconds

    private var hideTask: Task<Void, Never>?

    init(content: NSView) {
        super.init(frame: .zero)
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(content)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        scheduleHidingTheCursor()
    }

    override func mouseMoved(with event: NSEvent) {
        scheduleHidingTheCursor()
    }

    override func mouseExited(with event: NSEvent) {
        hideTask?.cancel()
    }

    private func scheduleHidingTheCursor() {
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(Self.hideDelayInSeconds))
            } catch {
                return
            }
            NSCursor.setHiddenUntilMouseMoves(true)
        }
    }
}
