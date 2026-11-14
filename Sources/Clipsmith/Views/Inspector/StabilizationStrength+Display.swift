import Foundation

extension StabilizationStrength {
    var titleKey: String {
        switch self {
        case .light: return "inspector.stabilization.light"
        case .normal: return "inspector.stabilization.normal"
        case .strong: return "inspector.stabilization.strong"
        }
    }
}
