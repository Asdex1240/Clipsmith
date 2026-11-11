import XCTest
@testable import Clipsmith

final class SpectralDenoiserTests: XCTestCase {
    private let rate = 16_000.0
    private let seconds = 8.0

    private struct Signal {
        var clean: [Float]
        var noisy: [Float]
        var isSpeech: [Bool]
    }

    private func makeSignal() -> Signal {
        var generator = SystemRandomNumberGenerator()
        let count = Int(rate * seconds)
        var clean = [Float](repeating: 0, count: count)
        var noisy = clean
        var speech = [Bool](repeating: false, count: count)
        for index in 0..<count {
            let time = Double(index) / rate
            let isOn = Int(time / 0.7) % 2 == 0
            speech[index] = isOn
            if isOn { clean[index] = Float(0.3 * sin(2 * .pi * 1000 * time)) }
            noisy[index] = clean[index] + Float.random(in: -0.05...0.05, using: &generator)
        }
        return Signal(clean: clean, noisy: noisy, isSpeech: speech)
    }

    private func denoise(_ input: [Float], level: NoiseReductionLevel) -> [Float] {
        let denoiser = SpectralDenoiser(sampleRate: rate, level: level)
        var output: [Float] = []
        var offset = 0
        while offset < input.count {
            let end = min(offset + 4_000, input.count)
            output += denoiser.process(Array(input[offset..<end]))
            offset = end
        }
        output += denoiser.finish()
        return output
    }

    private func rms(_ values: [Float], where include: (Int) -> Bool) -> Float {
        var total: Float = 0
        var count = 0
        for index in values.indices where include(index) {
            total += values[index] * values[index]
            count += 1
        }
        return sqrt(total / Float(max(count, 1)))
    }

    func testOutputHasTheSameLengthAsTheInput() {
        let signal = makeSignal()

        XCTAssertEqual(denoise(signal.noisy, level: .medium).count, signal.noisy.count)
    }

    func testChunkSizeDoesNotChangeTheLength() {
        let input = makeSignal().noisy
        let denoiser = SpectralDenoiser(sampleRate: rate, level: .light)

        var output = denoiser.process(Array(input[0..<1]))
        output += denoiser.process(Array(input[1..<777]))
        output += denoiser.process(Array(input[777...]))
        output += denoiser.finish()

        XCTAssertEqual(output.count, input.count)
    }

    func testNoiseBetweenSpeechIsReducedMoreAtHigherLevels() {
        let signal = makeSignal()
        let settled = Int(rate * 3)
        let before = rms(signal.noisy) { $0 > settled && !signal.isSpeech[$0] }

        let medium = rms(denoise(signal.noisy, level: .medium)) {
            $0 > settled && !signal.isSpeech[$0]
        }
        let strong = rms(denoise(signal.noisy, level: .strong)) {
            $0 > settled && !signal.isSpeech[$0]
        }

        XCTAssertLessThan(medium, before * 0.5)
        XCTAssertLessThan(strong, before * 0.3)
    }

    func testTheSignalIsKeptWhereThereIsSpeech() {
        let signal = makeSignal()
        let settled = Int(rate * 3)

        let output = denoise(signal.noisy, level: .medium)

        let original = rms(signal.clean) { $0 > settled && signal.isSpeech[$0] }
        let kept = rms(output) { $0 > settled && signal.isSpeech[$0] }
        XCTAssertGreaterThan(kept, original * 0.8)
        XCTAssertLessThan(kept, original * 1.2)
    }

    func testStrongerLevelsRemoveMoreNoise() {
        let signal = makeSignal()
        let settled = Int(rate * 3)

        let levels = NoiseReductionLevel.allCases.map { level in
            rms(denoise(signal.noisy, level: level)) { $0 > settled && !signal.isSpeech[$0] }
        }

        XCTAssertGreaterThan(levels[0], levels[1])
        XCTAssertGreaterThan(levels[1], levels[2])
    }

    func testSilenceStaysSilent() {
        let output = denoise([Float](repeating: 0, count: 8_000), level: .strong)

        XCTAssertEqual(output.count, 8_000)
        XCTAssertTrue(output.allSatisfy { abs($0) < 1e-6 })
    }

    func testFFTRoundTripRestoresTheSignal() {
        let fft = FFT(size: 64)
        let original = (0..<64).map { Float(sin(Double($0) * 0.4)) }
        var real = original
        var imaginary = [Float](repeating: 0, count: 64)

        fft.forward(&real, &imaginary)
        fft.inverse(&real, &imaginary)

        for index in 0..<64 { XCTAssertEqual(real[index], original[index], accuracy: 1e-4) }
    }
}
