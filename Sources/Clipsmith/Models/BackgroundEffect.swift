import Foundation

enum BackgroundEffect: String, Codable, CaseIterable, Identifiable {
    case remove
    case blur

    var id: String { rawValue }
}
