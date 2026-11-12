import Foundation

struct WindowShortcut: Identifiable, Equatable {
    let titleKey: String
    let keys: String

    var id: String { titleKey }
}
