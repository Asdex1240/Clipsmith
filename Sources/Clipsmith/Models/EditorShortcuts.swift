import Foundation

enum EditorAction: CaseIterable {
    case togglePlayback
    case split
    case addText
    case addMarker
    case toggleSnapping
    case delete
    case rippleDelete
    case trimStartToPlayhead
    case trimEndToPlayhead
    case copy
    case cut
    case paste
    case duplicate
    case selectAll
    case group
    case ungroup
    case zoomIn
    case zoomOut
    case stepBackward
    case stepForward
    case jumpBackward
    case jumpForward
    case previousEdit
    case nextEdit
    case goToStart
    case goToEnd
    case deselect

    var allowsKeyRepeat: Bool {
        switch self {
        case .zoomIn, .zoomOut, .stepBackward, .stepForward, .jumpBackward, .jumpForward,
            .previousEdit, .nextEdit:
            return true
        default:
            return false
        }
    }
}

enum ShortcutKey: Equatable {
    case character(Character)
    case space
    case delete
    case leftArrow
    case rightArrow
    case home
    case end
    case escape
}

struct ShortcutModifiers: OptionSet {
    let rawValue: Int

    static let shift = ShortcutModifiers(rawValue: 1 << 0)
    static let option = ShortcutModifiers(rawValue: 1 << 1)
    static let command = ShortcutModifiers(rawValue: 1 << 2)
}

enum EditorShortcuts {
    static func action(for key: ShortcutKey, modifiers: ShortcutModifiers) -> EditorAction? {
        switch key {
        case .space: return whenUnmodified(.togglePlayback, modifiers)
        case .delete: return deleteAction(modifiers)
        case .leftArrow:
            return arrowAction(
                modifiers, plain: .stepBackward, shift: .jumpBackward, option: .previousEdit)
        case .rightArrow:
            return arrowAction(
                modifiers, plain: .stepForward, shift: .jumpForward, option: .nextEdit)
        case .home: return whenUnmodified(.goToStart, modifiers)
        case .end: return whenUnmodified(.goToEnd, modifiers)
        case .escape: return whenUnmodified(.deselect, modifiers)
        case .character(let character): return characterAction(character, modifiers)
        }
    }

    static func displayKeys(for action: EditorAction) -> String {
        switch action {
        case .togglePlayback: return "Space"
        case .split: return "S"
        case .addText: return "T"
        case .addMarker: return "M"
        case .toggleSnapping: return "N"
        case .delete: return "⌫"
        case .rippleDelete: return "⇧⌫"
        case .trimStartToPlayhead: return "Q"
        case .trimEndToPlayhead: return "W"
        case .copy: return "⌘C"
        case .cut: return "⌘X"
        case .paste: return "⌘V"
        case .duplicate: return "⌘D"
        case .selectAll: return "⌘A"
        case .group: return "⌘G"
        case .ungroup: return "⇧⌘G"
        case .zoomIn: return "+"
        case .zoomOut: return "−"
        case .stepBackward: return "←"
        case .stepForward: return "→"
        case .jumpBackward: return "⇧←"
        case .jumpForward: return "⇧→"
        case .previousEdit: return "⌥←"
        case .nextEdit: return "⌥→"
        case .goToStart: return "Home"
        case .goToEnd: return "End"
        case .deselect: return "Esc"
        }
    }

    private static func whenUnmodified(
        _ action: EditorAction, _ modifiers: ShortcutModifiers
    ) -> EditorAction? {
        guard modifiers.isEmpty else { return nil }
        return action
    }

    private static func deleteAction(_ modifiers: ShortcutModifiers) -> EditorAction? {
        if modifiers.isEmpty { return .delete }
        guard modifiers == .shift else { return nil }
        return .rippleDelete
    }

    private static func arrowAction(
        _ modifiers: ShortcutModifiers,
        plain: EditorAction,
        shift: EditorAction,
        option: EditorAction
    ) -> EditorAction? {
        if modifiers.isEmpty { return plain }
        if modifiers == .shift { return shift }
        guard modifiers == .option else { return nil }
        return option
    }

    private static func characterAction(
        _ character: Character, _ modifiers: ShortcutModifiers
    ) -> EditorAction? {
        if modifiers == .command { return commandAction(character) }
        if modifiers == [.command, .shift] {
            guard character.lowercased() == "g" else { return nil }
            return .ungroup
        }
        guard modifiers.isEmpty || modifiers == .shift else { return nil }
        return plainAction(character, modifiers)
    }

    private static func commandAction(_ character: Character) -> EditorAction? {
        switch character.lowercased() {
        case "c": return .copy
        case "x": return .cut
        case "v": return .paste
        case "d": return .duplicate
        case "a": return .selectAll
        case "g": return .group
        default: return nil
        }
    }

    private static func plainAction(
        _ character: Character, _ modifiers: ShortcutModifiers
    ) -> EditorAction? {
        switch character.lowercased() {
        case "q": return whenUnmodified(.trimStartToPlayhead, modifiers)
        case "w": return whenUnmodified(.trimEndToPlayhead, modifiers)
        case "s": return whenUnmodified(.split, modifiers)
        case "t": return whenUnmodified(.addText, modifiers)
        case "m": return whenUnmodified(.addMarker, modifiers)
        case "n": return whenUnmodified(.toggleSnapping, modifiers)
        case "=", "+": return .zoomIn
        case "-", "_": return .zoomOut
        default: return nil
        }
    }
}
