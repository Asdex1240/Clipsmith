import AVFoundation
import AppKit
import XCTest
@testable import Clipsmith

final class ProjectExporterTests: XCTestCase {
    private var directory: URL!
    private var exporter: ProjectExporter!
    private var project = Project(name: "Test")

    private var mainTrackID: Track.ID { project.track(withRole: .main)!.id }
    private var audioTrackID: Track.ID { project.track(withRole: .audio)!.id }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stills = StillImageVideoWriter(directory: directory.appendingPathComponent("stills"))
        exporter = ProjectExporter(builder: CompositionBuilder(stillImages: stills))
        project = Project(name: "Test")
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testEmptyProjectCannotBeExported() async {
        do {
            try await exporter.export(
                project, with: ExportPreset.youtube1080.settings, to: output()
            ) { _ in }
            XCTFail("Expected an error")
        } catch ExportError.nothingToExport {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testExportsH264AtTheRequestedSizeDurationAndWithAudio() async throws {
        try addImageAndMusic(duration: 3)
        let url = output()

        try await exporter.export(project, with: ExportPreset.youtube1080.settings, to: url) { _ in
        }

        let info = try await inspect(url)
        XCTAssertEqual(info.size, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(info.codec, kCMVideoCodecType_H264)
        XCTAssertEqual(info.duration, 3, accuracy: 0.2)
        XCTAssertTrue(info.hasAudio)
    }

    func testExportsHEVCWhenRequested() async throws {
        try addImageAndMusic(duration: 2)
        var settings = ExportPreset.youtube1080.settings
        settings.codec = .hevc
        let url = output()

        try await exporter.export(project, with: settings, to: url) { _ in }

        let info = try await inspect(url)
        XCTAssertEqual(info.codec, kCMVideoCodecType_HEVC)
    }

    func testPortraitProjectExportsVerticalVideo() async throws {
        try addImageAndMusic(duration: 2)
        project.canvas = .portrait
        let url = output()

        try await exporter.export(project, with: ExportPreset.vertical1080.settings, to: url) { _ in
        }

        let info = try await inspect(url)
        XCTAssertEqual(info.size, CGSize(width: 1080, height: 1920))
    }

    func testProgressNeverDecreasesAndEndsAtOne() async throws {
        try addImageAndMusic(duration: 3)
        let recorder = ProgressRecorder()

        try await exporter.export(project, with: ExportPreset.youtube1080.settings, to: output()) {
            recorder.record($0)
        }

        let values = recorder.values
        XCTAssertEqual(values.last, 1)
        XCTAssertEqual(values, values.sorted())
    }

    func testReplacesAnExistingFileAtTheDestination() async throws {
        try addImageAndMusic(duration: 2)
        let url = output()
        try Data("old".utf8).write(to: url)

        try await exporter.export(project, with: ExportPreset.youtube1080.settings, to: url) { _ in
        }

        let info = try await inspect(url)
        XCTAssertEqual(info.duration, 2, accuracy: 0.2)
    }

    private func output() -> URL {
        directory.appendingPathComponent("out-\(UUID().uuidString).mp4")
    }

    private func addImageAndMusic(duration: TimeInterval) throws {
        let image = try makeImage()
        let music = try makeSilentWav(seconds: duration)
        project.addClip(
            Clip(
                sourceURL: image, mediaKind: .image, startInSeconds: 0, sourceStartInSeconds: 0,
                sourceEndInSeconds: duration),
            toTrack: mainTrackID
        )
        project.addClip(
            Clip(
                sourceURL: music, mediaKind: .audio, startInSeconds: 0, sourceStartInSeconds: 0,
                sourceEndInSeconds: duration, sourceDurationInSeconds: duration
            ),
            toTrack: audioTrackID
        )
    }

    private func inspect(
        _ url: URL
    ) async throws -> (
        size: CGSize, codec: CMVideoCodecType, duration: TimeInterval, hasAudio: Bool
    ) {
        let asset = AVURLAsset(url: url)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let video = try XCTUnwrap(videoTracks.first)
        let size = try await video.load(.naturalSize)
        let descriptions = try await video.load(.formatDescriptions)
        let codec = try XCTUnwrap(descriptions.first).mediaSubType.rawValue
        let duration = try await asset.load(.duration).seconds
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        return (size, codec, duration, !audioTracks.isEmpty)
    }

    private func makeImage() throws -> URL {
        let bitmap = try XCTUnwrap(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 36, bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
                bitsPerPixel: 0
            ))
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

private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [Double] = []

    var values: [Double] {
        lock.withLock { recorded }
    }

    func record(_ value: Double) {
        lock.withLock { recorded.append(value) }
    }
}
