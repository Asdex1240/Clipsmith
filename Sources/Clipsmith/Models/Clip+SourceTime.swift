import Foundation

extension Clip {
    func timelineTime(forSourceTime source: TimeInterval) -> TimeInterval {
        startInSeconds + (source - sourceStartInSeconds) / speed
    }

    func sourceTime(forTimelineTime timeline: TimeInterval) -> TimeInterval {
        sourceStartInSeconds + (timeline - startInSeconds) * speed
    }
}
