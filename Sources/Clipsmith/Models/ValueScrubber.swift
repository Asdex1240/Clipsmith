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

enum ValueScrubber {
    static let pointsForFullRange = 300.0

    static func value(
        startingAt start: Double, dragging translation: Double, in range: ClosedRange<Double>,
        speed: ScrubSpeed = .normal
    ) -> Double {
        let span = range.upperBound - range.lowerBound
        let change = translation / pointsForFullRange * span * speed.multiplier
        return min(max(start + change, range.lowerBound), range.upperBound)
    }
}
