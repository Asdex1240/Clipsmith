import Foundation

enum ScrubSpeed {
    case normal
    case fine

    var multiplier: Double {
        switch self {
        case .normal: return 1
        case .fine: return 0.1
        }
    }
}
