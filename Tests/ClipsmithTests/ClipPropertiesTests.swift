import XCTest
@testable import Clipsmith

final class ClipPropertiesTests: XCTestCase {
    private var project = Project(name: "Test")

    private var mainTrackID: Track.ID { project.track(withRole: .main)!.id }
    private var textTrackID: Track.ID { project.track(withRole: .text)!.id }
    private var mainClips: [Clip] { project.track(withRole: .main)!.clips }
    private var textClips: [Clip] { project.track(withRole: .text)!.clips }

    override func setUp() {
        project = Project(name: "Test")
    }

    func testVolumeIsClampedBetweenZeroAndTheMaximum() {
        let clip = TestClips.video(start: 0)
        project.addClip(clip, toTrack: mainTrackID)

        project.setVolume(of: clip.id, to: 5)
        XCTAssertEqual(mainClips[0].volume, Clip.maximumVolume)

        project.setVolume(of: clip.id, to: -1)
        XCTAssertEqual(mainClips[0].volume, 0)

        project.setVolume(of: clip.id, to: 0.5)
        XCTAssertEqual(mainClips[0].volume, 0.5)
    }

    func testFadeInAndOutCannotExceedTheClipDuration() {
        let clip = TestClips.video(start: 0, sourceEnd: 10)
        project.addClip(clip, toTrack: mainTrackID)

        project.setFadeIn(of: clip.id, to: 7)
        project.setFadeOut(of: clip.id, to: 7)

        XCTAssertEqual(mainClips[0].fadeInDurationInSeconds, 7)
        XCTAssertEqual(mainClips[0].fadeOutDurationInSeconds, 3)
    }

    func testNegativeFadesBecomeZero() {
        let clip = TestClips.video(start: 0)
        project.addClip(clip, toTrack: mainTrackID)

        project.setFadeIn(of: clip.id, to: -2)

        XCTAssertEqual(mainClips[0].fadeInDurationInSeconds, 0)
    }

    func testSplitKeepsFadeInOnTheLeftAndFadeOutOnTheRight() {
        let clip = TestClips.video(start: 0, sourceEnd: 10)
        project.addClip(clip, toTrack: mainTrackID)
        project.setFadeIn(of: clip.id, to: 2)
        project.setFadeOut(of: clip.id, to: 2)

        project.splitClip(clip.id, at: 5)

        XCTAssertEqual(mainClips[0].fadeInDurationInSeconds, 2)
        XCTAssertEqual(mainClips[0].fadeOutDurationInSeconds, 0)
        XCTAssertEqual(mainClips[1].fadeInDurationInSeconds, 0)
        XCTAssertEqual(mainClips[1].fadeOutDurationInSeconds, 2)
    }

    func testSplitKeepsTheVolumeOnBothHalves() {
        let clip = TestClips.video(start: 0, sourceEnd: 10)
        project.addClip(clip, toTrack: mainTrackID)
        project.setVolume(of: clip.id, to: 0.3)

        project.splitClip(clip.id, at: 5)

        XCTAssertEqual(mainClips.map(\.volume), [0.3, 0.3])
    }

    func testTrimmingShrinksFadesThatNoLongerFit() {
        let clip = TestClips.video(start: 0, sourceEnd: 10)
        project.addClip(clip, toTrack: mainTrackID)
        project.setFadeIn(of: clip.id, to: 4)
        project.setFadeOut(of: clip.id, to: 4)

        project.trimClip(clip.id, edge: .trailing, to: 5)

        XCTAssertEqual(mainClips[0].fadeInDurationInSeconds, 4)
        XCTAssertEqual(mainClips[0].fadeOutDurationInSeconds, 1)
    }

    func testTextClipLivesOnTheTextTrackOnly() {
        let layer = TextLayer(content: "Hello")

        XCTAssertNotNil(project.addTextClip(layer, at: 2, duration: 3))
        let textClip = Clip(text: layer, startInSeconds: 0, durationInSeconds: 3)

        XCTAssertFalse(project.addClip(textClip, toTrack: mainTrackID))
        XCTAssertEqual(textClips.count, 1)
        XCTAssertEqual(textClips[0].mediaKind, .text)
        XCTAssertEqual(textClips[0].startInSeconds, 2)
        XCTAssertEqual(textClips[0].displayName, "Hello")
    }

    func testMediaCannotBeDroppedOnTheTextTrack() {
        XCTAssertFalse(project.addClip(TestClips.video(start: 0), toTrack: textTrackID))
    }

    func testOverlappingTextClipsAreSeparated() {
        project.addTextClip(TextLayer(content: "A"), at: 0, duration: 3)
        project.addTextClip(TextLayer(content: "B"), at: 1, duration: 3)

        XCTAssertEqual(textClips.map(\.startInSeconds), [0, 3])
    }

    func testUpdatingTheTextLayerChangesOnlyTheRequestedFields() throws {
        let id = try XCTUnwrap(project.addTextClip(TextLayer(content: "Old"), at: 0, duration: 3))

        project.updateTextLayer(of: id) {
            $0.content = "New"
            $0.fontSize = 120
        }

        let layer = try XCTUnwrap(textClips[0].textLayer)
        XCTAssertEqual(layer.content, "New")
        XCTAssertEqual(layer.fontSize, 120)
        XCTAssertEqual(layer.fontName, TextLayer.defaultFontName)
    }

    func testTextClipsCanBeSplitAndKeepTheirText() throws {
        let id = try XCTUnwrap(project.addTextClip(TextLayer(content: "Hello"), at: 0, duration: 6))

        XCTAssertTrue(project.splitClip(id, at: 2))

        XCTAssertEqual(textClips.map(\.displayName), ["Hello", "Hello"])
        XCTAssertEqual(textClips.map(\.durationInSeconds), [2, 4])
    }

    func testTextClipCanBeStretchedFreely() throws {
        let id = try XCTUnwrap(project.addTextClip(TextLayer(content: "Hello"), at: 0, duration: 3))

        project.trimClip(id, edge: .trailing, to: 30)

        XCTAssertEqual(textClips[0].durationInSeconds, 30)
    }

    func testTrackRoleOfAClipIsFound() throws {
        let clip = TestClips.video(start: 0)
        project.addClip(clip, toTrack: mainTrackID)

        XCTAssertEqual(project.trackRole(ofClip: clip.id), .main)
        XCTAssertNil(project.trackRole(ofClip: UUID()))
    }

    func testOnlyMainAndAudioTracksPlayAudio() {
        XCTAssertTrue(Track.Role.main.playsAudio)
        XCTAssertTrue(Track.Role.audio.playsAudio)
        XCTAssertFalse(Track.Role.broll.playsAudio)
        XCTAssertFalse(Track.Role.text.playsAudio)
    }
}
