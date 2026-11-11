import AVFoundation
import XCTest
@testable import Clipsmith

final class WaveformTests: XCTestCase {
    func testAccumulatorKeepsThePeakOfEachGroupOfSamples() {
        var accumulator = PeakAccumulator(samplesPerPeak: 4)

        accumulator.add([0, 1000, -16_383, 0, 100, 200, 300, 400])

        let peaks = accumulator.finish()
        XCTAssertEqual(peaks.count, 2)
        XCTAssertEqual(peaks[0], 0.5, accuracy: 0.001)
        XCTAssertEqual(peaks[1], 400 / 32_767, accuracy: 0.001)
    }

    func testAccumulatorFlushesAPartialGroupOnFinish() {
        var accumulator = PeakAccumulator(samplesPerPeak: 10)

        accumulator.add([Int16.max, 0, 0])

        XCTAssertEqual(accumulator.finish(), [1])
    }

    func testAccumulatorHandlesTheMostNegativeSample() {
        var accumulator = PeakAccumulator(samplesPerPeak: 1)

        accumulator.add([Int16.min])

        XCTAssertEqual(accumulator.finish(), [1])
    }

    func testResamplerTakesTheMaximumOfEachColumn() {
        let peaks: [Float] = [0.1, 0.9, 0.2, 0.3]

        let columns = WaveformResampler.columns(
            peaks: peaks, peaksPerSecond: 1, sourceStart: 0, sourceEnd: 4, columnCount: 2
        )

        XCTAssertEqual(columns, [0.9, 0.3])
    }

    func testResamplerRespectsTheTrimmedSourceRange() {
        let peaks: [Float] = [0.1, 0.9, 0.2, 0.3]

        let columns = WaveformResampler.columns(
            peaks: peaks, peaksPerSecond: 1, sourceStart: 2, sourceEnd: 4, columnCount: 2
        )

        XCTAssertEqual(columns, [0.2, 0.3])
    }

    func testResamplerReturnsSilenceBeyondTheAvailablePeaks() {
        let columns = WaveformResampler.columns(
            peaks: [0.5], peaksPerSecond: 1, sourceStart: 10, sourceEnd: 12, columnCount: 2
        )

        XCTAssertEqual(columns, [0, 0])
    }

    func testResamplerWithInvalidInputIsEmpty() {
        XCTAssertTrue(
            WaveformResampler.columns(
                peaks: [1], peaksPerSecond: 1, sourceStart: 0, sourceEnd: 0, columnCount: 3
            ).isEmpty)
        XCTAssertTrue(
            WaveformResampler.columns(
                peaks: [1], peaksPerSecond: 1, sourceStart: 0, sourceEnd: 1, columnCount: 0
            ).isEmpty)
    }

    func testGeneratorSeesSilenceFollowedBySound() async throws {
        let url = try makeWav(silenceSeconds: 1, toneSeconds: 1)
        defer { try? FileManager.default.removeItem(at: url) }

        let peaks = await AVWaveformGenerator().peaks(for: url)

        XCTAssertEqual(Double(peaks.count), 2 * WaveformSpec.peaksPerSecond, accuracy: 3)
        let half = peaks.count / 2
        XCTAssertLessThan(peaks[..<(half - 2)].max() ?? 1, 0.01)
        XCTAssertGreaterThan(peaks[(half + 2)...].max() ?? 0, 0.3)
    }

    func testGeneratorReturnsNothingForFilesWithoutAudio() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(UUID().uuidString).png")
        try Data("x".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let peaks = await AVWaveformGenerator().peaks(for: url)

        XCTAssertTrue(peaks.isEmpty)
    }

    @MainActor
    func testStoreLoadsEachFileOnce() async {
        let generator = CountingGenerator()
        let store = WaveformStore(generator: generator)
        let url = URL(fileURLWithPath: "/tmp/a.wav")

        await store.load(url)
        await store.load(url)

        XCTAssertEqual(generator.callCount, 1)
        XCTAssertEqual(store.peaksByURL[url], [0.5])
    }

    private func makeWav(silenceSeconds: Double, toneSeconds: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(UUID().uuidString).wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let silenceFrames = Int(format.sampleRate * silenceSeconds)
        let toneFrames = Int(format.sampleRate * toneSeconds)
        let buffer = try XCTUnwrap(
            AVAudioPCMBuffer(
                pcmFormat: format, frameCapacity: AVAudioFrameCount(silenceFrames + toneFrames)))
        buffer.frameLength = AVAudioFrameCount(silenceFrames + toneFrames)
        let channel = try XCTUnwrap(buffer.floatChannelData?[0])
        for frame in 0..<toneFrames {
            channel[silenceFrames + frame] =
                0.8 * sin(Float(frame) * 2 * .pi * 440 / Float(format.sampleRate))
        }
        try AVAudioFile(forWriting: url, settings: format.settings).write(from: buffer)
        return url
    }
}

private final class CountingGenerator: WaveformGenerating, @unchecked Sendable {
    private(set) var callCount = 0

    func peaks(for url: URL) async -> [Float] {
        callCount += 1
        return [0.5]
    }
}
