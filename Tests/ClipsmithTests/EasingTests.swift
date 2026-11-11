import AVFoundation
import AppKit
import XCTest
@testable import Clipsmith

final class EasingTests: XCTestCase {
    func testEveryCurveStartsAtZeroAndEndsAtOne() {
        for easing in Easing.allCases {
            XCTAssertEqual(easing.apply(0), 0, accuracy: 1e-9)
            XCTAssertEqual(easing.apply(1), 1, accuracy: 1e-9)
        }
    }

    func testCurvesNeverGoBackwards() {
        for easing in Easing.allCases {
            let values = stride(from: 0.0, through: 1.0, by: 0.05).map(easing.apply)
            XCTAssertEqual(values, values.sorted())
        }
    }

    func testEaseInStartsSlowAndEaseOutEndsSlow() {
        XCTAssertLessThan(Easing.easeIn.apply(0.25), 0.25)
        XCTAssertGreaterThan(Easing.easeOut.apply(0.25), 0.25)
        XCTAssertEqual(Easing.easeInOut.apply(0.5), 0.5, accuracy: 1e-9)
        XCTAssertLessThan(Easing.easeInOut.apply(0.2), 0.2)
        XCTAssertGreaterThan(Easing.easeInOut.apply(0.8), 0.8)
    }

    func testTimeForProgressUndoesTheCurve() {
        for easing in Easing.allCases {
            let time = easing.time(forProgress: 0.5)
            XCTAssertEqual(easing.apply(time), 0.5, accuracy: 1e-6)
        }
    }

    func testKeyframeEasingShapesTheStretchThatLeavesIt() {
        var clip = Clip(
            sourceURL: URL(fileURLWithPath: "/tmp/a.mp4"), mediaKind: .video, startInSeconds: 0,
            sourceStartInSeconds: 0, sourceEndInSeconds: 10, sourceDurationInSeconds: 60
        )
        clip.keyframes = [
            Keyframe(timeInSeconds: 0, state: VisualState(scale: 1), easing: .easeIn),
            Keyframe(timeInSeconds: 4, state: VisualState(scale: 3), easing: .linear),
            Keyframe(timeInSeconds: 8, state: VisualState(scale: 5)),
        ]

        XCTAssertEqual(
            clip.visualState(atClipTime: 1).scale, 1 + 2 * Easing.easeIn.apply(0.25), accuracy: 1e-9
        )
        XCTAssertEqual(clip.visualState(atClipTime: 6).scale, 4, accuracy: 1e-9)
        XCTAssertTrue(clip.eased(from: 1))
        XCTAssertFalse(clip.eased(from: 5))
        XCTAssertFalse(clip.eased(from: 9))
    }

    func testEasedKeyframesGetExtraSamplesForSmoothRamps() {
        var clip = Clip(
            sourceURL: URL(fileURLWithPath: "/tmp/a.mp4"), mediaKind: .video, startInSeconds: 0,
            sourceStartInSeconds: 0, sourceEndInSeconds: 10, sourceDurationInSeconds: 60
        )
        clip.keyframes = [
            Keyframe(timeInSeconds: 0, state: VisualState(offsetX: 0), easing: .easeInOut),
            Keyframe(timeInSeconds: 4, state: VisualState(offsetX: 1)),
        ]
        var plain = clip
        plain.keyframes[0].easing = .linear

        XCTAssertGreaterThan(LayerAnimation.samplePoints(for: clip, from: 0, to: 4).count, 10)
        XCTAssertEqual(LayerAnimation.samplePoints(for: plain, from: 0, to: 4).count, 2)
    }

    func testEasingSurvivesSavingAndOlderFilesAreLinear() throws {
        let frame = Keyframe(timeInSeconds: 1, state: VisualState(), easing: .easeOut)
        let decoded = try JSONDecoder().decode(Keyframe.self, from: JSONEncoder().encode(frame))
        XCTAssertEqual(decoded, frame)

        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(frame)) as? [String: Any])
        json.removeValue(forKey: "easing")
        let legacy = try JSONDecoder().decode(
            Keyframe.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.easing, .linear)

        let transition = ClipTransition(kind: .slideLeft, durationInSeconds: 2, easing: .easeIn)
        XCTAssertEqual(
            try JSONDecoder().decode(ClipTransition.self, from: JSONEncoder().encode(transition)),
            transition)
        XCTAssertEqual(ClipTransition(kind: .dissolve).easing, .easeInOut)
    }

    func testPlannedTransitionProgressFollowsItsEasing() {
        let linear = PlannedTransition(
            outgoingClipID: UUID(), incomingClipID: UUID(), kind: .dissolve, windowStart: 0,
            windowEnd: 2
        )
        var eased = linear
        eased.easing = .easeIn

        XCTAssertEqual(linear.progress(at: 0.5), 0.25, accuracy: 1e-9)
        XCTAssertEqual(eased.progress(at: 0.5), Easing.easeIn.apply(0.25), accuracy: 1e-9)
    }

    func testEasedTransitionBlendsLessAtFirst() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        func png(_ color: NSColor, _ name: String) throws -> URL {
            let bitmap = try XCTUnwrap(
                NSBitmapImageRep(
                    bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 36, bitsPerSample: 8,
                    samplesPerPixel: 4,
                    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
                    bitsPerPixel: 0
                ))
            let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            color.setFill()
            NSRect(x: 0, y: 0, width: 64, height: 36).fill()
            NSGraphicsContext.restoreGraphicsState()
            let url = directory.appendingPathComponent(name)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
            return url
        }
        var project = Project(name: "T")
        let main = project.track(withRole: .main)!.id
        project.addClip(
            Clip(
                sourceURL: try png(.white, "w.png"), mediaKind: .image, startInSeconds: 0,
                sourceStartInSeconds: 0, sourceEndInSeconds: 3), toTrack: main)
        var second = Clip(
            sourceURL: try png(.black, "b.png"), mediaKind: .image, startInSeconds: 3,
            sourceStartInSeconds: 0, sourceEndInSeconds: 3)
        second.transition = ClipTransition(kind: .dissolve, durationInSeconds: 1, easing: .easeIn)
        project.addClip(second, toTrack: main)
        let builder = CompositionBuilder(
            stillImages: StillImageVideoWriter(directory: directory.appendingPathComponent("s")))

        let built = try await builder.build(from: project)
        let generator = AVAssetImageGenerator(asset: built.composition)
        generator.videoComposition = built.videoComposition
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let quarter = try KeyframeTests.brightness(
            of: try await generator.image(at: 3.25.cmTime).image)

        XCTAssertGreaterThan(quarter, 0.9)
    }
}
