import Foundation

struct ClipDucking: Codable, Equatable {
    static let levelRange = 0.05...0.8
    static let defaultLevel = 0.25
    static let attackInSeconds: TimeInterval = 0.15
    static let releaseInSeconds: TimeInterval = 0.4

    struct Range: Codable, Equatable {
        var start: TimeInterval
        var end: TimeInterval
    }

    var level = ClipDucking.defaultLevel
    var ranges: [Range] = []
}

extension Clip {
    func settingDucking(_ ducking: ClipDucking?) -> Clip {
        var clip = self
        clip.ducking = ducking
        return clip
    }

    func settingDuckLevel(_ level: Double) -> Clip {
        guard var ducking else { return self }
        ducking.level = min(
            max(level, ClipDucking.levelRange.lowerBound), ClipDucking.levelRange.upperBound)
        return settingDucking(ducking)
    }

    func duckingRangesOnTimeline() -> [Swift.Range<TimeInterval>] {
        guard let ducking else { return [] }
        return ducking.ranges.compactMap { range in
            let start = timelineTime(forSourceTime: range.start)
            let end = timelineTime(forSourceTime: range.end)
            guard end > start else { return nil }
            return start..<end
        }
    }

    func sourceRanges(from timeline: [Swift.Range<TimeInterval>]) -> [ClipDucking.Range] {
        timeline.compactMap { range in
            let start = max(sourceStartInSeconds, sourceTime(forTimelineTime: range.lowerBound))
            let end = min(sourceEndInSeconds, sourceTime(forTimelineTime: range.upperBound))
            guard end > start else { return nil }
            return ClipDucking.Range(start: start, end: end)
        }
    }
}
