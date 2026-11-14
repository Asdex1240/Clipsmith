import AVFoundation
import AppKit
import XCTest

@testable import Clipsmith

final class StabilizationAnalyzerTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "stab-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func noiseImage(width: Int, height: Int) throws -> CGImage {
        var generator = SystemRandomNumberGenerator()
        var bytes = (0..<(width * height)).map { _ in UInt8.random(in: 0...255, using: &generator) }
        let context = try XCTUnwrap(
            CGContext(
                data: &bytes, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue))
        return try XCTUnwrap(context.makeImage())
    }

    private func makeMovingVideo(
        stepX: Int, stepY: Int, frames: Int = 24, swayAmplitude: Double = 0,
        framesPerSecond: Int32 = 8
    ) async throws -> URL {
        let width = 640
        let height = 360
        let margin = 200
        let texture = try noiseImage(width: width + 2 * margin, height: height + 2 * margin)
        let url = directory.appendingPathComponent(
            "moving-\(stepX)-\(stepY)-\(swayAmplitude).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: AVAssetWriterInput(
                mediaType: .video,
                outputSettings: [
                    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width,
                    AVVideoHeightKey: height,
                ]),
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
            ])
        writer.add(input.assetWriterInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        var offsetX = 0
        for index in 0..<frames {
            if swayAmplitude > 0 {
                let seconds = Double(index) / Double(framesPerSecond)
                offsetX = Int((swayAmplitude * sin(2 * .pi * 1.5 * seconds)).rounded())
            } else {
                offsetX = stepX * index
            }
            while !input.assetWriterInput.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
            let pixels = try XCTUnwrap(buffer)
            CVPixelBufferLockBaseAddress(pixels, [])
            let context = try XCTUnwrap(
                CGContext(
                    data: CVPixelBufferGetBaseAddress(pixels), width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixels),
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                        | CGBitmapInfo.byteOrder32Little.rawValue))
            context.draw(
                texture,
                in: CGRect(
                    x: -margin + offsetX, y: -margin - stepY * index,
                    width: width + 2 * margin, height: height + 2 * margin))
            CVPixelBufferUnlockBaseAddress(pixels, [])
            input.append(
                pixels,
                withPresentationTime: CMTime(value: Int64(index), timescale: framesPerSecond))
        }
        input.assetWriterInput.markAsFinished()
        await writer.finishWriting()
        return url
    }

    private func averageMotion(of url: URL) async throws -> (dx: Double, dy: Double) {
        let result = await VisionStabilizationAnalyzer().motion(in: url, sourceRange: 0...2.5) {
            _ in
        }
        let samples = try XCTUnwrap(result)
        let moving = samples.dropFirst()
        let count = Double(moving.count)
        return (moving.reduce(0) { $0 + $1.dx } / count, moving.reduce(0) { $0 + $1.dy } / count)
    }

    func testContentMovingRightGivesPositiveHorizontalMotion() async throws {
        let video = try await makeMovingVideo(stepX: 4, stepY: 0)

        let motion = try await averageMotion(of: video)

        XCTAssertEqual(motion.dx, 4.0 / 640, accuracy: 0.002)
        XCTAssertEqual(motion.dy, 0, accuracy: 0.002)
    }

    func testContentMovingDownGivesPositiveVerticalMotion() async throws {
        let video = try await makeMovingVideo(stepX: 0, stepY: 3)

        let motion = try await averageMotion(of: video)

        XCTAssertEqual(motion.dy, 3.0 / 360, accuracy: 0.002)
        XCTAssertEqual(motion.dx, 0, accuracy: 0.002)
    }

    private func roughness(of url: URL) async throws -> Double {
        let result = await VisionStabilizationAnalyzer().motion(in: url, sourceRange: 0...2.5) {
            _ in
        }
        let moving = try XCTUnwrap(result).dropFirst()
        return moving.reduce(0) { $0 + abs($1.dx) } / Double(moving.count)
    }

    func testStabilizingAShakyShotMakesTheExportSteadier() async throws {
        let shaky = try await makeMovingVideo(
            stepX: 0, stepY: 0, frames: 90, swayAmplitude: 12, framesPerSecond: 30)
        let analysis = await VisionStabilizationAnalyzer().motion(
            in: shaky, sourceRange: 0...2.9
        ) { _ in }
        let samples = try XCTUnwrap(analysis)
        let plan = try XCTUnwrap(StabilizationPlanner.plan(from: samples, strength: .strong))
        let stills = StillImageVideoWriter(directory: directory.appendingPathComponent("stills"))
        let exporter = ProjectExporter(builder: CompositionBuilder(stillImages: stills))

        func export(_ stabilization: Stabilization?, as name: String) async throws -> URL {
            var project = Project(name: "Shaky")
            let clip = Clip(
                sourceURL: shaky, mediaKind: .video, startInSeconds: 0, sourceStartInSeconds: 0,
                sourceEndInSeconds: 2.9, sourceDurationInSeconds: 3)
            project.addClip(clip, toTrack: project.track(withRole: .main)!.id)
            project.setStabilization(of: clip.id, to: stabilization)
            let destination = directory.appendingPathComponent(name)
            try await exporter.export(
                project, with: ExportPreset.landscape720.settings, to: destination
            ) { _ in }
            return destination
        }

        let plainFile = try await export(nil, as: "plain.mp4")
        let steadyFile = try await export(plan, as: "steady.mp4")
        let before = try await roughness(of: plainFile)
        let after = try await roughness(of: steadyFile)

        XCTAssertGreaterThan(before, 0.008)
        XCTAssertLessThan(after, before * 0.6, "before \(before), after \(after)")
    }

    func testAStillShotHasNoMotion() async throws {
        let video = try await makeMovingVideo(stepX: 0, stepY: 0)

        let motion = try await averageMotion(of: video)

        XCTAssertEqual(motion.dx, 0, accuracy: 0.001)
        XCTAssertEqual(motion.dy, 0, accuracy: 0.001)
    }

    func testSampleTimesCoverTheRangeAtTheAnalysisRate() {
        let times = VisionStabilizationAnalyzer.sampleTimes(in: 2...4)

        XCTAssertEqual(times.first, 2)
        XCTAssertEqual(times.count, 17)
        XCTAssertLessThanOrEqual(try XCTUnwrap(times.last), 4)
    }

    func testAMissingFileGivesNoMotion() async {
        let result = await VisionStabilizationAnalyzer().motion(
            in: directory.appendingPathComponent("none.mov"), sourceRange: 0...3
        ) { _ in }

        XCTAssertNil(result)
    }
}
