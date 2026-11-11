import Foundation

enum TimelineScale {
    private static let tickIntervals: [TimeInterval] = [
        0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600,
    ]
    private static let minimumTickSpacingInPoints = 70.0

    static func tickInterval(pointsPerSecond: Double) -> TimeInterval {
        tickIntervals.first { $0 * pointsPerSecond >= minimumTickSpacingInPoints }
            ?? tickIntervals[tickIntervals.count - 1]
    }
}
