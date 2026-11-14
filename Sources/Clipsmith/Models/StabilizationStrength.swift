import Foundation

enum StabilizationStrength: String, CaseIterable, Identifiable {
    case light, normal, strong

    var id: String { rawValue }

    var smoothingWindowInSeconds: TimeInterval {
        switch self {
        case .light: return 0.6
        case .normal: return 1.2
        case .strong: return 2.5
        }
    }

    var maximumZoom: Double {
        switch self {
        case .light: return 1.06
        case .normal: return 1.1
        case .strong: return 1.15
        }
    }
}
