import Foundation

struct ShortcutModifiers: OptionSet {
    let rawValue: Int

    static let shift = ShortcutModifiers(rawValue: 1 << 0)
    static let option = ShortcutModifiers(rawValue: 1 << 1)
    static let command = ShortcutModifiers(rawValue: 1 << 2)
}
