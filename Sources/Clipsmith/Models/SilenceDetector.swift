import Foundation

enum SilenceDetector {
    static let defaultThreshold: Float = 0.02
    static let defaultMinimumDurationInSeconds: TimeInterval = 0.6
    static let paddingInSeconds: TimeInterval = 0.1

    static func silences(
        peaks: [Float], from start: TimeInterval, to end: TimeInterval,
        threshold: Float = defaultThreshold,
        minimumDuration: TimeInterval = defaultMinimumDurationInSeconds,
        padding: TimeInterval = paddingInSeconds,
        peaksPerSecond: Double = WaveformSpec.peaksPerSecond
    ) -> [Range<TimeInterval>] {
        let first = max(0, Int(start * peaksPerSecond))
        let last = min(Int(end * peaksPerSecond), peaks.count)
        guard first < last else { return [] }
        var result: [Range<TimeInterval>] = []
        var runStart: Int?
        for index in first...last {
            let isQuiet = index < last && peaks[index] < threshold
            if isQuiet {
                if runStart == nil { runStart = index }
                continue
            }
            guard let begin = runStart else { continue }
            runStart = nil
            let from = Double(begin) / peaksPerSecond
            let to = Double(index) / peaksPerSecond
            guard to - from >= minimumDuration else { continue }
            let cutStart = from + (begin == first ? 0 : padding)
            let cutEnd = to - (index == last ? 0 : padding)
            if cutEnd - cutStart >= Clip.minimumDurationInSeconds {
                result.append(cutStart..<cutEnd)
            }
        }
        return result
    }

    static func timelineRanges(
        _ ranges: [Range<TimeInterval>], for clip: Clip
    ) -> [Range<TimeInterval>] {
        ranges.compactMap { range in
            let start = clip.startInSeconds + (range.lowerBound - clip.sourceStartInSeconds) / clip.speed
            let end = clip.startInSeconds + (range.upperBound - clip.sourceStartInSeconds) / clip.speed
            let lower = max(start, clip.startInSeconds)
            let upper = min(end, clip.endInSeconds)
            return upper - lower >= Clip.minimumDurationInSeconds ? lower..<upper : nil
        }
    }
}
