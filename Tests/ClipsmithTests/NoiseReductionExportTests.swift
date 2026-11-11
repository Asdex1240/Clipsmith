import AVFoundation
import AppKit
import XCTest
@testable import Clipsmith

final class NoiseReductionExportTests: XCTestCase {
    private var directory: URL!
    private let rate = 16_000.0
    private let seconds = 8.0

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "nr-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeNoisyWav() throws -> URL {
        let url = directory.appendingPathComponent("noisy.wav")
        let format = try XCTUnwrap(
            AVAudioFormat(
                commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1, interleaved: false))
        let frames = Int(rate * seconds)
        let buffer = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)))
        buffer.frameLength = AVAudioFrameCount(frames)
        let data = try XCTUnwrap(buffer.floatChannelData)[0]
        for index in 0..<frames {
            let time = Double(index) / rate
            let tone = Int(time / 0.7) % 2 == 0 ? Float(0.3 * sin(2 * .pi * 1000 * time)) : 0
            data[index] = tone + Float.random(in: -0.05...0.05)
        }
        try AVAudioFile(forWriting: url, settings: format.settings).write(from: buffer)
        return url
    }

    private func makeImage() throws -> URL {
        let bitmap = try XCTUnwrap(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 36, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0))
        let url = directory.appendingPathComponent("black.png")
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    private func exportedQuietRMS(level: NoiseReductionLevel?) async throws -> Float {
        let image = try makeImage()
        var project = Project(name: "T")
        project.addClip(
            Clip(
                sourceURL: image, mediaKind: .image, startInSeconds: 0, sourceStartInSeconds: 0,
                sourceEndInSeconds: seconds),
            toTrack: project.track(withRole: .main)!.id)
        var audio = Clip(
            sourceURL: try makeNoisyWav(), mediaKind: .audio, startInSeconds: 0,
            sourceStartInSeconds: 0, sourceEndInSeconds: seconds, sourceDurationInSeconds: seconds)
        audio.noiseReduction = level
        project.addClip(audio, toTrack: project.track(withRole: .audio)!.id)
        let builder = CompositionBuilder(
            stillImages: StillImageVideoWriter(directory: directory.appendingPathComponent("stills")))
        let exporter = ProjectExporter(
            builder: builder,
            denoisedAudio: DenoisedAudioCache(directory: directory.appendingPathComponent("clean")))
        let output = directory.appendingPathComponent("out-\(level?.rawValue ?? "none").mp4")

        try await exporter.export(project, with: ExportPreset.youtube1080.settings, to: output) {
            _ in
        }

        let file = try AVAudioFile(forReading: output)
        let buffer = try XCTUnwrap(
            AVAudioPCMBuffer(
                pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let samples = try XCTUnwrap(buffer.floatChannelData)[0]
        let sampleRate = file.processingFormat.sampleRate
        var total: Float = 0
        var count = 0
        for index in Int(sampleRate * 3)..<Int(buffer.frameLength) {
            guard Int(Double(index) / sampleRate / 0.7) % 2 == 1 else { continue }
            total += samples[index] * samples[index]
            count += 1
        }
        return sqrt(total / Float(max(count, 1)))
    }

    func testTheExportUsesTheCleanedAudio() async throws {
        let plain = try await exportedQuietRMS(level: nil)
        let cleaned = try await exportedQuietRMS(level: .strong)

        XCTAssertGreaterThan(plain, 0.01)
        XCTAssertLessThan(cleaned, plain * 0.5)
    }
}
