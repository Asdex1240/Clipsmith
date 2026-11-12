import XCTest
@testable import Clipsmith

@MainActor
final class RippleAllTracksTests: XCTestCase {
    private var project = Project(name: "T")

    private func add(_ clip: Clip, _ role: Track.Role) {
        project.addClip(clip, toTrack: project.track(withRole: role)!.id)
    }

    private func clips(_ role: Track.Role, in project: Project? = nil) -> [Clip] {
        (project ?? self.project).track(withRole: role)!.clips
    }

    private func store(deleting ids: [Clip.ID]) -> ProjectStore {
        let store = ProjectStore(project: project)
        store.selectClip(ids[0])
        for id in ids.dropFirst() { store.toggleSelection(of: id) }
        store.rippleDeleteSelectedClip()
        return store
    }

    func testDeletingAMainClipClosesTheGapOnEveryTrack() {
        let first = TestClips.video(start: 0, sourceEnd: 5)
        let second = TestClips.video(start: 5, sourceEnd: 5)
        let third = TestClips.video(start: 10, sourceEnd: 5)
        [first, second, third].forEach { add($0, .main) }
        add(TestClips.audio(start: 0, duration: 15), .audio)
        add(
            Clip(text: TextLayer(content: "later"), startInSeconds: 11, durationInSeconds: 2), .text
        )

        let result = store(deleting: [second.id]).project

        XCTAssertEqual(clips(.main, in: result).map(\.startInSeconds), [0, 5])
        XCTAssertEqual(clips(.audio, in: result).map(\.durationInSeconds), [5, 5])
        XCTAssertEqual(clips(.audio, in: result).map(\.startInSeconds), [0, 5])
        XCTAssertEqual(clips(.text, in: result).first?.startInSeconds ?? 0, 6, accuracy: 1e-9)
        XCTAssertEqual(result.durationInSeconds, 10, accuracy: 1e-9)
    }

    func testClipsInsideTheDeletedStretchGoAndLaterMarkersAndHighlightsMoveBack() {
        let first = TestClips.video(start: 0, sourceEnd: 5)
        let second = TestClips.video(start: 5, sourceEnd: 5)
        let third = TestClips.video(start: 10, sourceEnd: 5)
        [first, second, third].forEach { add($0, .main) }
        add(Clip(text: TextLayer(content: "gone"), startInSeconds: 6, durationInSeconds: 2), .text)
        project.markers = [Marker(timeInSeconds: 7), Marker(timeInSeconds: 12)]
        project.addHighlight(Highlight(name: "h", startInSeconds: 11, endInSeconds: 14))

        let result = store(deleting: [second.id]).project

        XCTAssertTrue(clips(.text, in: result).isEmpty)
        XCTAssertEqual(result.markers.map(\.timeInSeconds), [7])
        XCTAssertEqual(result.highlights.first?.startInSeconds ?? 0, 6, accuracy: 1e-9)
    }

    func testDeletingAClipOnAnotherTrackOnlyAffectsThatTrack() {
        add(TestClips.video(start: 0, sourceEnd: 20), .main)
        let overlay = TestClips.video(start: 2, sourceEnd: 3)
        let after = TestClips.video(start: 8, sourceEnd: 3)
        add(overlay, .broll)
        add(after, .broll)
        let text = Clip(text: TextLayer(content: "stays"), startInSeconds: 9, durationInSeconds: 2)
        add(text, .text)

        let result = store(deleting: [overlay.id]).project

        XCTAssertEqual(clips(.main, in: result).map(\.durationInSeconds), [20])
        XCTAssertEqual(clips(.broll, in: result).map(\.startInSeconds), [5])
        XCTAssertEqual(clips(.text, in: result).first?.startInSeconds, 9)
    }

    func testSeveralMainClipsAreRemovedTogether() {
        let ids = (0..<4).map { index -> Clip.ID in
            let clip = TestClips.video(start: Double(index) * 5, sourceEnd: 5)
            add(clip, .main)
            return clip.id
        }
        add(TestClips.audio(start: 0, duration: 20), .audio)

        let result = store(deleting: [ids[0], ids[2]]).project

        XCTAssertEqual(clips(.main, in: result).map(\.id), [ids[1], ids[3]])
        XCTAssertEqual(clips(.main, in: result).map(\.startInSeconds), [0, 5])
        XCTAssertEqual(
            clips(.audio, in: result).reduce(0) { $0 + $1.durationInSeconds }, 10, accuracy: 1e-9)
    }

    func testItIsOneUndoStep() {
        let first = TestClips.video(start: 0, sourceEnd: 5)
        let second = TestClips.video(start: 5, sourceEnd: 5)
        [first, second].forEach { add($0, .main) }
        add(TestClips.audio(start: 0, duration: 10), .audio)
        let store = store(deleting: [first.id])

        store.undo()

        XCTAssertEqual(store.project, project)
    }

    func testThePlainPrimitiveStillLeavesOtherTracksAlone() {
        let main = TestClips.video(start: 0, sourceEnd: 5)
        let broll = TestClips.video(start: 8, sourceEnd: 5)
        add(main, .main)
        add(broll, .broll)

        project.rippleDeleteClips([main.id])

        XCTAssertEqual(clips(.broll).first?.startInSeconds, 8)
    }
}
