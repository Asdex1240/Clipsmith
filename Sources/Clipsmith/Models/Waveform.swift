import Foundation

enum WaveformSpec {
    static let peaksPerSecond = 50.0
}

struct PeakAccumulator {
    private let samplesPerPeak: Int
    private var peaks: [Float] = []
    private var currentPeak: Float = 0
    private var samplesInCurrentPeak = 0

    init(samplesPerPeak: Int) {
        self.samplesPerPeak = max(1, samplesPerPeak)
    }

    mutating func add(_ samples: [Int16]) {
        for sample in samples {
            currentPeak = max(currentPeak, Float(abs(Int32(sample))) / Float(Int16.max))
            samplesInCurrentPeak += 1
            if samplesInCurrentPeak == samplesPerPeak { closeCurrentPeak() }
        }
    }

    mutating func finish() -> [Float] {
        if samplesInCurrentPeak > 0 { closeCurrentPeak() }
        return peaks
    }

    private mutating func closeCurrentPeak() {
        peaks.append(min(currentPeak, 1))
        currentPeak = 0
        samplesInCurrentPeak = 0
    }
}

enum WaveformResampler {
    static func columns(
        peaks: [Float],
        peaksPerSecond: Double,
        sourceStart: TimeInterval,
        sourceEnd: TimeInterval,
        columnCount: Int
    ) -> [Float] {
        guard columnCount > 0, sourceEnd > sourceStart else { return [] }
        let span = sourceEnd - sourceStart
        return (0..<columnCount).map { column in
            let start = sourceStart + span * Double(column) / Double(columnCount)
            let end = sourceStart + span * Double(column + 1) / Double(columnCount)
            return peak(in: peaks, from: start * peaksPerSecond, to: end * peaksPerSecond)
        }
    }

    private static func peak(in peaks: [Float], from lower: Double, to upper: Double) -> Float {
        let first = max(0, Int(lower.rounded(.down)))
        let last = min(peaks.count, max(first + 1, Int(upper.rounded(.up))))
        guard first < last else { return 0 }
        return peaks[first..<last].max() ?? 0
    }
}
