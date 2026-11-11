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
        ducking.level = min(max(level, ClipDucking.levelRange.lowerBound), ClipDucking.levelRange.upperBound)
        return settingDucking(ducking)
    }

    func duckingRangesOnTimeline() -> [Swift.Range<TimeInterval>] {
        guard let ducking else { return [] }
        return ducking.ranges.compactMap { range in
            let start = startInSeconds + (range.start - sourceStartInSeconds) / speed
            let end = startInSeconds + (range.end - sourceStartInSeconds) / speed
            return end > start ? start..<end : nil
        }
    }

    func sourceRanges(from timeline: [Swift.Range<TimeInterval>]) -> [ClipDucking.Range] {
        timeline.compactMap { range in
            let start = max(sourceStartInSeconds, sourceStartInSeconds + (range.lowerBound - startInSeconds) * speed)
            let end = min(sourceEndInSeconds, sourceStartInSeconds + (range.upperBound - startInSeconds) * speed)
            return end > start ? ClipDucking.Range(start: start, end: end) : nil
        }
    }
}

enum DuckingPlanner {
    static func timelineRanges(
        voices: [(clip: Clip, peaks: [Float])]
    ) -> [Range<TimeInterval>] {
        let all = voices.flatMap { voice -> [Range<TimeInterval>] in
            let source = SpeechActivity.ranges(
                peaks: voice.peaks, from: voice.clip.sourceStartInSeconds,
                to: voice.clip.sourceEndInSeconds)
            return SilenceDetector.timelineRanges(source, for: voice.clip)
        }
        return SpeechActivity.merged(all, gap: SpeechActivity.mergeGapInSeconds)
    }
}
