import Foundation

enum HighlightSuggester {
    static let defaultDurationInSeconds: TimeInterval = 30
    static let defaultCount = 5
    static let minimumSourceDurationInSeconds: TimeInterval = 10
    static let silenceFloor: Float = 0.02
    static let snapRadiusInSeconds = 2

    static func suggestions(
        peaks: [Float], from start: TimeInterval, to end: TimeInterval,
        duration: TimeInterval = defaultDurationInSeconds, count: Int = defaultCount,
        peaksPerSecond: Double = WaveformSpec.peaksPerSecond
    ) -> [ClosedRange<TimeInterval>] {
        let energy = secondlyEnergy(
            peaks: peaks, from: start, to: end, peaksPerSecond: peaksPerSecond)
        guard Double(energy.count) >= minimumSourceDurationInSeconds, count > 0 else { return [] }
        let window = min(Int(duration), energy.count)
        guard window > 0 else { return [] }
        let totals = prefixSums(of: energy)
        var chosen: [Range<Int>] = []
        while chosen.count < count,
            let best = bestWindow(
                totals: totals, window: window, count: energy.count, avoiding: chosen)
        {
            let mean = (totals[best.upperBound] - totals[best.lowerBound]) / Float(window)
            guard mean >= silenceFloor else { break }
            chosen.append(best)
        }
        return chosen.sorted { $0.lowerBound < $1.lowerBound }.map {
            let snappedStart = quietest(near: $0.lowerBound, in: energy)
            let snappedEnd = quietest(near: $0.upperBound, in: energy, upperBound: energy.count)
            let lower = start + Double(snappedStart)
            return lower...max(lower + 1, start + Double(snappedEnd))
        }
    }

    private static func secondlyEnergy(
        peaks: [Float], from start: TimeInterval, to end: TimeInterval, peaksPerSecond: Double
    ) -> [Float] {
        let seconds = Int(floor(end - start))
        guard seconds > 0 else { return [] }
        return (0..<seconds).map { second in
            let first = Int((start + Double(second)) * peaksPerSecond)
            let last = min(Int((start + Double(second + 1)) * peaksPerSecond), peaks.count)
            guard first < last else { return 0 }
            return peaks[first..<last].reduce(0, +) / Float(last - first)
        }
    }

    private static func prefixSums(of values: [Float]) -> [Float] {
        var sums: [Float] = [0]
        sums.reserveCapacity(values.count + 1)
        for value in values { sums.append(sums[sums.count - 1] + value) }
        return sums
    }

    private static func bestWindow(
        totals: [Float], window: Int, count: Int, avoiding chosen: [Range<Int>]
    ) -> Range<Int>? {
        var best: Range<Int>?
        var bestTotal = -Float.infinity
        for lower in 0...(count - window) {
            let candidate = lower..<(lower + window)
            guard !chosen.contains(where: { $0.overlaps(candidate) }) else { continue }
            let total = totals[candidate.upperBound] - totals[candidate.lowerBound]
            if total > bestTotal {
                bestTotal = total
                best = candidate
            }
        }
        return best
    }

    private static func quietest(
        near index: Int, in energy: [Float], upperBound: Int? = nil
    ) -> Int {
        let limit = upperBound ?? energy.count - 1
        let lower = max(0, index - snapRadiusInSeconds)
        let upper = min(limit, index + snapRadiusInSeconds)
        guard lower <= upper else { return min(max(index, 0), limit) }
        return (lower...upper).min { value(energy, $0) < value(energy, $1) } ?? index
    }

    private static func value(_ energy: [Float], _ index: Int) -> Float {
        guard index < energy.count else { return 0 }
        return energy[index]
    }
}
