import Foundation

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
