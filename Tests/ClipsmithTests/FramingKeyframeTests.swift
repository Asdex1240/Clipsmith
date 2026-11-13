import XCTest

@testable import Clipsmith

final class FramingKeyframeTests: XCTestCase {
    private var project = Project(name: "Vlog")
    private var main: Track.ID { project.track(withRole: .main)!.id }

    override func setUp() {
        project = Project(name: "Vlog")
        project.addClip(TestClips.video(start: 0, sourceEnd: 60), toTrack: main)
    }

    private func highlight(_ start: TimeInterval = 10, _ end: TimeInterval = 20) -> Highlight.ID {
        project.addHighlight(Highlight(name: "Clip", startInSeconds: start, endInSeconds: end))
    }

    private func frames(_ id: Highlight.ID) -> [FramingKeyframe] {
        project.highlight(withID: id)?.framingKeyframes ?? []
    }

    // MARK: Curve

    func testWithoutKeyframesTheCurveIsTheStaticOffset() {
        let curve = FramingCurve(staticOffsetX: 0.3, keyframes: [])

        XCTAssertEqual(curve.offsetX(at: 4), 0.3)
        XCTAssertFalse(curve.isAnimated)
    }

    func testTheCurveHoldsTheEndValuesAndInterpolatesBetween() {
        let curve = FramingCurve(
            staticOffsetX: 0,
            keyframes: [
                FramingKeyframe(timeInSeconds: 2, offsetX: -0.5),
                FramingKeyframe(timeInSeconds: 6, offsetX: 0.5),
            ])

        XCTAssertEqual(curve.offsetX(at: 0), -0.5)
        XCTAssertEqual(curve.offsetX(at: 4), 0, accuracy: 1e-9)
        XCTAssertEqual(curve.offsetX(at: 9), 0.5)
    }

    func testEasingShapesTheSegmentFromItsKeyframe() {
        let curve = FramingCurve(
            staticOffsetX: 0,
            keyframes: [
                FramingKeyframe(timeInSeconds: 0, offsetX: 0, easing: .easeIn),
                FramingKeyframe(timeInSeconds: 4, offsetX: 1),
            ])

        XCTAssertLessThan(curve.offsetX(at: 2), 0.5)
    }

    func testKeyframesAreSortedWhateverTheOrderTheyArrive() {
        let curve = FramingCurve(
            staticOffsetX: 0,
            keyframes: [
                FramingKeyframe(timeInSeconds: 6, offsetX: 1),
                FramingKeyframe(timeInSeconds: 2, offsetX: 0),
            ])

        XCTAssertEqual(curve.keyframes.map(\.timeInSeconds), [2, 6])
    }

    func testEasedSegmentsGetExtraSamples() {
        let linear = FramingCurve(
            staticOffsetX: 0,
            keyframes: [
                FramingKeyframe(timeInSeconds: 0, offsetX: 0),
                FramingKeyframe(timeInSeconds: 4, offsetX: 1),
            ])
        let eased = FramingCurve(
            staticOffsetX: 0,
            keyframes: [
                FramingKeyframe(timeInSeconds: 0, offsetX: 0, easing: .easeInOut),
                FramingKeyframe(timeInSeconds: 4, offsetX: 1),
            ])

        XCTAssertTrue(linear.sampleTimes(from: 0, to: 4).isEmpty)
        XCTAssertEqual(
            eased.sampleTimes(from: 0, to: 4).count, FramingCurve.subdivisionsPerEasedSegment - 1)
    }

    // MARK: Model

    func testKeyframeValuesAreClamped() {
        XCTAssertEqual(FramingKeyframe(timeInSeconds: -3, offsetX: 4).timeInSeconds, 0)
        XCTAssertEqual(FramingKeyframe(timeInSeconds: 1, offsetX: 4).offsetX, 1)
    }

    func testKeyframesRoundTripThroughJSONAndStayOutOfOldFiles() throws {
        let plain = Highlight(name: "A", startInSeconds: 0, endInSeconds: 5)
        XCTAssertFalse(
            try XCTUnwrap(String(data: JSONEncoder().encode(plain), encoding: .utf8))
                .contains("framingKeyframes"))

        let animated = Highlight(
            name: "B", startInSeconds: 0, endInSeconds: 5,
            framingKeyframes: [FramingKeyframe(timeInSeconds: 1, offsetX: 0.4, easing: .easeOut)])
        let decoded = try JSONDecoder().decode(
            Highlight.self, from: JSONEncoder().encode(animated))

        XCTAssertEqual(decoded, animated)
    }

    func testKeyframesBeyondTheHighlightAreDroppedWhenBuilt() {
        let result = Highlight(
            name: "A", startInSeconds: 0, endInSeconds: 5,
            framingKeyframes: [
                FramingKeyframe(timeInSeconds: 1, offsetX: 0),
                FramingKeyframe(timeInSeconds: 99, offsetX: 1),
            ])

        XCTAssertEqual(result.framingKeyframes.map(\.timeInSeconds), [1])
    }

    // MARK: Editing

    func testTheFirstKeyframeAlsoPinsTheStartToTheStaticFraming() throws {
        let id = highlight()
        project.setHighlightFraming(id, offsetX: 0.2)

        project.addFramingKeyframe(to: id, at: 5, offsetX: -0.6)

        XCTAssertEqual(frames(id).map(\.timeInSeconds), [0, 5])
        XCTAssertEqual(frames(id).map(\.offsetX), [0.2, -0.6])
    }

    func testANewKeyframeDefaultsToTheCurrentCurveValue() {
        let id = highlight()
        project.addFramingKeyframe(to: id, at: 0, offsetX: 0)
        project.addFramingKeyframe(to: id, at: 8, offsetX: 1)

        project.addFramingKeyframe(to: id, at: 4)

        XCTAssertEqual(frames(id).map(\.offsetX)[1], 0.5, accuracy: 1e-9)
    }

    func testAddingTwiceAtTheSameTimeUpdatesTheKeyframe() {
        let id = highlight()
        project.addFramingKeyframe(to: id, at: 3, offsetX: 0.1)

        project.addFramingKeyframe(to: id, at: 3.01, offsetX: 0.9)

        XCTAssertEqual(frames(id).filter { abs($0.timeInSeconds - 3) < 0.05 }.count, 1)
        XCTAssertEqual(frames(id).last?.offsetX, 0.9)
    }

    func testKeyframesOutsideTheHighlightAreRejected() {
        let id = highlight()

        XCTAssertNil(project.addFramingKeyframe(to: id, at: -1))
        XCTAssertNil(project.addFramingKeyframe(to: id, at: 11))
        XCTAssertTrue(frames(id).isEmpty)
    }

    func testChangingRemovingAndClearing() throws {
        let id = highlight()
        let first = try XCTUnwrap(project.addFramingKeyframe(to: id, at: 0, offsetX: 0))
        let second = try XCTUnwrap(project.addFramingKeyframe(to: id, at: 5, offsetX: 0.5))

        project.setFramingKeyframeOffset(second, in: id, to: -0.3)
        project.setFramingKeyframeEasing(second, in: id, to: .easeOut)
        XCTAssertEqual(frames(id).last?.offsetX, -0.3)
        XCTAssertEqual(frames(id).last?.easing, .easeOut)

        project.removeFramingKeyframe(first, from: id)
        XCTAssertEqual(frames(id).count, 1)

        project.clearFramingKeyframes(of: id)
        XCTAssertTrue(frames(id).isEmpty)
    }

    func testMovingTheStartKeepsTheKeyframesWhereTheyWereInTheVideo() {
        let id = highlight(10, 20)
        project.addFramingKeyframe(to: id, at: 5, offsetX: 0.4)

        project.setHighlightRange(id, start: 8, end: 20)

        XCTAssertEqual(frames(id).map(\.timeInSeconds), [2, 7])
    }

    // MARK: Extraction

    func testExtractionAnimatesTheOffsetAlongTheKeyframes() throws {
        let id = highlight(10, 20)
        project.addFramingKeyframe(to: id, at: 0, offsetX: -1)
        project.addFramingKeyframe(to: id, at: 10, offsetX: 1)

        let result = project.extracting(try XCTUnwrap(project.highlight(withID: id)))

        let clip = try XCTUnwrap(result.track(withRole: .main)?.clips.first)
        XCTAssertEqual(clip.fitMode, .fill)
        XCTAssertEqual(clip.visualState(atClipTime: 0).offsetX, -1, accuracy: 1e-9)
        XCTAssertEqual(clip.visualState(atClipTime: 5).offsetX, 0, accuracy: 1e-9)
        XCTAssertEqual(clip.visualState(atClipTime: 10).offsetX, 1, accuracy: 1e-9)
    }

    func testAClipThatStartsLaterInTheHighlightFollowsTheSameCurve() throws {
        var second = TestClips.video(start: 14, sourceEnd: 60)
        second.id = UUID()
        project = Project(name: "Vlog")
        project.addClip(TestClips.video(start: 0, sourceEnd: 14), toTrack: main)
        project.addClip(second, toTrack: main)
        let id = highlight(10, 24)
        project.addFramingKeyframe(to: id, at: 0, offsetX: -1)
        project.addFramingKeyframe(to: id, at: 14, offsetX: 1)

        let result = project.extracting(try XCTUnwrap(project.highlight(withID: id)))

        let clips = try XCTUnwrap(result.track(withRole: .main)?.clips)
        XCTAssertEqual(clips.count, 2)
        let late = try XCTUnwrap(clips.last)
        XCTAssertEqual(late.startInSeconds, 4, accuracy: 1e-6)
        XCTAssertEqual(late.visualState(atClipTime: 0).offsetX, curveValue(at: 4), accuracy: 1e-6)
    }

    private func curveValue(at time: TimeInterval) -> Double {
        -1 + 2 * time / 14
    }

    func testOtherAnimatedPropertiesSurviveTheFramingAnimation() throws {
        var animated = TestClips.video(start: 0, sourceEnd: 60)
        animated.keyframes = [
            Keyframe(timeInSeconds: 0, state: VisualState(scale: 1)),
            Keyframe(timeInSeconds: 60, state: VisualState(scale: 2)),
        ]
        project = Project(name: "Vlog")
        project.addClip(animated, toTrack: main)
        let id = highlight(10, 20)
        project.addFramingKeyframe(to: id, at: 0, offsetX: 0.2)
        project.addFramingKeyframe(to: id, at: 10, offsetX: 0.8)

        let result = project.extracting(try XCTUnwrap(project.highlight(withID: id)))

        let clip = try XCTUnwrap(result.track(withRole: .main)?.clips.first)
        XCTAssertEqual(clip.visualState(atClipTime: 0).scale, 1 + 10.0 / 60, accuracy: 1e-6)
        XCTAssertEqual(clip.visualState(atClipTime: 5).offsetX, 0.5, accuracy: 1e-6)
    }

    func testBlurIgnoresTheAnimatedFraming() throws {
        let id = highlight(10, 20)
        project.addFramingKeyframe(to: id, at: 0, offsetX: 0.9)
        project.setHighlightFitMode(id, to: .blur)

        let result = project.extracting(try XCTUnwrap(project.highlight(withID: id)))

        let clip = try XCTUnwrap(result.track(withRole: .main)?.clips.first)
        XCTAssertEqual(clip.fitMode, .blur)
        XCTAssertEqual(clip.offsetX, 0)
    }

    func testWithoutKeyframesTheStaticFramingStillApplies() throws {
        let id = highlight(10, 20)
        project.setHighlightFraming(id, offsetX: 0.4)

        let result = project.extracting(try XCTUnwrap(project.highlight(withID: id)))

        XCTAssertEqual(result.track(withRole: .main)?.clips.first?.offsetX, 0.4)
    }

    // MARK: Face tracking

    func testFaceTrackingTurnsCentersIntoSmoothedKeyframes() throws {
        let frames = try XCTUnwrap(
            FaceFraming.keyframes(
                faceCenters: [0.5, 0.5, 0.8, 0.5, 0.5], at: [1, 2, 3, 4, 5],
                sourceAspect: 16.0 / 9, canvasAspect: 9.0 / 16))

        XCTAssertEqual(frames.map(\.timeInSeconds), [1, 2, 3, 4, 5])
        XCTAssertEqual(frames[0].offsetX, 0, accuracy: 1e-9)
        let peak = frames.map { abs($0.offsetX) }.max() ?? 0
        let raw = abs(-(0.8 - 0.5) * (16.0 / 9) / (9.0 / 16))
        XCTAssertLessThan(peak, min(raw, 1))
    }

    func testFaceTrackingNeedsAWideSourceAndEnoughSamples() {
        XCTAssertNil(
            FaceFraming.keyframes(
                faceCenters: [0.5], at: [1], sourceAspect: 16.0 / 9, canvasAspect: 9.0 / 16))
        XCTAssertNil(
            FaceFraming.keyframes(
                faceCenters: [0.4, 0.6], at: [1, 2], sourceAspect: 9.0 / 16,
                canvasAspect: 9.0 / 16))
        XCTAssertNil(
            FaceFraming.keyframes(
                faceCenters: [0.4, 0.6], at: [1], sourceAspect: 16.0 / 9, canvasAspect: 9.0 / 16))
    }
}

@MainActor
final class FramingKeyframeStoreTests: XCTestCase {
    private var store = ProjectStore(project: Project(name: "Vlog"))
    private var highlightID: Highlight.ID!

    override func setUp() async throws {
        store = ProjectStore(project: Project(name: "Vlog"))
        let main = store.project.track(withRole: .main)!.id
        store.addMedia(TestClips.mediaItem(duration: 60), toTrack: main, at: 0)
        highlightID = try XCTUnwrap(store.addHighlight(from: 10, to: 20))
    }

    func testAddingAtThePlayheadUsesTimeInsideTheHighlight() throws {
        store.followPlayback(at: 14)

        let id = try XCTUnwrap(store.addFramingKeyframeAtPlayhead(to: highlightID))

        let frames = store.project.highlight(withID: highlightID)?.framingKeyframes
        XCTAssertEqual(frames?.last?.id, id)
        XCTAssertEqual(frames?.last?.timeInSeconds ?? 0, 4, accuracy: 1e-9)
    }

    func testAddingOutsideTheHighlightDoesNothing() {
        store.followPlayback(at: 40)

        XCTAssertNil(store.addFramingKeyframeAtPlayhead(to: highlightID))
        XCTAssertFalse(
            store.canUndo
                && store.project.highlight(withID: highlightID)?.framingKeyframes.isEmpty == false)
    }

    func testDraggingAKeyframeSliderIsOneUndoStep() throws {
        store.followPlayback(at: 12)
        let frame = try XCTUnwrap(store.addFramingKeyframeAtPlayhead(to: highlightID))

        for step in 1...5 {
            store.setFramingKeyframeOffset(frame, in: highlightID, to: Double(step) / 10)
        }
        store.undo()

        let value = store.project.highlight(withID: highlightID)?.framingKeyframes.last?.offsetX
        XCTAssertEqual(value, 0.0)
    }

    func testFaceTrackingFillsTheHighlightWithKeyframes() async throws {
        let locator = TrackingLocator()

        let tracked = await store.trackFaceInHighlight(highlightID, using: locator)

        XCTAssertTrue(tracked)
        let frames = store.project.highlight(withID: highlightID)?.framingKeyframes ?? []
        XCTAssertGreaterThanOrEqual(frames.count, 4)
        XCTAssertTrue(frames.allSatisfy { $0.timeInSeconds >= 0 && $0.timeInSeconds <= 10 })
    }

    func testFaceTrackingFailsQuietlyWithoutFaces() async throws {
        let tracked = await store.trackFaceInHighlight(
            highlightID, using: TrackingLocator(centers: []))

        XCTAssertFalse(tracked)
        XCTAssertTrue(
            store.project.highlight(withID: highlightID)?.framingKeyframes.isEmpty ?? false)
    }
}

private struct TrackingLocator: FaceLocating {
    var centers: [Double]?

    func faceSample(in url: URL, at times: [TimeInterval]) async -> FaceSample? {
        let found = centers ?? times.indices.map { 0.3 + 0.05 * Double($0 % 5) }
        let kept = Array(times.prefix(found.count))
        return FaceSample(centers: found, sourceAspect: 16.0 / 9, times: kept)
    }
}
