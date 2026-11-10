import AVFoundation
import AppKit
import XCTest
@testable import Clipsmith

final class KeyframeTests: XCTestCase {
    private func clip(duration: TimeInterval = 10) -> Clip {
        Clip(
            sourceURL: URL(fileURLWithPath: "/tmp/video.mp4"), mediaKind: .video, startInSeconds: 5,
            sourceStartInSeconds: 0, sourceEndInSeconds: duration, sourceDurationInSeconds: 100
        )
    }

    func testWithoutKeyframesTheFixedValuesApply() {
        var base = clip()
        base.scale = 2

        XCTAssertEqual(base.visualState(atClipTime: 3).scale, 2)
        XCTAssertFalse(base.isAnimated)
    }

    func testValuesMoveInAStraightLineBetweenKeyframes() {
        var animated = clip()
        animated.keyframes = [
            Keyframe(timeInSeconds: 0, state: VisualState(offsetX: 0, scale: 1, opacity: 0)),
            Keyframe(timeInSeconds: 4, state: VisualState(offsetX: 0.4, scale: 3, rotationInDegrees: 90, opacity: 1)),
        ]

        let middle = animated.visualState(atClipTime: 2)

        XCTAssertEqual(middle.offsetX, 0.2, accuracy: 1e-9)
        XCTAssertEqual(middle.scale, 2, accuracy: 1e-9)
        XCTAssertEqual(middle.rotationInDegrees, 45, accuracy: 1e-9)
        XCTAssertEqual(middle.opacity, 0.5, accuracy: 1e-9)
    }

    func testValuesHoldBeforeTheFirstAndAfterTheLastKeyframe() {
        var animated = clip()
        animated.keyframes = [
            Keyframe(timeInSeconds: 2, state: VisualState(scale: 2)),
            Keyframe(timeInSeconds: 6, state: VisualState(scale: 4)),
        ]

        XCTAssertEqual(animated.visualState(atClipTime: 0).scale, 2)
        XCTAssertEqual(animated.visualState(atClipTime: 9).scale, 4)
    }

    func testEditingWithKeyframesCreatesOrUpdatesOneAtThatTime() {
        var animated = clip().addingKeyframe(atClipTime: 0)
        XCTAssertEqual(animated.keyframes.count, 1)

        animated = animated.updatingVisual(at: 5 + 4) { $0.scale = 2 }
        XCTAssertEqual(animated.keyframes.map(\.timeInSeconds), [0, 4])
        XCTAssertEqual(animated.keyframes[1].state.scale, 2)

        animated = animated.updatingVisual(at: 5 + 4.02) { $0.scale = 3 }
        XCTAssertEqual(animated.keyframes.count, 2)
        XCTAssertEqual(animated.keyframes[1].state.scale, 3)
    }

    func testEditingWithoutKeyframesChangesTheFixedValuesAndClamps() {
        let edited = clip().updatingVisual(at: 7) {
            $0.scale = 100
            $0.opacity = -1
        }

        XCTAssertEqual(edited.scale, Clip.scaleRange.upperBound)
        XCTAssertEqual(edited.opacity, 0)
        XCTAssertTrue(edited.keyframes.isEmpty)
    }

    func testAddingAKeyframeCapturesWhatIsOnScreen() {
        var animated = clip()
        animated.keyframes = [
            Keyframe(timeInSeconds: 0, state: VisualState(scale: 1)),
            Keyframe(timeInSeconds: 4, state: VisualState(scale: 3)),
        ]

        let added = animated.addingKeyframe(atClipTime: 2)

        XCTAssertEqual(added.keyframes.map(\.timeInSeconds), [0, 2, 4])
        XCTAssertEqual(added.keyframes[1].state.scale, 2, accuracy: 1e-9)
    }

    func testSplittingKeepsTheAnimationContinuous() throws {
        var animated = clip()
        animated.keyframes = [
            Keyframe(timeInSeconds: 0, state: VisualState(scale: 1)),
            Keyframe(timeInSeconds: 8, state: VisualState(scale: 5)),
        ]

        let halves = try XCTUnwrap(animated.split(at: 5 + 4))

        XCTAssertEqual(halves.left.visualState(atClipTime: 4).scale, 3, accuracy: 1e-9)
        XCTAssertEqual(halves.right.visualState(atClipTime: 0).scale, 3, accuracy: 1e-9)
        XCTAssertEqual(halves.right.visualState(atClipTime: 4).scale, 5, accuracy: 1e-9)
        XCTAssertEqual(halves.right.keyframes.map(\.timeInSeconds), [0, 4])
    }

    func testTrimmingTheStartKeepsKeyframesOnTheSamePicture() {
        var animated = clip()
        animated.keyframes = [Keyframe(timeInSeconds: 6, state: VisualState(scale: 2))]

        let trimmed = animated.trimmedLeading(to: 7, notBefore: 0)

        XCTAssertEqual(trimmed.keyframes.first?.timeInSeconds, 4)
    }

    func testProjectEditsGoToTheKeyframeAtThePlayhead() {
        var project = Project(name: "T")
        let main = project.track(withRole: .main)!.id
        let base = clip()
        project.addClip(base, toTrack: main)
        project.addKeyframe(to: base.id, atTimelineTime: 5)

        project.setTransform(of: base.id, scale: 2, rotationInDegrees: 0, at: 9)

        let updated = project.clip(withID: base.id)!
        XCTAssertEqual(updated.keyframes.map(\.timeInSeconds), [0, 4])
        XCTAssertEqual(updated.scale, 1)
        XCTAssertEqual(updated.keyframes[1].state.scale, 2)
    }

    func testKeyframesAndOpacitySurviveSaving() throws {
        var animated = clip()
        animated.opacity = 0.5
        animated.keyframes = [Keyframe(timeInSeconds: 1, state: VisualState(offsetX: 0.1, opacity: 0.2))]

        let decoded = try JSONDecoder().decode(Clip.self, from: JSONEncoder().encode(animated))

        XCTAssertEqual(decoded, animated)
    }

    func testSamplePointsCoverTheSegmentAndIncludeKeyframes() {
        var animated = clip()
        animated.keyframes = [
            Keyframe(timeInSeconds: 2, state: VisualState(offsetX: 0)),
            Keyframe(timeInSeconds: 4, state: VisualState(offsetX: 1)),
        ]

        let points = LayerAnimation.samplePoints(for: animated, from: 5, to: 15)

        XCTAssertEqual(points.first, 5)
        XCTAssertEqual(points.last, 15)
        XCTAssertTrue(points.contains(7))
        XCTAssertTrue(points.contains(9))
        XCTAssertEqual(points, points.sorted())
    }

    func testTurningAddsSamplesSoRampsStayCloseToTheRealRotation() {
        var animated = clip()
        animated.keyframes = [
            Keyframe(timeInSeconds: 0, state: VisualState(rotationInDegrees: 0)),
            Keyframe(timeInSeconds: 4, state: VisualState(rotationInDegrees: 180)),
        ]

        let points = LayerAnimation.samplePoints(for: animated, from: 5, to: 9)

        XCTAssertGreaterThanOrEqual(points.count, 18)
    }

    func testOpacityKeyframesFadeTheRenderedFrame() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("white.png")
        try Self.solidWhitePNG().write(to: url)
        var project = Project(name: "T")
        var still = Clip(sourceURL: url, mediaKind: .image, startInSeconds: 0, sourceStartInSeconds: 0, sourceEndInSeconds: 4)
        still.keyframes = [
            Keyframe(timeInSeconds: 0, state: VisualState(opacity: 0)),
            Keyframe(timeInSeconds: 4, state: VisualState(opacity: 1)),
        ]
        project.addClip(still, toTrack: project.track(withRole: .main)!.id)
        let builder = CompositionBuilder(stillImages: StillImageVideoWriter(directory: directory.appendingPathComponent("stills")))

        let built = try await builder.build(from: project)
        let generator = AVAssetImageGenerator(asset: built.composition)
        generator.videoComposition = built.videoComposition
        let early = try await Self.brightness(of: generator.image(at: 0.4.cmTime).image)
        let late = try await Self.brightness(of: generator.image(at: 3.6.cmTime).image)

        XCTAssertLessThan(early, 0.3)
        XCTAssertGreaterThan(late, 0.7)
    }

    private static func solidWhitePNG() throws -> Data {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 36, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 64, height: 36).fill()
        NSGraphicsContext.restoreGraphicsState()
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }

    /// Average brightness (0 to 1) of the pixel at the middle of the frame.
    static func brightness(of image: CGImage) throws -> Double {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: -image.width / 2, y: -image.height / 2, width: image.width, height: image.height))
        return (Double(pixel[0]) + Double(pixel[1]) + Double(pixel[2])) / (3 * 255)
    }
}
