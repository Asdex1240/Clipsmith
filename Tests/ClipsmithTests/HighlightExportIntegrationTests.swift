import AVFoundation
import AppKit
import XCTest

@testable import Clipsmith

final class HighlightExportIntegrationTests: XCTestCase {
    private var directory: URL!
    private var project = Project(name: "Vlog")

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        project = Project(name: "Vlog")
        try addImageAndMusic(duration: 8)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testEachHighlightBecomesAVerticalMP4WithItsOwnDurationAndAudio() async throws {
        let stills = StillImageVideoWriter(directory: directory.appendingPathComponent("stills"))
        let batch = HighlightBatchExporter(
            exporter: ProjectExporter(builder: CompositionBuilder(stillImages: stills)))
        let highlights = [
            Highlight(name: "Opening", startInSeconds: 1, endInSeconds: 4),
            Highlight(name: "Ending", startInSeconds: 5, endInSeconds: 7, framingOffsetX: 0.5),
        ]
        let folder = directory.appendingPathComponent("out")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let outcomes = try await batch.export(project, highlights: highlights, to: folder) { _ in }

        XCTAssertEqual(outcomes.count, 2)
        for (outcome, expected) in zip(outcomes, [3.0, 2.0]) {
            guard case .exported(let url) = outcome.result else {
                return XCTFail("Expected an exported file, got \(outcome)")
            }
            let info = try await inspect(url)
            XCTAssertEqual(info.size, CGSize(width: 1080, height: 1920))
            XCTAssertEqual(info.duration, expected, accuracy: 0.3)
            XCTAssertTrue(info.hasAudio)
        }
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted(),
            ["Ending.mp4", "Opening.mp4"])
    }

    private func addImageAndMusic(duration: TimeInterval) throws {
        let image = try makeImage()
        let music = try makeSilentWav(seconds: duration)
        let main = project.track(withRole: .main)!.id
        let audio = project.track(withRole: .audio)!.id
        project.addClip(
            Clip(
                sourceURL: image, mediaKind: .image, startInSeconds: 0, sourceStartInSeconds: 0,
                sourceEndInSeconds: duration),
            toTrack: main)
        project.addClip(
            Clip(
                sourceURL: music, mediaKind: .audio, startInSeconds: 0, sourceStartInSeconds: 0,
                sourceEndInSeconds: duration, sourceDurationInSeconds: duration),
            toTrack: audio)
    }

    private func inspect(
        _ url: URL
    ) async throws -> (
        size: CGSize, duration: TimeInterval, hasAudio: Bool
    ) {
        let asset = AVURLAsset(url: url)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let video = try XCTUnwrap(videoTracks.first)
        let size = try await video.load(.naturalSize)
        let duration = try await asset.load(.duration).seconds
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let hasAudio = !audioTracks.isEmpty
        return (size, duration, hasAudio)
    }

    private func makeImage() throws -> URL {
        let bitmap = try XCTUnwrap(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 36, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let url = directory.appendingPathComponent("photo.png")
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    private func makeSilentWav(seconds: Double) throws -> URL {
        let url = directory.appendingPathComponent("silence.wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let frameCount = AVAudioFrameCount(format.sampleRate * seconds)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
        buffer.frameLength = frameCount
        try AVAudioFile(forWriting: url, settings: format.settings).write(from: buffer)
        return url
    }
}
