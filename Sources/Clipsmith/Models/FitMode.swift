import Foundation

enum FitMode: String, Codable, CaseIterable, Identifiable {
    case fit
    case fill
    case blur

    var id: String { rawValue }
}
