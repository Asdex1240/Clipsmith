import Foundation

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
