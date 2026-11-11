import AVFoundation
import AppKit
import XCTest
@testable import Clipsmith

final class TransitionTests: XCTestCase {
    private var directory: URL!
    private var project = Project(name: "T")

    private var mainTrackID: Track.ID { project.track(withRole: .main)!.id }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        project = Project(name: "T")
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    // MARK: Model

    func testDissolveFadesTheOutgoingClipOnly() {
        XCTAssertEqual(TransitionKind.dissolve.opacity(at: 0).outgoing, 1)
        XCTAssertEqual(TransitionKind.dissolve.opacity(at: 0.5).outgoing, 0.5)
        XCTAssertEqual(TransitionKind.dissolve.opacity(at: 0.5).incoming, 1)
    }

    func testFadeThroughBlackIsDarkestInTheMiddle() {
        let middle = TransitionKind.fadeBlack.opacity(at: 0.5)

        XCTAssertEqual(middle.outgoing, 0)
        XCTAssertEqual(middle.incoming, 0)
        XCTAssertEqual(TransitionKind.fadeBlack.opacity(at: 1).incoming, 1)
        XCTAssertEqual(TransitionKind.fadeBlack.breakpoints, [0.5])
    }

    func testSlidesPushTheClipsAcrossTheCanvas() {
        XCTAssertEqual(TransitionKind.slideLeft.shift(at: 0).incoming, 1)
        XCTAssertEqual(TransitionKind.slideLeft.shift(at: 1).outgoing, -1)
        XCTAssertEqual(TransitionKind.slideRight.shift(at: 0.25).incoming, -0.75)
    }

    func testDurationIsClamped() {
        XCTAssertEqual(
            ClipTransition(kind: .dissolve).settingDuration(99).durationInSeconds,
            ClipTransition.durationRange.upperBound)
        XCTAssertEqual(
            ClipTransition(kind: .dissolve).settingDuration(0).durationInSeconds,
            ClipTransition.durationRange.lowerBound)
    }

    func testTransitionSurvivesSavingAndSplittingKeepsItOnTheFirstHalfOnly() throws {
        var clip = TestClips.video(start: 0, sourceEnd: 10)
        clip.transition = ClipTransition(kind: .slideLeft, durationInSeconds: 2)

        let decoded = try JSONDecoder().decode(Clip.self, from: JSONEncoder().encode(clip))
        let halves = try XCTUnwrap(clip.split(at: 4))

        XCTAssertEqual(decoded.transition, clip.transition)
        XCTAssertEqual(halves.left.transition, clip.transition)
        XCTAssertNil(halves.right.transition)
    }

    func testOnlyTouchingClipsOnTheSameVisualTrackCanTransition() {
        let first = TestClips.video(start: 0, sourceEnd: 5)
        let touching = TestClips.video(start: 5, sourceEnd: 5)
        let apart = TestClips.video(start: 12, sourceEnd: 5)
        project.addClip(first, toTrack: mainTrackID)
        project.addClip(touching, toTrack: mainTrackID)
        project.addClip(apart, toTrack: mainTrackID)

        XCTAssertEqual(project.clipBeforeAndTouching(touching.id)?.id, first.id)
        XCTAssertNil(project.clipBeforeAndTouching(apart.id))
        XCTAssertNil(project.clipBeforeAndTouching(first.id))
    }

    // MARK: Planner

    func testPlannerAddsAWindowSegmentWithTheTransition() {
        let first = TestClips.video(start: 0, sourceEnd: 5)
        var second = TestClips.video(start: 5, sourceEnd: 5)
        second.transition = ClipTransition(kind: .dissolve, durationInSeconds: 2)
        project.addClip(first, toTrack: mainTrackID)
        project.addClip(second, toTrack: mainTrackID)

        let segments = CompositionPlanner.segments(for: project)

        XCTAssertEqual(segments.map(\.startInSeconds), [0, 5, 7])
        XCTAssertEqual(segments[1].transitions.map(\.outgoingClipID), [first.id])
        XCTAssertEqual(segments[1].transitions.first?.windowEnd, 7)
        XCTAssertTrue(segments[0].transitions.isEmpty)
        XCTAssertTrue(segments[2].transitions.isEmpty)
    }

    func testPlannerIgnoresTransitionsWithoutATouchingClipAndClampsLongOnes() {
        var alone = TestClips.video(start: 0, sourceEnd: 5)
        alone.transition = ClipTransition(kind: .dissolve)
        project.addClip(alone, toTrack: mainTrackID)
        XCTAssertTrue(
            CompositionPlanner.segments(for: project).allSatisfy { $0.transitions.isEmpty })

        var second = TestClips.video(start: 5, sourceEnd: 0.5)
        second.transition = ClipTransition(kind: .dissolve, durationInSeconds: 3)
        project.addClip(second, toTrack: mainTrackID)

        let window = CompositionPlanner.segments(for: project).flatMap(\.transitions).first
        XCTAssertEqual(window?.windowEnd ?? 0, 5.5, accuracy: 1e-9)
    }

    // MARK: Rendering

    private func solidPNG(_ color: NSColor, named name: String) throws -> URL {
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

    private func brightness(
        with kind: TransitionKind, at times: [TimeInterval]
    ) async throws -> [Double] {
        let white = try solidPNG(.white, named: "white.png")
        let black = try solidPNG(.black, named: "black.png")
        func still(_ url: URL, start: TimeInterval) -> Clip {
            Clip(
                sourceURL: url, mediaKind: .image, startInSeconds: start, sourceStartInSeconds: 0,
                sourceEndInSeconds: 3)
        }
        var second = still(black, start: 3)
        second.transition = ClipTransition(kind: kind, durationInSeconds: 1)
        project.addClip(still(white, start: 0), toTrack: mainTrackID)
        project.addClip(second, toTrack: mainTrackID)
        let builder = CompositionBuilder(
            stillImages: StillImageVideoWriter(
                directory: directory.appendingPathComponent("stills")))

        let built = try await builder.build(from: project)

        XCTAssertTrue(built.skippedClipIDs.isEmpty)
        XCTAssertEqual(built.durationInSeconds, 6, accuracy: 0.05)
        let generator = AVAssetImageGenerator(asset: built.composition)
        generator.videoComposition = built.videoComposition
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        var values: [Double] = []
        for time in times {
            values.append(
                try KeyframeTests.brightness(of: try await generator.image(at: time.cmTime).image))
        }
        return values
    }

    func testDissolveBlendsTheTwoClips() async throws {
        let values = try await brightness(with: .dissolve, at: [2, 3.5, 5])

        XCTAssertGreaterThan(values[0], 0.9)
        XCTAssertEqual(values[1], 0.5, accuracy: 0.15)
        XCTAssertLessThan(values[2], 0.1)
    }

    func testFadeThroughBlackDipsInTheMiddle() async throws {
        let values = try await brightness(with: .fadeBlack, at: [3.25, 3.5, 3.9])

        XCTAssertGreaterThan(values[0], 0.3)
        XCTAssertLessThan(values[1], 0.1)
        XCTAssertLessThan(values[2], 0.9)
    }

    func testSlideLeftPushesTheFirstClipOut() async throws {
        let values = try await brightness(with: .slideLeft, at: [3.25, 3.75])

        XCTAssertGreaterThan(values[0], 0.9)
        XCTAssertLessThan(values[1], 0.1)
    }
}
