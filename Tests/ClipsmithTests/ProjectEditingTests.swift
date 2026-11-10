import XCTest
@testable import Clipsmith

final class ProjectEditingTests: XCTestCase {
    private var project = Project(name: "Test")

    private var mainTrackID: Track.ID { project.track(withRole: .main)!.id }
    private var audioTrackID: Track.ID { project.track(withRole: .audio)!.id }
    private var brollTrackID: Track.ID { project.track(withRole: .broll)!.id }
    private var mainClips: [Clip] { project.track(withRole: .main)!.clips }

    override func setUp() {
        project = Project(name: "Test")
    }

    func testAddClipRejectsMediaTheTrackDoesNotAccept() {
        let added = project.addClip(TestClips.audio(start: 0, duration: 5), toTrack: mainTrackID)

        XCTAssertFalse(added)
        XCTAssertTrue(mainClips.isEmpty)
    }

    func testAddClipOverlappingAnotherMovesToNearestFreePosition() {
        project.addClip(TestClips.video(start: 0, sourceEnd: 10), toTrack: mainTrackID)

        project.addClip(TestClips.video(start: 4, sourceEnd: 10), toTrack: mainTrackID)

        XCTAssertEqual(mainClips.map(\.startInSeconds), [0, 10])
    }

    func testMoveClipToFreeSpotKeepsRequestedStart() {
        let clip = TestClips.video(start: 0, sourceEnd: 5)
        project.addClip(clip, toTrack: mainTrackID)

        project.moveClip(clip.id, toTrack: mainTrackID, startingAt: 20)

        XCTAssertEqual(mainClips[0].startInSeconds, 20)
    }

    func testMoveClipOntoNeighbourDoesNotOverlap() {
        let first = TestClips.video(start: 0, sourceEnd: 5)
        let second = TestClips.video(start: 5, sourceEnd: 5)
        project.addClip(first, toTrack: mainTrackID)
        project.addClip(second, toTrack: mainTrackID)

        project.moveClip(second.id, toTrack: mainTrackID, startingAt: 1)

        XCTAssertEqual(mainClips.map(\.startInSeconds), [0, 5])
    }

    func testMoveClipCanReorderAroundNeighbour() {
        let first = TestClips.video(start: 0, sourceEnd: 5)
        let second = TestClips.video(start: 5, sourceEnd: 5)
        project.addClip(first, toTrack: mainTrackID)
        project.addClip(second, toTrack: mainTrackID)

        project.moveClip(first.id, toTrack: mainTrackID, startingAt: 7)

        XCTAssertEqual(mainClips.map(\.id), [second.id, first.id])
    }

    func testMoveClipToIncompatibleTrackIsRejected() {
        let clip = TestClips.video(start: 0)
        project.addClip(clip, toTrack: mainTrackID)

        let moved = project.moveClip(clip.id, toTrack: audioTrackID, startingAt: 0)

        XCTAssertFalse(moved)
        XCTAssertEqual(mainClips.count, 1)
    }

    func testMoveClipBetweenVideoTracks() {
        let clip = TestClips.video(start: 2)
        project.addClip(clip, toTrack: mainTrackID)

        project.moveClip(clip.id, toTrack: brollTrackID, startingAt: 2)

        XCTAssertTrue(mainClips.isEmpty)
        XCTAssertEqual(project.track(withRole: .broll)?.clips.count, 1)
    }

    func testTrimLeadingAdvancesStartAndSourceTogether() {
        let clip = TestClips.video(start: 10, sourceStart: 0, sourceEnd: 10)
        project.addClip(clip, toTrack: mainTrackID)

        project.trimClip(clip.id, edge: .leading, to: 13)

        XCTAssertEqual(mainClips[0].startInSeconds, 13)
        XCTAssertEqual(mainClips[0].sourceStartInSeconds, 3)
        XCTAssertEqual(mainClips[0].endInSeconds, 20)
    }

    func testTrimLeadingCannotGoBeforeTheStartOfTheSource() {
        let clip = TestClips.video(start: 10, sourceStart: 2, sourceEnd: 12)
        project.addClip(clip, toTrack: mainTrackID)

        project.trimClip(clip.id, edge: .leading, to: 0)

        XCTAssertEqual(mainClips[0].startInSeconds, 8)
        XCTAssertEqual(mainClips[0].sourceStartInSeconds, 0)
    }

    func testTrimLeadingStopsAtPreviousClip() {
        let first = TestClips.video(start: 0, sourceEnd: 5)
        let second = TestClips.video(start: 8, sourceStart: 4, sourceEnd: 9)
        project.addClip(first, toTrack: mainTrackID)
        project.addClip(second, toTrack: mainTrackID)

        project.trimClip(second.id, edge: .leading, to: 2)

        XCTAssertEqual(mainClips[1].startInSeconds, 5)
    }

    func testTrimLeadingKeepsMinimumDuration() {
        let clip = TestClips.video(start: 0, sourceEnd: 10)
        project.addClip(clip, toTrack: mainTrackID)

        project.trimClip(clip.id, edge: .leading, to: 50)

        XCTAssertEqual(mainClips[0].durationInSeconds, Clip.minimumDurationInSeconds, accuracy: 1e-9)
    }

    func testTrimTrailingShortensTheClip() {
        let clip = TestClips.video(start: 0, sourceEnd: 10)
        project.addClip(clip, toTrack: mainTrackID)

        project.trimClip(clip.id, edge: .trailing, to: 6)

        XCTAssertEqual(mainClips[0].endInSeconds, 6)
        XCTAssertEqual(mainClips[0].sourceEndInSeconds, 6)
    }

    func testTrimTrailingCannotExceedSourceDuration() {
        let clip = TestClips.video(start: 0, sourceStart: 0, sourceEnd: 10, sourceDuration: 15)
        project.addClip(clip, toTrack: mainTrackID)

        project.trimClip(clip.id, edge: .trailing, to: 100)

        XCTAssertEqual(mainClips[0].endInSeconds, 15)
    }

    func testTrimTrailingStopsAtNextClip() {
        let first = TestClips.video(start: 0, sourceEnd: 5)
        let second = TestClips.video(start: 8, sourceEnd: 5)
        project.addClip(first, toTrack: mainTrackID)
        project.addClip(second, toTrack: mainTrackID)

        project.trimClip(first.id, edge: .trailing, to: 30)

        XCTAssertEqual(mainClips[0].endInSeconds, 8)
    }

    func testStillImagesCanBeStretchedWithoutLimit() {
        let image = Clip(item: TestClips.mediaItem(kind: .image, duration: 5), startInSeconds: 0)
        project.addClip(image, toTrack: mainTrackID)

        project.trimClip(image.id, edge: .trailing, to: 60)

        XCTAssertEqual(mainClips[0].durationInSeconds, 60)
    }

    func testSplitCreatesTwoContiguousClipsCoveringTheOriginal() throws {
        let clip = TestClips.video(start: 10, sourceStart: 2, sourceEnd: 12)
        project.addClip(clip, toTrack: mainTrackID)

        XCTAssertTrue(project.splitClip(clip.id, at: 14))

        XCTAssertEqual(mainClips.count, 2)
        XCTAssertEqual(mainClips[0].startInSeconds, 10)
        XCTAssertEqual(mainClips[0].endInSeconds, 14)
        XCTAssertEqual(mainClips[1].startInSeconds, 14)
        XCTAssertEqual(mainClips[1].endInSeconds, 20)
        XCTAssertEqual(mainClips[0].sourceEndInSeconds, mainClips[1].sourceStartInSeconds)
        XCTAssertNotEqual(mainClips[0].id, mainClips[1].id)
    }

    func testSplitAtTheEdgesOrOutsideIsRejected() {
        let clip = TestClips.video(start: 10, sourceEnd: 10)
        project.addClip(clip, toTrack: mainTrackID)

        XCTAssertFalse(project.splitClip(clip.id, at: 10))
        XCTAssertFalse(project.splitClip(clip.id, at: 20))
        XCTAssertFalse(project.splitClip(clip.id, at: 5))
        XCTAssertEqual(mainClips.count, 1)
    }

    func testDeleteLeavesAGap() {
        let first = TestClips.video(start: 0, sourceEnd: 5)
        let second = TestClips.video(start: 5, sourceEnd: 5)
        project.addClip(first, toTrack: mainTrackID)
        project.addClip(second, toTrack: mainTrackID)

        project.deleteClip(first.id)

        XCTAssertEqual(mainClips.map(\.startInSeconds), [5])
    }

    func testRippleDeleteClosesTheGap() {
        let first = TestClips.video(start: 0, sourceEnd: 5)
        let second = TestClips.video(start: 5, sourceEnd: 5)
        let third = TestClips.video(start: 10, sourceEnd: 5)
        [first, second, third].forEach { project.addClip($0, toTrack: mainTrackID) }

        project.rippleDeleteClip(second.id)

        XCTAssertEqual(mainClips.map(\.id), [first.id, third.id])
        XCTAssertEqual(mainClips.map(\.startInSeconds), [0, 5])
    }

    func testRippleDeleteDoesNotAffectOtherTracks() {
        let main = TestClips.video(start: 0, sourceEnd: 5)
        let broll = TestClips.video(start: 8, sourceEnd: 5)
        project.addClip(main, toTrack: mainTrackID)
        project.addClip(broll, toTrack: brollTrackID)

        project.rippleDeleteClip(main.id)

        XCTAssertEqual(project.track(withRole: .broll)?.clips.first?.startInSeconds, 8)
    }

    func testProjectDurationIsTheLatestClipEnd() {
        project.addClip(TestClips.video(start: 0, sourceEnd: 5), toTrack: mainTrackID)
        project.addClip(TestClips.audio(start: 2, duration: 20), toTrack: audioTrackID)

        XCTAssertEqual(project.durationInSeconds, 22)
    }

    func testEditingAnUnknownClipChangesNothing() {
        let clip = TestClips.video(start: 0)
        project.addClip(clip, toTrack: mainTrackID)
        let unknown = UUID()

        project.deleteClip(unknown)
        project.rippleDeleteClip(unknown)
        project.trimClip(unknown, edge: .leading, to: 3)

        XCTAssertEqual(mainClips, [clip])
    }
}
