import Foundation

final class SpectralDenoiser {
    static let frameSize = 1024
    static let hop = 256
    private static let noiseSmoothing: Float = 0.85
    private static let noiseBias: Float = 1.8
    private static let subWindowSeconds = 0.5
    private static let subWindowCount = 6
    private static let gainRelease: Float = 0.6
    private static let tinyPower: Float = 1e-12

    private let level: NoiseReductionLevel
    private let fft = FFT(size: SpectralDenoiser.frameSize)
    private let window: [Float]
    private let framesPerSubWindow: Int
    private var pending: [Float]
    private var accumulator = [Float](repeating: 0, count: SpectralDenoiser.frameSize)
    private var toDrop = SpectralDenoiser.frameSize - SpectralDenoiser.hop
    private var totalIn = 0
    private var totalOut = 0
    private var smoothedPower: [Float] = []
    private var currentMinimum: [Float] = []
    private var history: [[Float]] = []
    private var framesInSubWindow = 0
    private var previousGain: [Float]

    private var bins: Int { Self.frameSize / 2 + 1 }

    init(sampleRate: Double, level: NoiseReductionLevel) {
        self.level = level
        let size = Self.frameSize
        window = (0..<size).map {
            Float(sqrt(0.5 - 0.5 * cos(2 * Double.pi * Double($0) / Double(size))))
        }
        framesPerSubWindow = max(
            1, Int(sampleRate * Self.subWindowSeconds / Double(Self.hop)))
        pending = [Float](repeating: 0, count: size - Self.hop)
        previousGain = [Float](repeating: 1, count: size / 2 + 1)
    }

    func process(_ samples: [Float]) -> [Float] {
        totalIn += samples.count
        pending.append(contentsOf: samples)
        return drain()
    }

    func finish() -> [Float] {
        pending.append(contentsOf: [Float](repeating: 0, count: Self.frameSize))
        var output = drain()
        let excess = totalOut - totalIn
        if excess > 0 { output.removeLast(min(excess, output.count)) }
        return output
    }

    private func drain() -> [Float] {
        var output: [Float] = []
        var offset = 0
        while pending.count - offset >= Self.frameSize {
            let finalized = processFrame(from: offset)
            offset += Self.hop
            if toDrop > 0 {
                let dropped = min(toDrop, finalized.count)
                toDrop -= dropped
                output.append(contentsOf: finalized.dropFirst(dropped))
            } else {
                output.append(contentsOf: finalized)
            }
        }
        pending.removeFirst(offset)
        totalOut += output.count
        return output
    }

    private func processFrame(from offset: Int) -> [Float] {
        let size = Self.frameSize
        var real = [Float](repeating: 0, count: size)
        var imaginary = [Float](repeating: 0, count: size)
        for index in 0..<size { real[index] = pending[offset + index] * window[index] }
        fft.forward(&real, &imaginary)
        var power = [Float](repeating: 0, count: bins)
        for bin in 0..<bins { power[bin] = real[bin] * real[bin] + imaginary[bin] * imaginary[bin] }
        let noise = estimateNoise(from: power)
        let gain = smoothedGain(power: power, noise: noise)
        for bin in 0..<bins {
            real[bin] *= gain[bin]
            imaginary[bin] *= gain[bin]
            if bin > 0 && bin < size / 2 {
                real[size - bin] = real[bin]
                imaginary[size - bin] = -imaginary[bin]
            }
        }
        fft.inverse(&real, &imaginary)
        for index in 0..<size { accumulator[index] += real[index] * window[index] * 0.5 }
        let finalized = Array(accumulator[0..<Self.hop])
        accumulator.removeFirst(Self.hop)
        accumulator.append(contentsOf: [Float](repeating: 0, count: Self.hop))
        return finalized
    }

    private func estimateNoise(from power: [Float]) -> [Float] {
        if smoothedPower.isEmpty {
            smoothedPower = power
            currentMinimum = power
        }
        for bin in 0..<bins {
            smoothedPower[bin] =
                Self.noiseSmoothing * smoothedPower[bin] + (1 - Self.noiseSmoothing) * power[bin]
            currentMinimum[bin] = min(currentMinimum[bin], smoothedPower[bin])
        }
        framesInSubWindow += 1
        if framesInSubWindow >= framesPerSubWindow {
            history.append(currentMinimum)
            if history.count > Self.subWindowCount { history.removeFirst() }
            currentMinimum = smoothedPower
            framesInSubWindow = 0
        }
        var noise = currentMinimum
        for past in history {
            for bin in 0..<bins { noise[bin] = min(noise[bin], past[bin]) }
        }
        return noise.map { $0 * Self.noiseBias }
    }

    private func smoothedGain(power: [Float], noise: [Float]) -> [Float] {
        let floor = level.floorGain
        var gain = [Float](repeating: 1, count: bins)
        for bin in 0..<bins {
            let ratio = noise[bin] / max(power[bin], Self.tinyPower)
            let amount = max(floor * floor, 1 - level.oversubtraction * ratio)
            gain[bin] = max(sqrt(amount), Self.gainRelease * previousGain[bin])
        }
        var blurred = gain
        for bin in 1..<(bins - 1) {
            blurred[bin] = 0.25 * gain[bin - 1] + 0.5 * gain[bin] + 0.25 * gain[bin + 1]
        }
        previousGain = blurred
        return blurred.map { min(max($0, floor), 1) }
    }
}
