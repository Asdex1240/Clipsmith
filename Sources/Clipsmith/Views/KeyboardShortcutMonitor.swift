import AppKit

@MainActor
final class KeyboardShortcutMonitor {
    private let perform: (EditorAction) -> Void
    private var monitor: Any?

    init(perform: @escaping (EditorAction) -> Void) {
        self.perform = perform
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            nonisolated(unsafe) let keyEvent = event
            let wasHandled = MainActor.assumeIsolated { self?.handle(keyEvent) ?? false }
            if wasHandled { return nil }
            return event
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard canHandleShortcuts(for: event),
            let key = ShortcutKey(event: event),
            let action = EditorShortcuts.action(
                for: key, modifiers: ShortcutModifiers(event: event)),
            !event.isARepeat || action.allowsKeyRepeat
        else { return false }
        perform(action)
        return true
    }

    private func canHandleShortcuts(for event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.control).isEmpty,
            let window = NSApp.keyWindow,
            window.sheetParent == nil,
            window.attachedSheet == nil
        else { return false }
        return !(window.firstResponder is NSText)
    }
}

private extension ShortcutKey {
    init?(event: NSEvent) {
        switch event.keyCode {
        case 49: self = .space
        case 51, 117: self = .delete
        case 123: self = .leftArrow
        case 124: self = .rightArrow
        case 115: self = .home
        case 119: self = .end
        case 53: self = .escape
        default:
            guard let character = event.charactersIgnoringModifiers?.first else { return nil }
            self = .character(character)
        }
    }
}

private extension ShortcutModifiers {
    init(event: NSEvent) {
        var modifiers: ShortcutModifiers = []
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        self = modifiers
    }
}
