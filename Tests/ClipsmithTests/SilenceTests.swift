import XCTest
@testable import Clipsmith

final class SilenceDetectorTests: XCTestCase {
    private let rate = WaveformSpec.peaksPerSecond

    private func peaks(_ segments: [(seconds: Double, level: Float)]) -> [Float] {
        segments.flatMap { [Float](repeating: $0.level, count: Int($0.seconds * rate)) }
    }

    func testFindsAQuietStretchAndKeepsPaddingAroundIt() {
        let data = peaks([(2, 0.5), (3, 0), (2, 0.5)])

        let result = SilenceDetector.silences(peaks: data, from: 0, to: 7, minimumDuration: 1)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].lowerBound, 2.1, accuracy: 0.001)
        XCTAssertEqual(result[0].upperBound, 4.9, accuracy: 0.001)
    }

    func testIgnoresPausesShorterThanTheMinimum() {
        let data = peaks([(2, 0.5), (0.4, 0), (2, 0.5)])

        XCTAssertTrue(
            SilenceDetector.silences(peaks: data, from: 0, to: 4.4, minimumDuration: 1).isEmpty)
    }

    func testLeadingAndTrailingSilenceTouchTheEdges() {
        let data = peaks([(2, 0), (2, 0.5), (2, 0)])

        let result = SilenceDetector.silences(peaks: data, from: 0, to: 6, minimumDuration: 1)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].lowerBound, 0, accuracy: 0.001)
        XCTAssertEqual(result[1].upperBound, 6, accuracy: 0.001)
    }

    func testHigherThresholdFindsMore() {
        let data = peaks([(2, 0.5), (2, 0.05), (2, 0.5)])

        XCTAssertTrue(
            SilenceDetector.silences(peaks: data, from: 0, to: 6, threshold: 0.02).isEmpty)
        XCTAssertEqual(
            SilenceDetector.silences(peaks: data, from: 0, to: 6, threshold: 0.1).count, 1)
    }

    func testRangesFollowTheClipOnTheTimeline() {
        let clip = TestClips.video(start: 20, sourceStart: 4, sourceEnd: 14)

        let result = SilenceDetector.timelineRanges([6..<8, 0..<5, 13..<20], for: clip)

        XCTAssertEqual(result, [22..<24, 20..<21, 29..<30])
    }
}

final class SilenceRemovalTests: XCTestCase {
    private func project(with clip: Clip) -> (Project, Clip.ID) {
        var project = Project(name: "T")
        project.addClip(clip, toTrack: project.track(withRole: .main)!.id)
        return (project, clip.id)
    }

    func testRemovingRangesClosesTheGaps() {
        let (start, id) = project(with: TestClips.video(start: 0, sourceEnd: 20))
        var project = start

        let removed = project.removeRanges([2..<4, 10..<13], from: id)

        let clips = project.track(withRole: .main)!.clips
        XCTAssertEqual(removed, 2)
        XCTAssertEqual(clips.count, 3)
        XCTAssertEqual(clips.map(\.startInSeconds), [0, 2, 8])
        XCTAssertEqual(clips.map(\.durationInSeconds), [2, 6, 7])
        XCTAssertEqual(clips.last?.endInSeconds ?? 0, 15, accuracy: 1e-9)
    }

    func testSilenceAtTheStartOfTheClipIsRemoved() {
        let (start, id) = project(with: TestClips.video(start: 0, sourceEnd: 10))
        var project = start

        project.removeRanges([0..<3], from: id)

        let clips = project.track(withRole: .main)!.clips
        XCTAssertEqual(clips.count, 1)
        XCTAssertEqual(clips[0].startInSeconds, 0)
        XCTAssertEqual(clips[0].durationInSeconds, 7, accuracy: 1e-9)
        XCTAssertEqual(clips[0].sourceStartInSeconds, 3, accuracy: 1e-9)
    }

    func testGroupedClipsAreCutTogether() {
        var base = Project(name: "T")
        let video = TestClips.video(start: 0, sourceEnd: 10)
        let audio = TestClips.video(start: 0, sourceEnd: 10)
        base.addClip(video, toTrack: base.track(withRole: .main)!.id)
        base.addClip(audio, toTrack: base.track(withRole: .broll)!.id)
        base.group([video.id, audio.id])
        var project = base

        project.removeRanges([4..<6], from: video.id)

        XCTAssertEqual(project.track(withRole: .main)!.clips.count, 2)
        XCTAssertEqual(project.track(withRole: .broll)!.clips.count, 2)
        XCTAssertEqual(
            project.track(withRole: .broll)!.clips.last?.startInSeconds ?? 0, 4, accuracy: 1e-9)
    }

    @MainActor
    func testStoreRemovesAllSilencesInOneUndoStep() {
        let (start, id) = project(with: TestClips.video(start: 0, sourceEnd: 20))
        let store = ProjectStore(project: start)

        store.removeSilences([2..<4, 10..<13], from: id)
        XCTAssertEqual(store.project.track(withRole: .main)!.clips.count, 3)

        store.undo()
        XCTAssertEqual(store.project.track(withRole: .main)!.clips.count, 1)
    }
}

final class TimeRemovalTests: XCTestCase {
    private var project = Project(name: "T")

    private func clips(_ role: Track.Role) -> [Clip] { project.track(withRole: role)!.clips }

    private func add(_ clip: Clip, _ role: Track.Role) {
        project.addClip(clip, toTrack: project.track(withRole: role)!.id)
    }

    func testOtherTracksStayInSyncWithTheCut() {
        let video = TestClips.video(start: 0, sourceEnd: 20)
        let music = TestClips.audio(start: 0, duration: 30)
        add(video, .main)
        add(music, .audio)

        project.removeRanges([5..<8], from: video.id, scope: .allTracks)

        XCTAssertEqual(clips(.main).map(\.durationInSeconds), [5, 12])
        XCTAssertEqual(clips(.audio).map(\.startInSeconds), [0, 5])
        XCTAssertEqual(clips(.audio).map(\.durationInSeconds), [5, 22])
        XCTAssertEqual(project.durationInSeconds, 27, accuracy: 1e-9)
    }

    func testClipsInsideTheCutAreRemovedAndLaterOnesMove() {
        let video = TestClips.video(start: 0, sourceEnd: 20)
        add(video, .main)
        add(Clip(text: TextLayer(content: "gone"), startInSeconds: 6, durationInSeconds: 1), .text)
        add(
            Clip(text: TextLayer(content: "later"), startInSeconds: 12, durationInSeconds: 2), .text
        )

        project.removeRanges([5..<8], from: video.id, scope: .allTracks)

        XCTAssertEqual(clips(.text).compactMap { $0.textLayer?.content }, ["later"])
        XCTAssertEqual(clips(.text).first?.startInSeconds ?? 0, 9, accuracy: 1e-9)
    }

    func testClipsOverlappingTheEdgesAreTrimmedWithoutOverlap() {
        let video = TestClips.video(start: 0, sourceEnd: 20)
        add(video, .main)
        add(Clip(text: TextLayer(content: "a"), startInSeconds: 3, durationInSeconds: 4), .text)
        add(Clip(text: TextLayer(content: "b"), startInSeconds: 7, durationInSeconds: 4), .text)

        project.removeRanges([5..<8], from: video.id, scope: .allTracks)

        let text = clips(.text)
        XCTAssertEqual(text.map(\.startInSeconds), [3, 5])
        XCTAssertEqual(text.map(\.durationInSeconds), [2, 3])
        XCTAssertLessThanOrEqual(text[0].endInSeconds, text[1].startInSeconds + 1e-9)
    }

    func testMarkersAndHighlightsFollowTheCut() {
        let video = TestClips.video(start: 0, sourceEnd: 30)
        add(video, .main)
        project.markers = [
            Marker(timeInSeconds: 2), Marker(timeInSeconds: 6), Marker(timeInSeconds: 20),
        ]
        project.addHighlight(Highlight(name: "h", startInSeconds: 10, endInSeconds: 25))

        project.removeRanges([5..<8], from: video.id, scope: .allTracks)

        XCTAssertEqual(project.markers.map(\.timeInSeconds), [2, 17])
        XCTAssertEqual(project.highlights.first?.startInSeconds ?? 0, 7, accuracy: 1e-9)
        XCTAssertEqual(project.highlights.first?.endInSeconds ?? 0, 22, accuracy: 1e-9)
    }

    func testWithoutSyncingOtherTracksAreLeftAlone() {
        let video = TestClips.video(start: 0, sourceEnd: 20)
        let music = TestClips.audio(start: 0, duration: 30)
        add(video, .main)
        add(music, .audio)

        project.removeRanges([5..<8], from: video.id, scope: .ownTracks)

        XCTAssertEqual(clips(.audio), [music])
    }

    @MainActor
    func testSyncedRemovalIsOneUndoStep() {
        let video = TestClips.video(start: 0, sourceEnd: 20)
        add(video, .main)
        add(TestClips.audio(start: 0, duration: 30), .audio)
        let store = ProjectStore(project: project)

        store.removeSilences([2..<4, 10..<12], from: video.id)
        store.undo()

        XCTAssertEqual(store.project.track(withRole: .main)!.clips.count, 1)
        XCTAssertEqual(store.project.track(withRole: .audio)!.clips.count, 1)
    }
}
