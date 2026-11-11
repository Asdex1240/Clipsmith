import XCTest
@testable import Clipsmith

@MainActor
final class MultiSelectionTests: XCTestCase {
    private var store: ProjectStore!
    private var main: Track.ID { store.project.track(withRole: .main)!.id }
    private var audio: Track.ID { store.project.track(withRole: .audio)!.id }

    override func setUp() {
        store = ProjectStore(project: Project(name: "T"))
    }

    @discardableResult
    private func addClips(at starts: [TimeInterval], track: Track.ID? = nil) -> [Clip.ID] {
        starts.map { start in
            store.addMedia(TestClips.mediaItem(duration: 4), toTrack: track ?? main, at: start)
            return store.selectedClipID!
        }
    }

    // MARK: Selecting

    func testToggleAddsAndRemovesClipsFromTheSelection() {
        let ids = addClips(at: [0, 10, 20])
        store.selectClip(ids[0])

        store.toggleSelection(of: ids[1])
        XCTAssertEqual(store.selectedClipIDs, [ids[0], ids[1]])
        XCTAssertEqual(store.selectedClipID, ids[1])
        XCTAssertTrue(store.hasMultipleSelected)

        store.toggleSelection(of: ids[1])
        XCTAssertEqual(store.selectedClipIDs, [ids[0]])
        XCTAssertEqual(store.selectedClipID, ids[0])
    }

    func testSelectAllAndDeselect() {
        let ids = addClips(at: [0, 10])

        store.selectAll()
        XCTAssertEqual(store.selectedClipIDs, Set(ids))

        store.selectClip(nil)
        XCTAssertTrue(store.selectedClipIDs.isEmpty)
        XCTAssertNil(store.selectedClipID)
    }

    func testClickingAClipSelectsOnlyIt() {
        let ids = addClips(at: [0, 10])
        store.selectAll()

        store.selectClip(ids[1])

        XCTAssertEqual(store.selectedClipIDs, [ids[1]])
    }

    // MARK: Editing

    func testDeleteRemovesEverySelectedClipInOneUndoStep() {
        let ids = addClips(at: [0, 10, 20])
        store.selectClip(ids[0])
        store.toggleSelection(of: ids[2])

        store.deleteSelectedClip()

        XCTAssertEqual(store.project.tracks.flatMap(\.clips).map(\.id), [ids[1]])
        XCTAssertTrue(store.selectedClipIDs.isEmpty)
        store.undo()
        XCTAssertEqual(store.project.allClipIDs, Set(ids))
    }

    func testRippleDeleteClosesEachGap() {
        let ids = addClips(at: [0, 4, 8])
        store.selectClip(ids[0])
        store.toggleSelection(of: ids[1])

        store.rippleDeleteSelectedClip()

        let clips = store.project.track(withRole: .main)!.clips
        XCTAssertEqual(clips.map(\.id), [ids[2]])
        XCTAssertEqual(clips[0].startInSeconds, 0, accuracy: 1e-9)
    }

    func testMovingTheSelectionKeepsTheSpacingBetweenClips() {
        let ids = addClips(at: [0, 6])
        store.selectAll()

        store.moveSelection(draggedClip: ids[0], near: 10)

        let clips = store.project.track(withRole: .main)!.clips
        XCTAssertEqual(clips.map(\.startInSeconds), [10, 16])
    }

    func testMovingStopsAtOtherClipsAndAtZero() {
        let ids = addClips(at: [2, 8, 20])
        store.selectClip(ids[0])
        store.toggleSelection(of: ids[1])

        store.moveSelection(draggedClip: ids[0], near: 18)
        var starts = store.project.track(withRole: .main)!.clips.map(\.startInSeconds)
        XCTAssertEqual(starts, [10, 16, 20])

        store.moveSelection(draggedClip: ids[0], near: -50)
        starts = store.project.track(withRole: .main)!.clips.map(\.startInSeconds)
        XCTAssertEqual(starts, [0, 6, 20])
    }

    func testMovingWorksAcrossTracks() {
        let video = addClips(at: [0])
        store.addMedia(TestClips.mediaItem(kind: .audio, duration: 4), toTrack: audio, at: 0)
        let sound = store.selectedClipID!
        store.selectAll()

        store.moveSelection(draggedClip: video[0], near: 5)

        XCTAssertEqual(store.project.clip(withID: video[0])?.startInSeconds, 5)
        XCTAssertEqual(store.project.clip(withID: sound)?.startInSeconds, 5)
    }

    func testSplitCutsEverySelectedClipUnderThePlayhead() {
        let video = addClips(at: [0])
        store.addMedia(TestClips.mediaItem(kind: .audio, duration: 4), toTrack: audio, at: 0)
        store.selectAll()
        store.movePlayhead(to: 2)

        store.splitAtPlayhead()

        XCTAssertEqual(store.project.track(withRole: .main)!.clips.count, 2)
        XCTAssertEqual(store.project.track(withRole: .audio)!.clips.count, 2)
        XCTAssertNotNil(video.first)
    }

    // MARK: Clipboard

    func testCopyAndPastePlacesTheSelectionAtThePlayheadKeepingItsShape() {
        let ids = addClips(at: [0, 6])
        store.selectAll()
        store.copySelectedClip()
        store.goToEnd()

        store.pasteAtPlayhead()

        let starts = store.project.track(withRole: .main)!.clips.map(\.startInSeconds)
        XCTAssertEqual(starts, [0, 6, 10, 16])
        XCTAssertEqual(store.selectedClipIDs.count, 2)
        XCTAssertTrue(store.selectedClipIDs.isDisjoint(with: Set(ids)))
    }

    func testDuplicateGoesRightAfterTheWholeSelection() {
        addClips(at: [0, 6])
        store.selectAll()

        store.duplicateSelectedClip()

        XCTAssertEqual(
            store.project.track(withRole: .main)!.clips.map(\.startInSeconds), [0, 6, 10, 16])
    }

    func testCutAndPasteMovesTheSelection() {
        let ids = addClips(at: [0, 6])
        store.selectAll()

        store.cutSelectedClip()
        XCTAssertTrue(store.project.track(withRole: .main)!.clips.isEmpty)
        store.pasteAtPlayhead()

        XCTAssertEqual(store.project.track(withRole: .main)!.clips.map(\.startInSeconds), [0, 6])
        XCTAssertTrue(store.selectedClipIDs.isDisjoint(with: Set(ids)))
    }

    // MARK: Groups

    func testGroupedClipsAreSelectedTogether() {
        let ids = addClips(at: [0, 10, 20])
        store.selectClip(ids[0])
        store.toggleSelection(of: ids[1])
        store.groupSelection()

        store.selectClip(ids[2])
        XCTAssertEqual(store.selectedClipIDs, [ids[2]])

        store.selectClip(ids[1])
        XCTAssertEqual(store.selectedClipIDs, [ids[0], ids[1]])
        XCTAssertTrue(store.selectionIsGrouped)
    }

    func testUngroupingReleasesEveryMember() {
        let ids = addClips(at: [0, 10])
        store.selectAll()
        store.groupSelection()
        store.selectClip(ids[0])

        store.ungroupSelection()
        store.selectClip(ids[0])

        XCTAssertEqual(store.selectedClipIDs, [ids[0]])
        XCTAssertFalse(store.selectionIsGrouped)
    }

    func testOneClipCannotBeGrouped() {
        let ids = addClips(at: [0])
        store.selectClip(ids[0])

        XCTAssertFalse(store.canGroupSelection)
        store.groupSelection()
        XCTAssertFalse(store.selectionIsGrouped)
    }

    func testSplittingAGroupGivesTheSecondHalvesTheirOwnGroup() {
        let ids = addClips(at: [0, 10])
        store.selectAll()
        store.groupSelection()
        store.selectAll()
        store.movePlayhead(to: 2)

        store.splitAtPlayhead()

        let clips = store.project.track(withRole: .main)!.clips
        XCTAssertEqual(clips.count, 3)
        let groups = clips.map(\.groupID)
        XCTAssertNotNil(groups[0])
        XCTAssertEqual(groups[0], groups[2])
        XCTAssertNotEqual(groups[1], groups[0])
        XCTAssertNotNil(ids.first)
    }

    func testPastedGroupsGetANewGroupIdentity() {
        let ids = addClips(at: [0, 6])
        store.selectAll()
        store.groupSelection()
        store.selectAll()
        store.duplicateSelectedClip()

        let clips = store.project.track(withRole: .main)!.clips
        let original = clips.filter { ids.contains($0.id) }.compactMap(\.groupID)
        let copies = clips.filter { !ids.contains($0.id) }.compactMap(\.groupID)
        XCTAssertEqual(Set(original).count, 1)
        XCTAssertEqual(Set(copies).count, 1)
        XCTAssertTrue(Set(original).isDisjoint(with: Set(copies)))
    }

    func testGroupsSurviveSavingAndUndo() throws {
        let ids = addClips(at: [0, 10])
        store.selectAll()
        store.groupSelection()

        let decoded = try JSONDecoder().decode(
            Project.self, from: JSONEncoder().encode(store.project))
        XCTAssertEqual(decoded.clip(withID: ids[0])?.groupID, decoded.clip(withID: ids[1])?.groupID)
        XCTAssertNotNil(decoded.clip(withID: ids[0])?.groupID)

        store.undo()
        XCTAssertNil(store.project.clip(withID: ids[0])?.groupID)
    }

    func testUndoDropsSelectedClipsThatNoLongerExist() {
        let ids = addClips(at: [0, 10])
        store.selectAll()

        store.undo()

        XCTAssertFalse(store.selectedClipIDs.contains(ids[1]))
        XCTAssertTrue(store.selectedClipIDs.isSubset(of: store.project.allClipIDs))
    }
}
