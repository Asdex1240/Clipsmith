import XCTest

@testable import Clipsmith

final class HighlightTests: XCTestCase {
    private var project: Project!
    private var mainID: Track.ID { project.track(withRole: .main)!.id }
    private var textID: Track.ID { project.track(withRole: .text)!.id }
    private var audioID: Track.ID { project.track(withRole: .audio)!.id }

    override func setUp() {
        project = Project(name: "Vlog")
    }

    private func highlight(
        _ start: TimeInterval, _ end: TimeInterval, framing: Double = 0
    ) -> Highlight {
        Highlight(name: "Clip", startInSeconds: start, endInSeconds: end, framingOffsetX: framing)
    }

    // MARK: Model

    func testHighlightKeepsAMinimumDuration() {
        let result = highlight(5, 5.1)

        XCTAssertEqual(result.durationInSeconds, Highlight.minimumDurationInSeconds)
    }

    func testHighlightNeverStartsBeforeZero() {
        XCTAssertEqual(highlight(-3, 4).startInSeconds, 0)
    }

    func testFramingIsClampedToItsRange() {
        XCTAssertEqual(highlight(0, 4, framing: 3).framingOffsetX, 1)
        XCTAssertEqual(highlight(0, 4, framing: -3).framingOffsetX, -1)
    }

    func testHighlightRoundTripsThroughJSON() throws {
        let original = highlight(2, 9, framing: 0.4)

        let decoded = try JSONDecoder().decode(
            Highlight.self, from: JSONEncoder().encode(original))

        XCTAssertEqual(decoded, original)
    }

    func testProjectWithoutHighlightsDecodesWithAnEmptyList() throws {
        let data = try JSONEncoder().encode(Project(name: "Old"))
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertFalse(json.contains("highlights"))
        XCTAssertTrue(try JSONDecoder().decode(Project.self, from: data).highlights.isEmpty)
    }

    func testProjectKeepsItsHighlightsAfterEncoding() throws {
        project.addHighlight(highlight(1, 6))

        let decoded = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(project))

        XCTAssertEqual(decoded.highlights, project.highlights)
    }

    // MARK: Editing

    func testHighlightsStayOrderedByStart() {
        project.addHighlight(highlight(20, 30))
        project.addHighlight(highlight(5, 10))

        XCTAssertEqual(project.highlights.map(\.startInSeconds), [5, 20])
    }

    func testRenameTrimsTheName() {
        let id = project.addHighlight(highlight(0, 4))

        project.renameHighlight(id, to: "  Intro \n")

        XCTAssertEqual(project.highlight(withID: id)?.name, "Intro")
    }

    func testRemoveDeletesOnlyThatHighlight() {
        let first = project.addHighlight(highlight(0, 4))
        let second = project.addHighlight(highlight(10, 14))

        project.removeHighlight(first)

        XCTAssertEqual(project.highlights.map(\.id), [second])
    }

    func testChangingTheRangeKeepsNameAndFraming() {
        let id = project.addHighlight(highlight(0, 4, framing: 0.5))

        project.setHighlightRange(id, start: 2, end: 9)

        let changed = project.highlight(withID: id)
        XCTAssertEqual(changed?.startInSeconds, 2)
        XCTAssertEqual(changed?.endInSeconds, 9)
        XCTAssertEqual(changed?.framingOffsetX, 0.5)
    }

    // MARK: Extracting

    func testExtractedProjectIsVerticalAndHasNoHighlights() {
        project.addHighlight(highlight(0, 4))

        let result = project.extracting(project.highlights[0])

        XCTAssertEqual(result.canvas, .portrait)
        XCTAssertFalse(result.autoFitCanvas)
        XCTAssertTrue(result.highlights.isEmpty)
        XCTAssertEqual(result.name, "Clip")
    }

    func testExtractingDoesNotChangeTheOriginalProject() {
        project.addClip(TestClips.video(start: 0, sourceEnd: 20), toTrack: mainID)
        let before = project!
        let range = highlight(5, 10)

        _ = project.extracting(range)

        XCTAssertEqual(project, before)
    }

    func testClipsAreCutAtTheBordersAndShiftedToZero() throws {
        project.addClip(TestClips.video(start: 0, sourceEnd: 20), toTrack: mainID)

        let result = project.extracting(highlight(5, 12))

        let clip = try XCTUnwrap(result.track(withRole: .main)?.clips.first)
        XCTAssertEqual(clip.startInSeconds, 0, accuracy: 1e-9)
        XCTAssertEqual(clip.durationInSeconds, 7, accuracy: 1e-9)
        XCTAssertEqual(clip.sourceStartInSeconds, 5, accuracy: 1e-9)
        XCTAssertEqual(result.durationInSeconds, 7, accuracy: 1e-9)
    }

    func testClipsOutsideTheRangeAreLeftOut() {
        project.addClip(TestClips.video(start: 0, sourceEnd: 4), toTrack: mainID)
        project.addClip(TestClips.video(start: 30, sourceEnd: 34), toTrack: mainID)

        let result = project.extracting(highlight(10, 20))

        XCTAssertTrue(result.tracks.flatMap(\.clips).isEmpty)
    }

    func testSeveralClipsKeepTheirRelativePositions() {
        project.addClip(TestClips.video(start: 0, sourceEnd: 10), toTrack: mainID)
        project.addClip(TestClips.video(start: 10, sourceEnd: 20), toTrack: mainID)

        let result = project.extracting(highlight(6, 16))

        let starts = result.track(withRole: .main)!.clips.map(\.startInSeconds)
        XCTAssertEqual(starts.count, 2)
        XCTAssertEqual(starts[0], 0, accuracy: 1e-9)
        XCTAssertEqual(starts[1], 4, accuracy: 1e-9)
    }

    func testVisualClipsAreFilledAndFramed() throws {
        var clip = TestClips.video(start: 0, sourceEnd: 20)
        clip.offsetY = 0.3
        project.addClip(clip, toTrack: mainID)

        let result = project.extracting(highlight(2, 8, framing: -0.6))

        let framed = try XCTUnwrap(result.track(withRole: .main)?.clips.first)
        XCTAssertEqual(framed.fitMode, .fill)
        XCTAssertEqual(framed.offsetX, -0.6)
        XCTAssertEqual(framed.offsetY, 0)
    }

    func testFramingAlsoReachesKeyframes() throws {
        var clip = TestClips.video(start: 0, sourceEnd: 20)
        clip.keyframes = [
            Keyframe(timeInSeconds: 0, state: VisualState(offsetX: 0.9, scale: 1)),
            Keyframe(timeInSeconds: 20, state: VisualState(offsetX: -0.9, scale: 2)),
        ]
        project.addClip(clip, toTrack: mainID)

        let result = project.extracting(highlight(0, 20, framing: 0.25))

        let frames = try XCTUnwrap(result.track(withRole: .main)?.clips.first?.keyframes)
        XCTAssertTrue(frames.allSatisfy { $0.state.offsetX == 0.25 })
        XCTAssertEqual(frames.map(\.state.scale), [1, 2])
    }

    func testAudioIsCutButNotReframed() throws {
        project.addClip(TestClips.audio(start: 0, duration: 30), toTrack: audioID)

        let result = project.extracting(highlight(10, 20, framing: 0.7))

        let clip = try XCTUnwrap(result.track(withRole: .audio)?.clips.first)
        XCTAssertEqual(clip.durationInSeconds, 10, accuracy: 1e-9)
        XCTAssertEqual(clip.offsetX, 0)
        XCTAssertEqual(clip.fitMode, .fit)
    }

    func testTextOverlappingTheRangeIsCutAndKeepsItsPosition() throws {
        var layer = TextLayer(content: "Hola")
        layer.positionX = 0.3
        let text = Clip(text: layer, startInSeconds: 8, durationInSeconds: 6)
        project.addClip(text, toTrack: textID)

        let result = project.extracting(highlight(10, 20))

        let clip = try XCTUnwrap(result.track(withRole: .text)?.clips.first)
        XCTAssertEqual(clip.startInSeconds, 0, accuracy: 1e-9)
        XCTAssertEqual(clip.durationInSeconds, 4, accuracy: 1e-9)
        XCTAssertEqual(clip.textLayer?.positionX, 0.3)
    }

    func testFadesAtTheCutAreRemovedButTheOnesInsideStay() throws {
        var clip = TestClips.video(start: 0, sourceEnd: 20)
        clip.fadeInDurationInSeconds = 2
        clip.fadeOutDurationInSeconds = 2
        project.addClip(clip, toTrack: mainID)

        let middle = project.extracting(highlight(5, 10))
        let whole = project.extracting(highlight(0, 20))

        let cut = try XCTUnwrap(middle.track(withRole: .main)?.clips.first)
        XCTAssertEqual(cut.fadeInDurationInSeconds, 0)
        XCTAssertEqual(cut.fadeOutDurationInSeconds, 0)
        let kept = try XCTUnwrap(whole.track(withRole: .main)?.clips.first)
        XCTAssertEqual(kept.fadeInDurationInSeconds, 2)
        XCTAssertEqual(kept.fadeOutDurationInSeconds, 2)
    }

    func testTransitionLosesItsPartnerWhenTheRangeStartsInsideTheSecondClip() throws {
        project.addClip(TestClips.video(start: 0, sourceEnd: 10), toTrack: mainID)
        var second = TestClips.video(start: 10, sourceEnd: 20)
        second.transition = ClipTransition(kind: .dissolve, durationInSeconds: 1)
        project.addClip(second, toTrack: mainID)

        let result = project.extracting(highlight(12, 18))

        let clip = try XCTUnwrap(result.track(withRole: .main)?.clips.first)
        XCTAssertNil(clip.transition)
    }

    func testTransitionBetweenTwoClipsInsideTheRangeIsKept() throws {
        project.addClip(TestClips.video(start: 0, sourceEnd: 10), toTrack: mainID)
        var second = TestClips.video(start: 10, sourceEnd: 20)
        second.transition = ClipTransition(kind: .dissolve, durationInSeconds: 1)
        project.addClip(second, toTrack: mainID)

        let result = project.extracting(highlight(4, 16))

        let clips = try XCTUnwrap(result.track(withRole: .main)?.clips)
        XCTAssertNotNil(clips.last?.transition)
    }

    func testMarkersInsideTheRangeAreKeptAndShifted() {
        project.markers = [
            Marker(timeInSeconds: 3), Marker(timeInSeconds: 12), Marker(timeInSeconds: 40),
        ]

        let result = project.extracting(highlight(10, 20))

        XCTAssertEqual(result.markers.map(\.timeInSeconds), [2])
    }

    func testClipThatEndsRightAtTheStartIsLeftOut() {
        project.addClip(TestClips.video(start: 0, sourceEnd: 10), toTrack: mainID)

        let result = project.extracting(highlight(10, 15))

        XCTAssertTrue(result.tracks.flatMap(\.clips).isEmpty)
    }

    func testSpeedChangedClipsAreCutInTimelineTime() throws {
        var clip = TestClips.video(start: 0, sourceEnd: 20)
        clip.speed = 2
        project.addClip(clip, toTrack: mainID)

        let result = project.extracting(highlight(2, 6))

        let cut = try XCTUnwrap(result.track(withRole: .main)?.clips.first)
        XCTAssertEqual(cut.durationInSeconds, 4, accuracy: 1e-9)
        XCTAssertEqual(cut.sourceStartInSeconds, 4, accuracy: 1e-9)
    }
}
