import Foundation

enum LoudnessNormalizer {
    static let targetLevel: Float = 0.35
    static let peakCeiling: Float = 0.95
    static let silenceFloor: Float = 0.02
    static let percentile = 0.9
    static let minimumActiveSeconds: TimeInterval = 1

    static func volume(
        peaks: [Float], from start: TimeInterval, to end: TimeInterval,
        peaksPerSecond: Double = WaveformSpec.peaksPerSecond
    ) -> Double? {
        let first = max(0, Int(start * peaksPerSecond))
        let last = min(Int(end * peaksPerSecond), peaks.count)
        guard first < last else { return nil }
        let slice = peaks[first..<last]
        let active = slice.filter { $0 >= silenceFloor }.sorted()
        guard Double(active.count) / peaksPerSecond >= minimumActiveSeconds,
            let maximum = active.last
        else { return nil }
        let level = active[min(Int(Double(active.count) * percentile), active.count - 1)]
        let wanted = min(targetLevel / level, peakCeiling / maximum)
        return min(max(Double(wanted), 0), Clip.maximumVolume)
    }
}
