import Foundation

enum TransitionKind: String, Codable, CaseIterable {
    case dissolve
    case fadeBlack
    case slideLeft
    case slideRight
}

/// How a clip comes in after the clip right before it on the same track.
struct ClipTransition: Codable, Equatable {
    static let durationRange = 0.25...3.0
    static let defaultDuration = 1.0

    var kind: TransitionKind
    var durationInSeconds: TimeInterval = ClipTransition.defaultDuration

    func settingDuration(_ seconds: TimeInterval) -> ClipTransition {
        var copy = self
        copy.durationInSeconds = min(max(seconds, Self.durationRange.lowerBound), Self.durationRange.upperBound)
        return copy
    }
}

extension TransitionKind {
    /// How far through the transition the incoming clip has to be before the outgoing one is gone.
    static let dipFraction = 0.5

    /// Opacity multipliers for the outgoing and incoming clip at `progress` (0 to 1).
    func opacity(at progress: Double) -> (outgoing: Double, incoming: Double) {
        switch self {
        case .dissolve:
            return (1 - progress, 1)
        case .fadeBlack:
            let half = Self.dipFraction
            return (max(0, 1 - progress / half), max(0, (progress - half) / (1 - half)))
        case .slideLeft, .slideRight:
            return (1, 1)
        }
    }

    /// Horizontal shift, as a fraction of the canvas width, of the outgoing and incoming clip at `progress`.
    func shift(at progress: Double) -> (outgoing: Double, incoming: Double) {
        switch self {
        case .slideLeft: return (-progress, 1 - progress)
        case .slideRight: return (progress, progress - 1)
        case .dissolve, .fadeBlack: return (0, 0)
        }
    }

    /// Progress values where the look changes direction, which a straight ramp cannot follow.
    var breakpoints: [Double] {
        self == .fadeBlack ? [Self.dipFraction] : []
    }
}
