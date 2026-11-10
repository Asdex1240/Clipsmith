import Foundation

enum EditorAction: CaseIterable {
    case togglePlayback
    case split
    case addText
    case delete
    case rippleDelete
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
        case .zoomIn, .zoomOut, .stepBackward, .stepForward, .jumpBackward, .jumpForward, .previousEdit, .nextEdit:
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
}

enum EditorShortcuts {
    static func action(for key: ShortcutKey, modifiers: ShortcutModifiers) -> EditorAction? {
        switch key {
        case .space: return modifiers.isEmpty ? .togglePlayback : nil
        case .delete: return deleteAction(modifiers)
        case .leftArrow: return arrowAction(modifiers, plain: .stepBackward, shift: .jumpBackward, option: .previousEdit)
        case .rightArrow: return arrowAction(modifiers, plain: .stepForward, shift: .jumpForward, option: .nextEdit)
        case .home: return modifiers.isEmpty ? .goToStart : nil
        case .end: return modifiers.isEmpty ? .goToEnd : nil
        case .escape: return modifiers.isEmpty ? .deselect : nil
        case .character(let character): return characterAction(character, modifiers)
        }
    }

    static func displayKeys(for action: EditorAction) -> String {
        switch action {
        case .togglePlayback: return "Space"
        case .split: return "S"
        case .addText: return "T"
        case .delete: return "⌫"
        case .rippleDelete: return "⇧⌫"
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

    private static func deleteAction(_ modifiers: ShortcutModifiers) -> EditorAction? {
        if modifiers.isEmpty { return .delete }
        return modifiers == .shift ? .rippleDelete : nil
    }

    private static func arrowAction(
        _ modifiers: ShortcutModifiers,
        plain: EditorAction,
        shift: EditorAction,
        option: EditorAction
    ) -> EditorAction? {
        if modifiers.isEmpty { return plain }
        if modifiers == .shift { return shift }
        return modifiers == .option ? option : nil
    }

    private static func characterAction(_ character: Character, _ modifiers: ShortcutModifiers) -> EditorAction? {
        guard modifiers.isEmpty || modifiers == .shift else { return nil }
        switch character.lowercased() {
        case "s": return modifiers.isEmpty ? .split : nil
        case "t": return modifiers.isEmpty ? .addText : nil
        case "=", "+": return .zoomIn
        case "-", "_": return .zoomOut
        default: return nil
        }
    }
}
