import Foundation

enum Snapping {
    static func snap(
        _ value: TimeInterval,
        to candidates: [TimeInterval],
        within threshold: TimeInterval
    ) -> TimeInterval {
        value + (shift(of: value, to: candidates, within: threshold) ?? 0)
    }

    static func snapStart(
        _ start: TimeInterval,
        duration: TimeInterval,
        to candidates: [TimeInterval],
        within threshold: TimeInterval
    ) -> TimeInterval {
        let startShift = shift(of: start, to: candidates, within: threshold)
        let endShift = shift(of: start + duration, to: candidates, within: threshold)
        let shifts = [startShift, endShift].compactMap { $0 }
        let closest = shifts.min { abs($0) < abs($1) } ?? 0
        return start + closest
    }

    private static func shift(
        of value: TimeInterval,
        to candidates: [TimeInterval],
        within threshold: TimeInterval
    ) -> TimeInterval? {
        guard let nearest = candidates.min(by: { abs($0 - value) < abs($1 - value) }),
            abs(nearest - value) <= threshold
        else { return nil }
        return nearest - value
    }
}
