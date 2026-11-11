import AVFoundation
import XCTest
@testable import Clipsmith

final class PerformanceBenchmarkTests: XCTestCase {
    private static let sourceSize = CGSize(width: 3840, height: 2160)
    private static let sourceSeconds = 20.0
    private static let framesPerSecond = 30

    private var directory: URL!

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CLIPSMITH_BENCHMARK"] == "1",
            "Set CLIPSMITH_BENCHMARK=1 to run")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    func testExportOf4KHevcFootageTo1080pIsFasterThanTwiceItsDuration() async throws {
        let generationStart = Date()
        let source = try await makeHEVC4KVideo()
        print("BENCH source generated in \(seconds(since: generationStart)) s")
        let music = try makeSilentWav(seconds: 30)
        let project = makeVlogProject(source: source, music: music)
        let stills = StillImageVideoWriter(directory: directory.appendingPathComponent("stills"))
        let builder = CompositionBuilder(stillImages: stills)

        let buildStart = Date()
        let built = try await builder.build(from: project)
        let buildTime = seconds(since: buildStart)
        let duration = built.durationInSeconds

        let exportStart = Date()
        try await ProjectExporter(builder: builder).export(
            project, with: ExportPreset.youtube1080.settings,
            to: directory.appendingPathComponent("out.mp4")
        ) { _ in }
        let exportTime = seconds(since: exportStart)

        print("BENCH timeline duration \(duration) s, composition build \(buildTime) s")
        print(
            "BENCH export 1080p H.264: \(exportTime) s -> "
                + "ratio \(exportTime / duration)x (goal < 2x)"
        )
        XCTAssertLessThan(exportTime, duration * 2)
    }

    func testHevc4KSourceExportsAt4KWithinAReasonableTime() async throws {
        let source = try await makeHEVC4KVideo()
        let project = makeVlogProject(source: source, music: try makeSilentWav(seconds: 30))
        let builder = CompositionBuilder(
            stillImages: StillImageVideoWriter(
                directory: directory.appendingPathComponent("stills")))
        let duration = try await builder.build(from: project).durationInSeconds

        let start = Date()
        try await ProjectExporter(builder: builder).export(
            project, with: ExportPreset.youtube4K.settings,
            to: directory.appendingPathComponent("out4k.mp4")
        ) { _ in }
        let exportTime = seconds(since: start)

        print(
            "BENCH export 4K HEVC: \(exportTime) s for \(duration) s -> \(exportTime / duration)x")
    }

    private func makeVlogProject(source: URL, music: URL) -> Project {
        var project = Project(name: "Bench")
        let main = project.track(withRole: .main)!.id
        let broll = project.track(withRole: .broll)!.id
        let audio = project.track(withRole: .audio)!.id
        let ranges: [(start: Double, end: Double)] = [(0, 8), (10, 16), (4, 12)]
        var cursor = 0.0
        for range in ranges {
            let clip = makeClip(source: source, timelineStart: cursor, sourceRange: range)
            project.addClip(clip, toTrack: main)
            cursor += range.end - range.start
        }
        project.addClip(
            makeClip(source: source, timelineStart: 5, sourceRange: (2, 6)), toTrack: broll)
        project.addTextClip(TextLayer(content: "Benchmark vlog"), at: 1, duration: 4)
        let musicClip = Clip(
            sourceURL: music, mediaKind: .audio, startInSeconds: 0, sourceStartInSeconds: 0,
            sourceEndInSeconds: cursor, sourceDurationInSeconds: 30
        ).settingVolume(0.4).settingFadeIn(1).settingFadeOut(2)
        project.addClip(musicClip, toTrack: audio)
        return project
    }

    private func makeClip(
        source: URL, timelineStart: Double, sourceRange: (start: Double, end: Double)
    ) -> Clip {
        Clip(
            sourceURL: source, mediaKind: .video, startInSeconds: timelineStart,
            sourceStartInSeconds: sourceRange.start, sourceEndInSeconds: sourceRange.end,
            sourceDurationInSeconds: Self.sourceSeconds
        )
    }

    private func seconds(since start: Date) -> Double {
        (Date().timeIntervalSince(start) * 100).rounded() / 100
    }

    private func makeHEVC4KVideo() async throws -> URL {
        let url = directory.appendingPathComponent("source4k.mov")
        let width = Int(Self.sourceSize.width)
        let height = Int(Self.sourceSize.height)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 40_000_000],
            ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        let frameCount = Int(Self.sourceSeconds) * Self.framesPerSecond
        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
            guard let pool = adaptor.pixelBufferPool else {
                throw StillImageError.writingFailed(url)
            }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let buffer else { throw StillImageError.writingFailed(url) }
            draw(frame: frame, into: buffer, width: width, height: height)
            adaptor.append(
                buffer,
                withPresentationTime: CMTime(
                    value: CMTimeValue(frame), timescale: CMTimeScale(Self.framesPerSecond)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw StillImageError.writingFailed(url) }
        return url
    }

    private func draw(frame: Int, into buffer: CVPixelBuffer, width: Int, height: Int) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard
            let context = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
            )
        else { return }
        let phase = Double(frame) / Double(Self.sourceSeconds * Double(Self.framesPerSecond))
        context.setFillColor(CGColor(red: phase, green: 0.3, blue: 1 - phase, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(
            CGRect(
                x: Int(phase * Double(width - 400)), y: height / 3, width: 400, height: height / 3))
    }

    private func makeSilentWav(seconds: Double) throws -> URL {
        let url = directory.appendingPathComponent("music.wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        let frameCount = AVAudioFrameCount(format.sampleRate * seconds)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
        buffer.frameLength = frameCount
        try AVAudioFile(forWriting: url, settings: format.settings).write(from: buffer)
        return url
    }
}
