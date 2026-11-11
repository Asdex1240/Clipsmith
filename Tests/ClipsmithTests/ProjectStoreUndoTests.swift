import XCTest
@testable import Clipsmith

@MainActor
final class ProjectStoreUndoTests: XCTestCase {
    private var clock = Date(timeIntervalSince1970: 1_000)
    private var store = ProjectStore(project: Project(name: "Test"))

    private var mainClips: [Clip] { store.project.track(withRole: .main)!.clips }

    override func setUp() async throws {
        clock = Date(timeIntervalSince1970: 1_000)
        store = ProjectStore(project: Project(name: "Test"), now: { [unowned self] in clock })
    }

    func testNewStoreHasNothingToUndoOrRedo() {
        XCTAssertFalse(store.canUndo)
        XCTAssertFalse(store.canRedo)
    }

    func testUndoRestoresThePreviousStateAndRedoReappliesIt() {
        store.appendToTimeline(TestClips.mediaItem(duration: 5))

        store.undo()
        XCTAssertTrue(mainClips.isEmpty)
        XCTAssertTrue(store.canRedo)

        store.redo()
        XCTAssertEqual(mainClips.count, 1)
        XCTAssertFalse(store.canRedo)
    }

    func testEachEditingOperationIsUndoable() {
        store.appendToTimeline(TestClips.mediaItem(duration: 10))
        store.setPlayhead(near: 4)
        store.splitAtPlayhead()
        XCTAssertEqual(mainClips.count, 2)
        store.undo()
        XCTAssertEqual(mainClips.count, 1)

        store.selectClip(mainClips[0].id)
        store.deleteSelectedClip()
        XCTAssertTrue(mainClips.isEmpty)
        store.undo()
        XCTAssertEqual(mainClips.count, 1)

        store.selectClip(mainClips[0].id)
        store.rippleDeleteSelectedClip()
        store.undo()
        XCTAssertEqual(mainClips.count, 1)

        store.setCanvas(.portrait)
        store.undo()
        XCTAssertEqual(store.project.canvas, .landscape)
    }

    func testOperationsThatChangeNothingAreNotRecorded() {
        store.splitAtPlayhead()
        store.deleteSelectedClip()
        store.moveClip(UUID(), toTrack: UUID(), near: 3)

        XCTAssertFalse(store.canUndo)
    }

    func testNewEditClearsTheRedoHistory() {
        store.appendToTimeline(TestClips.mediaItem())
        store.undo()
        XCTAssertTrue(store.canRedo)

        store.appendToTimeline(TestClips.mediaItem())

        XCTAssertFalse(store.canRedo)
    }

    func testRapidChangesToTheSameFieldAreOneUndoStep() {
        store.appendToTimeline(TestClips.mediaItem(kind: .audio, duration: 10))
        let id = store.selectedClipID!

        for value in stride(from: 0.9, through: 0.3, by: -0.1) {
            store.setVolume(of: id, to: value)
            clock.addTimeInterval(0.1)
        }
        store.undo()

        XCTAssertEqual(store.selectedClip?.volume, 1)
    }

    func testChangesSeparatedByALongPauseAreSeparateSteps() {
        store.appendToTimeline(TestClips.mediaItem(kind: .audio, duration: 10))
        let id = store.selectedClipID!

        store.setVolume(of: id, to: 0.8)
        clock.addTimeInterval(ProjectStore.coalescingWindowInSeconds + 1)
        store.setVolume(of: id, to: 0.4)
        store.undo()

        XCTAssertEqual(store.selectedClip?.volume, 0.8)
    }

    func testChangesToDifferentFieldsAreNotMerged() {
        store.appendToTimeline(TestClips.mediaItem(kind: .audio, duration: 10))
        let id = store.selectedClipID!

        store.setVolume(of: id, to: 0.5)
        store.setFadeIn(of: id, to: 2)
        store.undo()

        XCTAssertEqual(store.selectedClip?.volume, 0.5)
        XCTAssertEqual(store.selectedClip?.fadeInDurationInSeconds, 0)
    }

    func testTrimDragIsASingleUndoStep() {
        store.appendToTimeline(TestClips.mediaItem(duration: 10))
        let id = store.selectedClipID!

        for end in [9.0, 8.0, 7.0, 6.0] {
            store.trimClip(id, edge: .trailing, near: end)
            clock.addTimeInterval(0.05)
        }
        XCTAssertEqual(store.selectedClip?.durationInSeconds, 6)
        store.undo()

        XCTAssertEqual(store.selectedClip?.durationInSeconds, 10)
    }

    func testTextEditsToTheSameFieldAreCoalesced() {
        store.addTextAtPlayhead()
        let id = store.selectedClipID!

        for text in ["B", "Ba", "Bar", "Barc"] {
            store.updateTextLayer(of: id, field: "content") { $0.content = text }
            clock.addTimeInterval(0.1)
        }
        store.undo()

        XCTAssertEqual(store.selectedClip?.displayName, localized("text.default"))
    }

    func testUndoKeepsTheCurrentProjectName() {
        store.appendToTimeline(TestClips.mediaItem())
        store.setProjectName("Renamed")

        store.undo()

        XCTAssertEqual(store.project.name, "Renamed")
    }

    func testUndoClearsASelectionThatNoLongerExists() {
        store.appendToTimeline(TestClips.mediaItem())
        XCTAssertNotNil(store.selectedClipID)

        store.undo()

        XCTAssertNil(store.selectedClipID)
    }

    func testHistoryIsLimited() {
        for index in 0..<(ProjectStore.maximumUndoSteps + 20) {
            if index.isMultiple(of: 2) {
                store.setCanvas(.portrait)
            } else {
                store.setCanvas(.landscape)
            }
        }
        var steps = 0
        while store.canUndo {
            store.undo()
            steps += 1
        }

        XCTAssertEqual(steps, ProjectStore.maximumUndoSteps)
    }

    func testLoadingAProjectResetsTheHistory() {
        store.appendToTimeline(TestClips.mediaItem())

        store.load(Project(name: "Other"))

        XCTAssertFalse(store.canUndo)
        XCTAssertFalse(store.canRedo)
        XCTAssertEqual(store.project.name, "Other")
        XCTAssertEqual(store.playheadInSeconds, 0)
        XCTAssertNil(store.selectedClipID)
    }

    func testReplacingMediaIsUndoable() {
        let item = TestClips.mediaItem()
        store.appendToTimeline(item)
        let replacement = URL(fileURLWithPath: "/tmp/other.mp4")

        store.replaceMedia(from: item.url, to: replacement)
        XCTAssertEqual(store.project.referencedSourceURLs, [replacement])
        store.undo()

        XCTAssertEqual(store.project.referencedSourceURLs, [item.url])
    }
}
