import XCTest
@testable import Clipsmith

@MainActor
final class ProjectStoreTests: XCTestCase {
    private var store = ProjectStore(project: Project(name: "Test"))

    private var mainTrack: Track { store.project.track(withRole: .main)! }

    override func setUp() async throws {
        store = ProjectStore(project: Project(name: "Test"))
    }

    func testAppendPlacesVideoAtTheEndOfTheMainTrack() {
        store.appendToTimeline(TestClips.mediaItem(duration: 5))
        store.appendToTimeline(TestClips.mediaItem(duration: 3))

        XCTAssertEqual(mainTrack.clips.map(\.startInSeconds), [0, 5])
    }

    func testAppendPlacesAudioOnTheAudioTrack() {
        store.appendToTimeline(TestClips.mediaItem(kind: .audio, duration: 8))

        XCTAssertEqual(store.project.track(withRole: .audio)?.clips.count, 1)
        XCTAssertTrue(mainTrack.clips.isEmpty)
    }

    func testAddedMediaBecomesSelected() {
        store.appendToTimeline(TestClips.mediaItem())

        XCTAssertEqual(store.selectedClipID, mainTrack.clips.first?.id)
    }

    func testSplitAtPlayheadSplitsTheSelectedClip() {
        store.appendToTimeline(TestClips.mediaItem(duration: 10))
        store.setPlayhead(near: 4)

        store.splitAtPlayhead()

        XCTAssertEqual(mainTrack.clips.map(\.startInSeconds), [0, 4])
    }

    func testSplitAtPlayheadWithoutSelectionSplitsEveryClipUnderIt() {
        store.appendToTimeline(TestClips.mediaItem(duration: 10))
        store.appendToTimeline(TestClips.mediaItem(kind: .audio, duration: 10))
        store.selectClip(nil)
        store.setPlayhead(near: 4)

        store.splitAtPlayhead()

        XCTAssertEqual(store.project.tracks.flatMap(\.clips).count, 4)
    }

    func testDeleteRemovesSelectionAndClearsIt() {
        store.appendToTimeline(TestClips.mediaItem())

        store.deleteSelectedClip()

        XCTAssertTrue(mainTrack.clips.isEmpty)
        XCTAssertNil(store.selectedClipID)
    }

    func testRippleDeleteClosesTheGapAndClearsSelection() {
        store.appendToTimeline(TestClips.mediaItem(duration: 5))
        let first = mainTrack.clips[0]
        store.appendToTimeline(TestClips.mediaItem(duration: 5))
        store.selectClip(first.id)

        store.rippleDeleteSelectedClip()

        XCTAssertEqual(mainTrack.clips.map(\.startInSeconds), [0])
        XCTAssertNil(store.selectedClipID)
    }

    func testPlayheadSnapsToClipEdges() {
        store.appendToTimeline(TestClips.mediaItem(duration: 10))

        store.setPlayhead(near: 10.05)

        XCTAssertEqual(store.playheadInSeconds, 10)
    }

    func testPlayheadNeverGoesNegative() {
        store.setPlayhead(near: -5)

        XCTAssertEqual(store.playheadInSeconds, 0)
    }

    func testMovedClipSnapsToTheNeighbouringEdge() {
        store.appendToTimeline(TestClips.mediaItem(duration: 5))
        store.appendToTimeline(TestClips.mediaItem(duration: 5))
        let second = mainTrack.clips[1]

        store.moveClip(second.id, toTrack: mainTrack.id, near: 5.1)

        XCTAssertEqual(mainTrack.clips[1].startInSeconds, 5)
    }

    func testZoomIsClamped() {
        for _ in 0..<50 { store.zoomIn() }
        XCTAssertEqual(store.pointsPerSecond, ProjectStore.maximumPointsPerSecond)

        for _ in 0..<100 { store.zoomOut() }
        XCTAssertEqual(store.pointsPerSecond, ProjectStore.minimumPointsPerSecond)
    }
}
