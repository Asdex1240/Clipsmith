import XCTest
@testable import Clipsmith

final class CompositionPlannerTests: XCTestCase {
    private var project = Project(name: "Test")

    private var mainTrackID: Track.ID { project.track(withRole: .main)!.id }
    private var brollTrackID: Track.ID { project.track(withRole: .broll)!.id }
    private var audioTrackID: Track.ID { project.track(withRole: .audio)!.id }

    override func setUp() {
        project = Project(name: "Test")
    }

    func testEmptyProjectHasNoSegments() {
        XCTAssertTrue(CompositionPlanner.segments(for: project).isEmpty)
    }

    func testChainedClipsProduceOneSegmentEach() {
        let first = TestClips.video(start: 0, sourceEnd: 5)
        let second = TestClips.video(start: 5, sourceEnd: 5)
        project.addClip(first, toTrack: mainTrackID)
        project.addClip(second, toTrack: mainTrackID)

        let segments = CompositionPlanner.segments(for: project)

        XCTAssertEqual(segments.map(\.startInSeconds), [0, 5])
        XCTAssertEqual(segments.map(\.endInSeconds), [5, 10])
        XCTAssertEqual(segments.map(\.clipIDsTopFirst), [[first.id], [second.id]])
    }

    func testGapBetweenClipsIsASegmentWithoutLayers() {
        project.addClip(TestClips.video(start: 0, sourceEnd: 3), toTrack: mainTrackID)
        project.addClip(TestClips.video(start: 6, sourceEnd: 3), toTrack: mainTrackID)

        let segments = CompositionPlanner.segments(for: project)

        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[1].clipIDsTopFirst, [])
    }

    func testBrollIsLayeredAboveMainWhereTheyOverlap() {
        let main = TestClips.video(start: 0, sourceEnd: 10)
        let broll = TestClips.video(start: 3, sourceEnd: 4)
        project.addClip(main, toTrack: mainTrackID)
        project.addClip(broll, toTrack: brollTrackID)

        let segments = CompositionPlanner.segments(for: project)

        XCTAssertEqual(segments.map(\.clipIDsTopFirst), [[main.id], [broll.id, main.id], [main.id]])
        XCTAssertEqual(segments.map(\.startInSeconds), [0, 3, 7])
    }

    func testAudioLongerThanVideoExtendsTheLastSegment() {
        project.addClip(TestClips.video(start: 0, sourceEnd: 4), toTrack: mainTrackID)
        project.addClip(TestClips.audio(start: 0, duration: 10), toTrack: audioTrackID)

        let segments = CompositionPlanner.segments(for: project)

        XCTAssertEqual(segments.last?.endInSeconds, 10)
        XCTAssertEqual(segments.last?.clipIDsTopFirst, [])
    }

    func testSegmentsAreContiguousFromZero() {
        project.addClip(TestClips.video(start: 2, sourceEnd: 3), toTrack: mainTrackID)
        project.addClip(TestClips.video(start: 4, sourceEnd: 9), toTrack: brollTrackID)

        let segments = CompositionPlanner.segments(for: project)

        XCTAssertEqual(segments.first?.startInSeconds, 0)
        for (previous, next) in zip(segments, segments.dropFirst()) {
            XCTAssertEqual(previous.endInSeconds, next.startInSeconds)
        }
        XCTAssertEqual(segments.last?.endInSeconds, project.durationInSeconds)
    }

    func testClampDropsAndShortensSegmentsBeyondTheDuration() {
        let segments = [
            PlannedSegment(startInSeconds: 0, endInSeconds: 5, clipIDsTopFirst: []),
            PlannedSegment(startInSeconds: 5, endInSeconds: 10, clipIDsTopFirst: []),
            PlannedSegment(startInSeconds: 10, endInSeconds: 12, clipIDsTopFirst: []),
        ]

        let clamped = CompositionPlanner.clamp(segments, toDuration: 8)

        XCTAssertEqual(clamped.map(\.endInSeconds), [5, 8])
    }
}
