import Foundation

enum SpeechActivity {
    static let defaultThreshold: Float = 0.04
    static let mergeGapInSeconds: TimeInterval = 0.5
    static let minimumDurationInSeconds: TimeInterval = 0.2

    static func ranges(
        peaks: [Float], from start: TimeInterval, to end: TimeInterval,
        threshold: Float = defaultThreshold,
        peaksPerSecond: Double = WaveformSpec.peaksPerSecond
    ) -> [Range<TimeInterval>] {
        let first = max(0, Int(start * peaksPerSecond))
        let last = min(Int(end * peaksPerSecond), peaks.count)
        guard first < last else { return [] }
        var runs: [Range<TimeInterval>] = []
        var runStart: Int?
        for index in first...last {
            let isActive = index < last && peaks[index] >= threshold
            if isActive {
                if runStart == nil { runStart = index }
            } else if let begin = runStart {
                runs.append(Double(begin) / peaksPerSecond..<Double(index) / peaksPerSecond)
                runStart = nil
            }
        }
        return merged(runs, gap: mergeGapInSeconds).filter {
            $0.upperBound - $0.lowerBound >= minimumDurationInSeconds
        }
    }

    static func merged(_ ranges: [Range<TimeInterval>], gap: TimeInterval) -> [Range<TimeInterval>]
    {
        var result: [Range<TimeInterval>] = []
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = result.last, range.lowerBound - last.upperBound < gap {
                result[result.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                result.append(range)
            }
        }
        return result
    }
}
