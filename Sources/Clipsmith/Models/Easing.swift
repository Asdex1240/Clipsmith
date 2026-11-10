import Foundation

/// How a value moves between two points: evenly, or slowly at the start and/or the end.
enum Easing: String, Codable, CaseIterable {
    case linear
    case easeIn
    case easeOut
    case easeInOut

    var isLinear: Bool { self == .linear }

    /// Maps how far through the time (0 to 1) we are to how far through the movement (0 to 1).
    func apply(_ time: Double) -> Double {
        let t = min(max(time, 0), 1)
        switch self {
        case .linear: return t
        case .easeIn: return t * t * t
        case .easeOut: return 1 - pow(1 - t, 3)
        case .easeInOut: return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
        }
    }

    /// The time (0 to 1) at which the movement reaches `progress`.
    func time(forProgress progress: Double) -> Double {
        guard !isLinear else { return min(max(progress, 0), 1) }
        var low = 0.0
        var high = 1.0
        for _ in 0..<40 {
            let middle = (low + high) / 2
            if apply(middle) < progress { low = middle } else { high = middle }
        }
        return (low + high) / 2
    }
}
