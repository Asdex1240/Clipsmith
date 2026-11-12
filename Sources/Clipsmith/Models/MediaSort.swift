import Foundation

enum MediaSort: String, CaseIterable, Identifiable {
    case added, name, duration

    var id: String { rawValue }
}
