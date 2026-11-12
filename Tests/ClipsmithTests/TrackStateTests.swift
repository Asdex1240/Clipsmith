import AVFoundation
import XCTest

@testable import Clipsmith

final class TrackStateTests: XCTestCase {
    private var project = Project(name: "Vlog")
    private var main: Track.ID { project.track(withRole: .main)!.id }
    private var broll: Track.ID { project.track(withRole: .broll)!.id }
    private var audio: Track.ID { project.track(withRole: .audio)!.id }
    private var text: Track.ID { project.track(withRole: .text)!.id }

    override func setUp() {
        project = Project(name: "Vlog")
    }

    private func video(at start: TimeInterval = 0) -> Clip {
        TestClips.video(start: start, sourceEnd: 10)
    }

    // MARK: Toggles and persistence

    func testNewTracksAreUnmutedVisibleAndUnlocked() {
        XCTAssertTrue(project.tracks.allSatisfy { !$0.isMuted && !$0.isHidden && !$0.isLocked })
    }

    func testTogglesFlipTheFlagsAndFlipBack() {
        project.toggleMute(ofTrack: audio)
        project.toggleVisibility(ofTrack: main)
        project.toggleLock(ofTrack: text)

        XCTAssertTrue(project.track(withRole: .audio)!.isMuted)
        XCTAssertTrue(project.track(withRole: .main)!.isHidden)
        XCTAssertTrue(project.track(withRole: .text)!.isLocked)

        project.toggleMute(ofTrack: audio)
        XCTAssertFalse(project.track(withRole: .audio)!.isMuted)
    }

    func testOnlyTracksThatMakeSenseCanBeMutedOrHidden() {
        project.toggleMute(ofTrack: text)
        project.toggleVisibility(ofTrack: audio)

        XCTAssertFalse(project.track(withRole: .text)!.isMuted)
        XCTAssertFalse(project.track(withRole: .audio)!.isHidden)
    }

    func testFlagsSurviveEncodingAndAreOmittedWhenOff() throws {
        project.toggleLock(ofTrack: main)

        let data = try JSONEncoder().encode(project)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        let decoded = try JSONDecoder().decode(Project.self, from: data)

        XCTAssertEqual(json.components(separatedBy: "isLocked").count - 1, 1)
        XCTAssertFalse(json.contains("isMuted"))
        XCTAssertEqual(decoded, project)
    }

    func testTracksFromOlderFilesDecodeWithoutFlags() throws {
        let json = """
            {"id":"\(UUID())","role":"main","clips":[]}
            """

        let track = try JSONDecoder().decode(Track.self, from: Data(json.utf8))

        XCTAssertFalse(track.isMuted || track.isHidden || track.isLocked)
    }

    // MARK: Playback

    func testMutedTrackPlaysSilentWithoutChangingTheProject() {
        project.addClip(video(), toTrack: main)
        project.toggleMute(ofTrack: main)

        let rendered = project.renderedForPlayback

        XCTAssertEqual(rendered.track(withRole: .main)?.clips.first?.volume, 0)
        XCTAssertEqual(project.track(withRole: .main)?.clips.first?.volume, 1)
    }

    func testHiddenVideoTrackIsFullyTransparent() {
        var clip = video()
        clip.keyframes = [Keyframe(timeInSeconds: 0, state: VisualState(opacity: 1))]
        project.addClip(clip, toTrack: broll)
        project.toggleVisibility(ofTrack: broll)

        let hidden = project.renderedForPlayback.track(withRole: .broll)?.clips.first

        XCTAssertEqual(hidden?.opacity, 0)
        XCTAssertEqual(hidden?.keyframes.first?.state.opacity, 0)
    }

    func testHiddenTextTrackDrawsNothingButKeepsItsLength() {
        project.addTextClip(TextLayer(content: "Hola"), at: 0, duration: 8)
        project.toggleVisibility(ofTrack: text)

        let rendered = project.renderedForPlayback

        XCTAssertNil(rendered.track(withRole: .text)?.clips.first?.textLayer)
        XCTAssertEqual(rendered.durationInSeconds, project.durationInSeconds)
    }

    func testHiddenMainTrackKeepsPlayingItsAudio() {
        project.addClip(video(), toTrack: main)
        project.toggleVisibility(ofTrack: main)

        XCTAssertEqual(project.renderedForPlayback.track(withRole: .main)?.clips.first?.volume, 1)
    }

    func testMutingATrackSilencesItInTheBuiltAudioMix() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100 * 3))
        buffer.frameLength = 44_100 * 3
        try AVAudioFile(forWriting: url, settings: format.settings).write(from: buffer)
        let sound = Clip(
            sourceURL: url, mediaKind: .audio, startInSeconds: 0, sourceStartInSeconds: 0,
            sourceEndInSeconds: 3, sourceDurationInSeconds: 3)
        project.addClip(sound, toTrack: audio)
        project.toggleMute(ofTrack: audio)

        let built = try await CompositionBuilder().build(from: project)

        let parameters = try XCTUnwrap(built.audioMix?.inputParameters.first)
        var start: Float = -1
        var end: Float = -1
        var range = CMTimeRange.zero
        _ = parameters.getVolumeRamp(
            for: 1.0.cmTime, startVolume: &start, endVolume: &end, timeRange: &range)
        XCTAssertEqual(start, 0, accuracy: 0.001)
        XCTAssertEqual(end, 0, accuracy: 0.001)
    }

    // MARK: Locking

    func testLockedTrackRejectsNewClips() {
        project.toggleLock(ofTrack: main)

        XCTAssertFalse(project.addClip(video(), toTrack: main))
        XCTAssertTrue(project.addClip(video(), toTrack: broll))
    }

    func testLockedClipsCannotBeMovedTrimmedSplitOrDeleted() {
        let clip = video(at: 2)
        project.addClip(clip, toTrack: main)
        project.toggleLock(ofTrack: main)
        let before = project

        project.moveClip(clip.id, toTrack: broll, startingAt: 5)
        project.trimClip(clip.id, edge: .trailing, to: 8)
        project.splitClip(clip.id, at: 5)
        project.deleteClip(clip.id)
        project.deleteClips([clip.id])
        project.rippleDeleteClip(clip.id)
        project.rippleDeleteClips([clip.id])

        XCTAssertEqual(project, before)
    }

    func testClipsCannotBeMovedOntoALockedTrack() {
        let clip = video()
        project.addClip(clip, toTrack: main)
        project.toggleLock(ofTrack: broll)

        XCTAssertFalse(project.moveClip(clip.id, toTrack: broll, startingAt: 1))
        XCTAssertNotNil(project.track(withRole: .main)?.clips.first)
    }

    func testClipSettingsOnALockedTrackAreIgnored() {
        let clip = video()
        project.addClip(clip, toTrack: main)
        project.toggleLock(ofTrack: main)

        project.setVolume(of: clip.id, to: 0.2)
        project.setFadeIn(of: clip.id, to: 1)

        XCTAssertEqual(project.clip(withID: clip.id)?.volume, 1)
        XCTAssertEqual(project.clip(withID: clip.id)?.fadeInDurationInSeconds, 0)
    }

    func testMovingSeveralClipsLeavesTheLockedOnesInPlace() {
        let locked = video(at: 0)
        let free = TestClips.audio(start: 0, duration: 4)
        project.addClip(locked, toTrack: main)
        project.addClip(free, toTrack: audio)
        project.toggleLock(ofTrack: main)

        project.moveClips([locked.id, free.id], by: 3)

        XCTAssertEqual(project.clip(withID: locked.id)?.startInSeconds, 0)
        XCTAssertEqual(project.clip(withID: free.id)?.startInSeconds, 3)
    }

    func testUnlockedTracksKeepWorkingNormally() {
        let locked = video()
        let free = TestClips.audio(start: 0, duration: 6)
        project.addClip(locked, toTrack: main)
        project.addClip(free, toTrack: audio)
        project.toggleLock(ofTrack: main)

        project.deleteClips([locked.id, free.id])

        XCTAssertNotNil(project.clip(withID: locked.id))
        XCTAssertNil(project.clip(withID: free.id))
    }

    func testNewTextGoesToAnUnlockedTrack() {
        let original = text
        let extra = project.addTrack(role: .text)!
        project.toggleLock(ofTrack: original)

        let placed = project.trackWithRoom(role: .text, start: 0, duration: 2)

        XCTAssertEqual(placed?.id, extra)
    }

    @MainActor
    func testStoreCommandsToggleTheFlagsWithUndo() {
        let store = ProjectStore(project: project)

        store.toggleLock(ofTrack: main)
        XCTAssertTrue(store.project.isTrackLocked(main))

        store.undo()
        XCTAssertFalse(store.project.isTrackLocked(main))
    }
}
