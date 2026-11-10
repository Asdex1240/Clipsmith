import AVFoundation
import AppKit
import XCTest
@testable import Clipsmith

final class ExportTextAndAudioTests: XCTestCase {
    private var directory: URL!
    private var exporter: ProjectExporter!
    private var builder: CompositionBuilder!
    private var project = Project(name: "Test")

    private var mainTrackID: Track.ID { project.track(withRole: .main)!.id }
    private var audioTrackID: Track.ID { project.track(withRole: .audio)!.id }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stills = StillImageVideoWriter(directory: directory.appendingPathComponent("stills"))
        builder = CompositionBuilder(stillImages: stills)
        exporter = ProjectExporter(builder: builder)
        project = Project(name: "Test")
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testTextAppearsAtTheRequestedPlaceAndOnlyDuringItsClip() async throws {
        project.addClip(try imageClip(duration: 3), toTrack: mainTrackID)
        var text = TextLayer(content: "MMMMMM")
        text.fontSize = 220
        text.positionY = 0.2
        project.addTextClip(text, at: 0.5, duration: 1)
        let url = directory.appendingPathComponent("out.mp4")

        try await exporter.export(project, with: ExportPreset.youtube1080.settings, to: url) { _ in }

        let withText = try await frame(of: url, at: 1.0)
        let withoutText = try await frame(of: url, at: 2.5)
        XCTAssertGreaterThan(brightPixels(in: withText, rows: 0.0..<0.45), 500)
        XCTAssertEqual(brightPixels(in: withText, rows: 0.55..<1.0), 0)
        XCTAssertEqual(brightPixels(in: withoutText, rows: 0.0..<1.0), 0)
    }

    func testVolumeAndFadesBecomeAudioMixRamps() async throws {
        let music = try makeSilentWav(seconds: 6)
        let clip = Clip(
            sourceURL: music, mediaKind: .audio, startInSeconds: 0, sourceStartInSeconds: 0,
            sourceEndInSeconds: 6, sourceDurationInSeconds: 6
        ).settingVolume(0.5).settingFadeIn(1).settingFadeOut(2)
        project.addClip(clip, toTrack: audioTrackID)

        let built = try await builder.build(from: project)

        let mix = try XCTUnwrap(built.audioMix)
        let parameters = try XCTUnwrap(mix.inputParameters.first)
        var start: Float = -1
        var end: Float = -1
        var range = CMTimeRange.zero
        XCTAssertTrue(parameters.getVolumeRamp(for: 0.5.cmTime, startVolume: &start, endVolume: &end, timeRange: &range))
        XCTAssertEqual(start, 0, accuracy: 0.001)
        XCTAssertEqual(end, 0.5, accuracy: 0.001)
        XCTAssertEqual(range.duration.seconds, 1, accuracy: 0.01)
        XCTAssertTrue(parameters.getVolumeRamp(for: 5.0.cmTime, startVolume: &start, endVolume: &end, timeRange: &range))
        XCTAssertEqual(start, 0.5, accuracy: 0.001)
        XCTAssertEqual(end, 0, accuracy: 0.001)
        XCTAssertEqual(range.start.seconds, 4, accuracy: 0.01)
    }

    func testBrollAudioStaysMutedAndTextClipsDoNotBreakTheComposition() async throws {
        project.addClip(try imageClip(duration: 2), toTrack: mainTrackID)
        project.addTextClip(TextLayer(content: "Hi"), at: 0, duration: 2)

        let built = try await builder.build(from: project)

        XCTAssertNil(built.audioMix)
        XCTAssertEqual(built.textOverlay?.clips.count, 1)
        XCTAssertEqual(built.durationInSeconds, 2, accuracy: 0.05)
    }

    func testExportedAudioKeepsItsDurationWithFades() async throws {
        project.addClip(try imageClip(duration: 3), toTrack: mainTrackID)
        let music = try makeSilentWav(seconds: 3)
        project.addClip(
            Clip(
                sourceURL: music, mediaKind: .audio, startInSeconds: 0, sourceStartInSeconds: 0,
                sourceEndInSeconds: 3, sourceDurationInSeconds: 3
            ).settingFadeIn(1).settingFadeOut(1),
            toTrack: audioTrackID
        )
        let url = directory.appendingPathComponent("faded.mp4")

        try await exporter.export(project, with: ExportPreset.youtube1080.settings, to: url) { _ in }

        let asset = AVURLAsset(url: url)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertFalse(audioTracks.isEmpty)
        let duration = try await asset.load(.duration)
        XCTAssertEqual(duration.seconds, 3, accuracy: 0.2)
    }

    private func frame(of url: URL, at seconds: Double) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        return try await generator.image(at: seconds.cmTime).image
    }

    private func brightPixels(in image: CGImage, rows: Range<Double>) -> Int {
        let width = image.width
        let height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return -1 }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let firstRow = Int(rows.lowerBound * Double(height))
        let lastRow = Int(rows.upperBound * Double(height))
        var count = 0
        for row in firstRow..<lastRow {
            for column in 0..<width {
                let offset = (row * width + column) * 4
                if data[offset] > 200, data[offset + 1] > 200, data[offset + 2] > 200 { count += 1 }
            }
        }
        return count
    }

    private func imageClip(duration: TimeInterval) throws -> Clip {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 36, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let url = directory.appendingPathComponent("black.png")
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
        return Clip(sourceURL: url, mediaKind: .image, startInSeconds: 0, sourceStartInSeconds: 0, sourceEndInSeconds: duration)
    }

    private func makeSilentWav(seconds: Double) throws -> URL {
        let url = directory.appendingPathComponent("music-\(UUID().uuidString).wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let frameCount = AVAudioFrameCount(format.sampleRate * seconds)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
        buffer.frameLength = frameCount
        try AVAudioFile(forWriting: url, settings: format.settings).write(from: buffer)
        return url
    }
}
