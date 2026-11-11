import XCTest
@testable import Clipsmith

final class SlowMomentTests: XCTestCase {
    private var project = Project(name: "T")
    private var mainID: Track.ID { project.track(withRole: .main)!.id }
    private var main: [Clip] { project.track(withRole: .main)!.clips }

    private func addVideo(start: TimeInterval = 0, length: TimeInterval = 20) -> Clip {
        let clip = TestClips.video(start: start, sourceEnd: length)
        project.addClip(clip, toTrack: mainID)
        return clip
    }

    func testSplitsTheClipIntoFiveSlowedPiecesBetweenTheRest() {
        let clip = addVideo()

        let added = project.addSlowMoment(to: clip.id, at: 5, sourceDuration: 2)

        XCTAssertTrue(added)
        XCTAssertEqual(main.count, 7)
        XCTAssertEqual(main.map(\.speed).prefix(1), [1])
        let speeds = main[1...5].map(\.speed)
        XCTAssertEqual(speeds[2], SlowMoment.defaultFactor, accuracy: 1e-9)
        XCTAssertTrue(speeds[0] > speeds[1] && speeds[1] > speeds[2])
        XCTAssertEqual(speeds[0], speeds[4], accuracy: 1e-9)
        XCTAssertEqual(main.last?.speed, 1)
    }

    func testPiecesStayContiguousAndTheRestMovesLater() {
        let clip = addVideo()

        project.addSlowMoment(to: clip.id, at: 5, sourceDuration: 2)

        for (left, right) in zip(main, main.dropFirst()) {
            XCTAssertEqual(left.endInSeconds, right.startInSeconds, accuracy: 1e-9)
        }
        let slowed = main[1...5].reduce(0) { $0 + $1.durationInSeconds }
        XCTAssertGreaterThan(slowed, 2)
        XCTAssertEqual(main.last?.endInSeconds ?? 0, 20 + slowed - 2, accuracy: 1e-9)
    }

    func testTheWholeSourceIsStillPlayedOnce() {
        let clip = addVideo()

        project.addSlowMoment(to: clip.id, at: 5, sourceDuration: 2)

        let covered = main.reduce(0) { $0 + $1.sourceSpanInSeconds }
        XCTAssertEqual(covered, 20, accuracy: 1e-9)
        for (left, right) in zip(main, main.dropFirst()) {
            XCTAssertEqual(left.sourceEndInSeconds, right.sourceStartInSeconds, accuracy: 1e-9)
        }
    }

    func testAudioOfTheMomentIsMutedOnlyWhenAsked() {
        let clip = addVideo()
        project.addSlowMoment(to: clip.id, at: 5, sourceDuration: 2, mutesAudio: true)
        XCTAssertEqual(main[1...5].map(\.volume), [0, 0, 0, 0, 0])
        XCTAssertEqual(main[0].volume, 1)

        var other = Project(name: "T")
        let second = TestClips.video(start: 0, sourceEnd: 20)
        other.addClip(second, toTrack: other.track(withRole: .main)!.id)
        other.addSlowMoment(to: second.id, at: 5, sourceDuration: 2, mutesAudio: false)
        XCTAssertTrue(other.track(withRole: .main)!.clips.allSatisfy { $0.volume == 1 })
    }

    func testMomentAtTheStartAndAtTheEnd() {
        let first = addVideo()
        project.addSlowMoment(to: first.id, at: 0, sourceDuration: 2)
        XCTAssertEqual(main.count, 6)
        XCTAssertEqual(main.first?.startInSeconds, 0)

        var other = Project(name: "T")
        let second = TestClips.video(start: 0, sourceEnd: 20)
        other.addClip(second, toTrack: other.track(withRole: .main)!.id)
        other.addSlowMoment(to: second.id, at: 18, sourceDuration: 2)
        XCTAssertEqual(other.track(withRole: .main)!.clips.count, 6)
    }

    func testLaterClipsAndMarkersMoveButEarlierOnesDoNot() {
        let clip = addVideo(length: 10)
        let later = addVideo(start: 10, length: 5)
        project.markers = [Marker(timeInSeconds: 2), Marker(timeInSeconds: 12)]

        project.addSlowMoment(to: clip.id, at: 3, sourceDuration: 2)

        let shift = main.last!.startInSeconds - 10
        XCTAssertGreaterThan(shift, 0)
        XCTAssertEqual(main.last?.id, later.id)
        XCTAssertEqual(project.markers.map(\.timeInSeconds), [2, 12 + shift])
    }

    func testOtherTracksAfterTheMomentStayInSync() {
        let clip = addVideo()
        project.addClip(
            TestClips.audio(start: 12, duration: 5), toTrack: project.track(withRole: .audio)!.id)

        project.addSlowMoment(to: clip.id, at: 3, sourceDuration: 2)

        let shift = main.last!.endInSeconds - 20
        XCTAssertEqual(
            project.track(withRole: .audio)!.clips[0].startInSeconds, 12 + shift, accuracy: 1e-9)
    }

    func testRefusesWhenThereIsNoRoomOrNoSpeedSupport() {
        let clip = addVideo(length: 10)
        XCTAssertFalse(project.addSlowMoment(to: clip.id, at: 9, sourceDuration: 2))
        XCTAssertFalse(project.addSlowMoment(to: clip.id, at: 1, sourceDuration: 0.5))
        XCTAssertFalse(project.addSlowMoment(to: clip.id, at: -1, sourceDuration: 2))
        XCTAssertEqual(main, [clip])

        let text = Clip(text: TextLayer(content: "t"), startInSeconds: 0, durationInSeconds: 10)
        project.addClip(text, toTrack: project.track(withRole: .text)!.id)
        XCTAssertFalse(project.addSlowMoment(to: text.id, at: 1, sourceDuration: 2))
    }

    func testAClipThatIsAlreadySlowerKeepsItsRelativeSlowdown() {
        var clip = TestClips.video(start: 0, sourceEnd: 20)
        clip.speed = 2
        project.addClip(clip, toTrack: mainID)

        project.addSlowMoment(to: clip.id, at: 1, sourceDuration: 2, factor: 0.5)

        XCTAssertEqual(main.map(\.speed).max() ?? 0, 2, accuracy: 1e-9)
        XCTAssertEqual(main[1...5].map(\.speed)[2], 1, accuracy: 1e-9)
    }

    @MainActor
    func testStoreAppliesItAsOneUndoStep() {
        let clip = addVideo()
        let store = ProjectStore(project: project)

        let added = store.addSlowMoment(
            to: clip.id, at: 5, sourceDuration: 2, factor: 0.4, mutesAudio: true)
        store.undo()

        XCTAssertTrue(added)
        XCTAssertEqual(store.project.track(withRole: .main)!.clips, [clip])
    }
}
