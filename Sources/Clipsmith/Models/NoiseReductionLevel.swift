import Foundation

enum NoiseReductionLevel: String, Codable, CaseIterable, Identifiable {
    case light, medium, strong

    var id: String { rawValue }

    var oversubtraction: Float {
        switch self {
        case .light: return 1.3
        case .medium: return 2.2
        case .strong: return 3.2
        }
    }

    var floorGain: Float {
        switch self {
        case .light: return 0.32
        case .medium: return 0.16
        case .strong: return 0.08
        }
    }
}
