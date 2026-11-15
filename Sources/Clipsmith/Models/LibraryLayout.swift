import Foundation

enum LibraryLayout: String, CaseIterable, Identifiable {
    case grid, list

    var id: String { rawValue }
}
