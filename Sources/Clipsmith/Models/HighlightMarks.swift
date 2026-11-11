import Foundation

struct HighlightMarks: Equatable {
    private(set) var start: TimeInterval?
    private(set) var end: TimeInterval?

    var isEmpty: Bool { start == nil && end == nil }

    var range: ClosedRange<TimeInterval>? {
        guard let start, let end else { return nil }
        let lower = min(start, end)
        let upper = max(start, end)
        guard upper - lower >= Highlight.minimumDurationInSeconds else { return nil }
        return lower...upper
    }

    mutating func markStart(at time: TimeInterval) {
        start = max(0, time)
    }

    mutating func markEnd(at time: TimeInterval) {
        end = max(0, time)
    }

    mutating func clear() {
        start = nil
        end = nil
    }
}
