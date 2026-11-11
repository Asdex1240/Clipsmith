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
        return quietRuns(peaks: peaks, first: first, last: last, threshold: threshold)
            .compactMap { run in
                let from = Double(run.lowerBound) / peaksPerSecond
                let to = Double(run.upperBound) / peaksPerSecond
                guard to - from >= minimumDuration else { return nil }
                var cutStart = from
                if run.lowerBound != first { cutStart += padding }
                var cutEnd = to
                if run.upperBound != last { cutEnd -= padding }
                guard cutEnd - cutStart >= Clip.minimumDurationInSeconds else { return nil }
                return cutStart..<cutEnd
            }
    }

    private static func quietRuns(
        peaks: [Float], first: Int, last: Int, threshold: Float
    ) -> [Range<Int>] {
        var runs: [Range<Int>] = []
        var runStart: Int?
        for index in first...last {
            if index < last, peaks[index] < threshold {
                if runStart == nil { runStart = index }
                continue
            }
            if let begin = runStart { runs.append(begin..<index) }
            runStart = nil
        }
        return runs
    }

    static func timelineRanges(
        _ ranges: [Range<TimeInterval>], for clip: Clip
    ) -> [Range<TimeInterval>] {
        ranges.compactMap { range in
            let start = clip.timelineTime(forSourceTime: range.lowerBound)
            let end = clip.timelineTime(forSourceTime: range.upperBound)
            let lower = max(start, clip.startInSeconds)
            let upper = min(end, clip.endInSeconds)
            guard upper - lower >= Clip.minimumDurationInSeconds else { return nil }
            return lower..<upper
        }
    }
}
