import AVFoundation
import AppKit
import XCTest
@testable import Clipsmith

final class CompositionBuilderTests: XCTestCase {
    private var directory: URL!
    private var builder: CompositionBuilder!
    private var project = Project(name: "Test")

    private var mainTrackID: Track.ID { project.track(withRole: .main)!.id }
    private var brollTrackID: Track.ID { project.track(withRole: .broll)!.id }
    private var audioTrackID: Track.ID { project.track(withRole: .audio)!.id }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        builder = CompositionBuilder(stillImages: StillImageVideoWriter(directory: directory.appendingPathComponent("stills")))
        project = Project(name: "Test")
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testEmptyProjectBuildsAnEmptyComposition() async throws {
        let built = try await builder.build(from: project)

        XCTAssertEqual(built.durationInSeconds, 0)
        XCTAssertNil(built.videoComposition)
    }

    func testStillImageClipIsStretchedToItsDuration() async throws {
        let image = try makeImage(named: "photo.png")
        project.addClip(imageClip(image, start: 0, duration: 4), toTrack: mainTrackID)

        let built = try await builder.build(from: project)

        XCTAssertEqual(built.durationInSeconds, 4, accuracy: 0.05)
        XCTAssertTrue(built.skippedClipIDs.isEmpty)
        XCTAssertEqual(built.videoComposition?.renderSize, CanvasFormat.landscape.renderSize)
    }

    func testChainedImagesPlayBackToBack() async throws {
        let image = try makeImage(named: "photo.png")
        project.addClip(imageClip(image, start: 0, duration: 3), toTrack: mainTrackID)
        project.addClip(imageClip(image, start: 3, duration: 2), toTrack: mainTrackID)

        let built = try await builder.build(from: project)

        XCTAssertEqual(built.durationInSeconds, 5, accuracy: 0.05)
        XCTAssertEqual(built.videoComposition?.instructions.count, 2)
    }

    func testBrollAddsALayerWhereItOverlapsMain() async throws {
        let image = try makeImage(named: "photo.png")
        project.addClip(imageClip(image, start: 0, duration: 10), toTrack: mainTrackID)
        project.addClip(imageClip(image, start: 4, duration: 2), toTrack: brollTrackID)

        let built = try await builder.build(from: project)

        let layerCounts = built.videoComposition?.instructions
            .compactMap { ($0 as? AVVideoCompositionInstruction)?.layerInstructions.count }
        XCTAssertEqual(layerCounts, [1, 2, 1])
    }

    func testPortraitCanvasChangesTheRenderSize() async throws {
        let image = try makeImage(named: "photo.png")
        project.canvas = .portrait
        project.addClip(imageClip(image, start: 0, duration: 2), toTrack: mainTrackID)

        let built = try await builder.build(from: project)

        XCTAssertEqual(built.videoComposition?.renderSize, CanvasFormat.portrait.renderSize)
    }

    func testAudioClipIsAddedAndBeyondVideoExtendsTheComposition() async throws {
        let image = try makeImage(named: "photo.png")
        let music = try makeSilentWav(seconds: 6)
        project.addClip(imageClip(image, start: 0, duration: 2), toTrack: mainTrackID)
        project.addClip(audioClip(music, start: 0, duration: 6), toTrack: audioTrackID)

        let built = try await builder.build(from: project)

        XCTAssertEqual(built.durationInSeconds, 6, accuracy: 0.05)
        XCTAssertEqual(built.composition.tracks(withMediaType: .audio).count, 1)
    }

    func testUnreadableClipIsSkippedWithoutBreakingTheRest() async throws {
        let image = try makeImage(named: "photo.png")
        let broken = directory.appendingPathComponent("broken.mp4")
        try Data("nope".utf8).write(to: broken)
        let brokenClip = TestClips.video(start: 0, sourceEnd: 3)
        var unreadable = brokenClip
        unreadable.sourceURL = broken
        project.addClip(unreadable, toTrack: brollTrackID)
        project.addClip(imageClip(image, start: 0, duration: 3), toTrack: mainTrackID)

        let built = try await builder.build(from: project)

        XCTAssertEqual(built.skippedClipIDs, [unreadable.id])
        XCTAssertEqual(built.durationInSeconds, 3, accuracy: 0.05)
    }

    func testBuiltCompositionRendersFramesWithTheVideoComposition() async throws {
        let image = try makeImage(named: "photo.png")
        project.addClip(imageClip(image, start: 0, duration: 3), toTrack: mainTrackID)
        project.addClip(imageClip(image, start: 5, duration: 3), toTrack: mainTrackID)
        project.addClip(imageClip(image, start: 1, duration: 1), toTrack: brollTrackID)
        let built = try await builder.build(from: project)
        let generator = AVAssetImageGenerator(asset: built.composition)
        generator.videoComposition = built.videoComposition

        for second in [0.5, 1.5, 4, 6.5] {
            let frame = try await generator.image(at: second.cmTime).image
            XCTAssertEqual(CGFloat(frame.width), CanvasFormat.landscape.renderSize.width)
            XCTAssertEqual(CGFloat(frame.height), CanvasFormat.landscape.renderSize.height)
        }
    }

    func testStillVideoWriterProducesAOneSecondVideoAtTheRequestedSize() async throws {
        let image = try makeImage(named: "photo.png")
        let writer = StillImageVideoWriter(directory: directory.appendingPathComponent("direct"))

        let url = try await writer.makeVideo(from: image, size: CanvasFormat.portrait.renderSize)

        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let size = try await track.load(.naturalSize)
        XCTAssertEqual(duration.seconds, 1, accuracy: 0.1)
        XCTAssertEqual(size, CanvasFormat.portrait.renderSize)
    }

    func testStillVideoWriterReusesTheCachedFile() async throws {
        let image = try makeImage(named: "photo.png")
        let writer = StillImageVideoWriter(directory: directory.appendingPathComponent("cache"))

        let first = try await writer.makeVideo(from: image, size: CanvasFormat.landscape.renderSize)
        let second = try await writer.makeVideo(from: image, size: CanvasFormat.landscape.renderSize)

        XCTAssertEqual(first, second)
    }

    private func imageClip(_ url: URL, start: TimeInterval, duration: TimeInterval) -> Clip {
        Clip(
            sourceURL: url,
            mediaKind: .image,
            startInSeconds: start,
            sourceStartInSeconds: 0,
            sourceEndInSeconds: duration
        )
    }

    private func audioClip(_ url: URL, start: TimeInterval, duration: TimeInterval) -> Clip {
        Clip(
            sourceURL: url,
            mediaKind: .audio,
            startInSeconds: start,
            sourceStartInSeconds: 0,
            sourceEndInSeconds: duration,
            sourceDurationInSeconds: duration
        )
    }

    private func makeImage(named name: String) throws -> URL {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 36, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let url = directory.appendingPathComponent(name)
        try png.write(to: url)
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
