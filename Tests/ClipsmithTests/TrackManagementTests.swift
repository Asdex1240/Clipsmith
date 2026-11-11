import AVFoundation
import AppKit
import XCTest
@testable import Clipsmith

final class TrackManagementTests: XCTestCase {
    private var project = Project(name: "T")

    override func setUp() {
        project = Project(name: "T")
    }

    private var roles: [Track.Role] { project.tracks.map(\.role) }

    // MARK: Adding and removing

    func testNewProjectsStartWithOneTrackOfEachKind() {
        XCTAssertEqual(roles, [.text, .broll, .main, .audio])
    }

    func testVideoTracksAreAddedAboveTheOthers() {
        let added = project.addTrack(role: .broll)

        XCTAssertEqual(roles, [.text, .broll, .broll, .main, .audio])
        XCTAssertEqual(project.tracks[1].id, added)
        XCTAssertEqual(project.videoTracksTopFirst.first?.id, added)
    }

    func testAudioTracksGoBelowAndTextTracksOnTop() {
        let audio = project.addTrack(role: .audio)
        let text = project.addTrack(role: .text)

        XCTAssertEqual(roles, [.text, .text, .broll, .main, .audio, .audio])
        XCTAssertEqual(project.tracks.last?.id, audio)
        XCTAssertEqual(project.tracks.first?.id, text)
    }

    func testThereIsOnlyOneMainTrack() {
        XCTAssertNil(project.addTrack(role: .main))
        XCTAssertEqual(roles.filter { $0 == .main }.count, 1)
    }

    func testTheMainTrackAndTheLastOfEachKindCannotBeRemoved() {
        for track in project.tracks {
            XCTAssertFalse(project.canRemoveTrack(track.id))
        }
        let extra = project.addTrack(role: .audio)!

        XCTAssertTrue(project.canRemoveTrack(extra))
        project.removeTrack(extra)
        XCTAssertEqual(roles, [.text, .broll, .main, .audio])
        project.removeTrack(project.track(withRole: .main)!.id)
        XCTAssertEqual(roles, [.text, .broll, .main, .audio])
    }

    func testRemovingATrackRemovesItsClips() {
        let extra = project.addTrack(role: .broll)!
        let clip = TestClips.video(start: 0)
        project.addClip(clip, toTrack: extra)

        project.removeTrack(extra)

        XCTAssertNil(project.clip(withID: clip.id))
    }

    // MARK: Ordering

    func testTracksSwapWithTheNearestOneOfTheSameKind() {
        let top = project.addTrack(role: .broll)!
        let original = project.tracks(withRole: .broll).first { $0.id != top }!.id
        XCTAssertTrue(project.canMoveTrack(top, direction: .down))
        XCTAssertFalse(project.canMoveTrack(top, direction: .up))

        project.moveTrack(top, direction: .down)

        XCTAssertEqual(
            project.tracks.map(\.id).filter { [top, original].contains($0) }, [original, top])
        XCTAssertEqual(roles, [.text, .broll, .broll, .main, .audio])
    }

    func testTracksNeverMoveAcrossKinds() {
        XCTAssertFalse(project.canMoveTrack(project.track(withRole: .audio)!.id, direction: .up))
        XCTAssertFalse(project.canMoveTrack(project.track(withRole: .text)!.id, direction: .down))
    }

    func testMainCanBeRaisedAboveAnOverlayTrack() {
        project.moveTrack(project.track(withRole: .main)!.id, direction: .up)

        XCTAssertEqual(roles, [.text, .main, .broll, .audio])
        XCTAssertEqual(project.videoTracksTopFirst.first?.role, .main)
    }

    func testNamesAndTitles() {
        let second = project.addTrack(role: .broll)!
        let first = project.track(withRole: .broll)!
        XCTAssertEqual(
            project.title(of: project.tracks.first { $0.id == second }!),
            "\(Track.Role.broll.title) 1")
        XCTAssertEqual(project.title(of: project.track(withRole: .main)!), Track.Role.main.title)

        project.renameTrack(first.id, to: "  Logos ")
        XCTAssertEqual(project.title(of: project.tracks.first { $0.id == first.id }!), "Logos")
        project.renameTrack(first.id, to: "   ")
        XCTAssertNil(project.tracks.first { $0.id == first.id }?.name)
    }

    func testTracksSurviveSavingWithTheirNames() throws {
        let extra = project.addTrack(role: .text)!
        project.renameTrack(extra, to: "Captions")

        let decoded = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(project))

        XCTAssertEqual(decoded.tracks.map(\.role), project.tracks.map(\.role))
        XCTAssertEqual(decoded.tracks.first { $0.id == extra }?.name, "Captions")
    }

    // MARK: Using several tracks

    func testTextGoesToTheNextTextTrackWhenTheFirstIsBusy() {
        project.addTrack(role: .text)
        let first = project.addTextClip(TextLayer(content: "A"), at: 0, duration: 3)!
        let second = project.addTextClip(TextLayer(content: "B"), at: 1, duration: 3)!

        let textTracks = project.tracks(withRole: .text)
        XCTAssertEqual(textTracks[0].clips.map(\.id), [first])
        XCTAssertEqual(textTracks[1].clips.map(\.id), [second])
        XCTAssertEqual(project.clip(withID: second)?.startInSeconds, 1)
    }

    func testDetachedSoundGoesToAFreeAudioTrack() throws {
        let video = TestClips.video(start: 0, sourceEnd: 5)
        project.addClip(video, toTrack: project.track(withRole: .main)!.id)
        project.addClip(
            TestClips.audio(start: 0, duration: 8), toTrack: project.track(withRole: .audio)!.id)
        XCTAssertFalse(project.canDetachAudio(ofClip: video.id))

        let extra = project.addTrack(role: .audio)!

        XCTAssertTrue(project.canDetachAudio(ofClip: video.id))
        let detached = try XCTUnwrap(project.detachAudio(ofClip: video.id))
        let extraTrack = try XCTUnwrap(project.tracks.first { $0.id == extra })
        XCTAssertEqual(extraTrack.clips.map(\.id), [detached])
    }

    // MARK: Rendering

    private func solidPNG(_ color: NSColor, in directory: URL, named name: String) throws -> URL {
        let bitmap = try XCTUnwrap(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 36, bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
                bitsPerPixel: 0
            ))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        color.setFill()
        NSRect(x: 0, y: 0, width: 64, height: 36).fill()
        NSGraphicsContext.restoreGraphicsState()
        let url = directory.appendingPathComponent(name)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    func testTheTrackHigherInTheListIsDrawnOnTop() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let white = try solidPNG(.white, in: directory, named: "white.png")
        let black = try solidPNG(.black, in: directory, named: "black.png")
        func still(_ url: URL) -> Clip {
            Clip(
                sourceURL: url, mediaKind: .image, startInSeconds: 0, sourceStartInSeconds: 0,
                sourceEndInSeconds: 3)
        }
        project.addClip(still(black), toTrack: project.track(withRole: .main)!.id)
        project.addClip(still(white), toTrack: project.track(withRole: .broll)!.id)
        let top = project.addTrack(role: .broll)!
        let middle = project.tracks(withRole: .broll).first { $0.id != top }!
        let builder = CompositionBuilder(
            stillImages: StillImageVideoWriter(directory: directory.appendingPathComponent("s")))

        func brightness(of project: Project) async throws -> Double {
            let built = try await builder.build(from: project)
            XCTAssertTrue(built.skippedClipIDs.isEmpty)
            let generator = AVAssetImageGenerator(asset: built.composition)
            generator.videoComposition = built.videoComposition
            return try KeyframeTests.brightness(of: try await generator.image(at: 1.0.cmTime).image)
        }

        let whiteOnTop = try await brightness(of: project)
        project.moveTrack(project.track(withRole: .main)!.id, direction: .up)
        project.moveTrack(project.track(withRole: .main)!.id, direction: .up)
        let mainOnTop = try await brightness(of: project)

        XCTAssertGreaterThan(whiteOnTop, 0.9)
        XCTAssertLessThan(mainOnTop, 0.1)
        XCTAssertNotNil(middle)
    }

    func testClipsOnTwoOverlayTracksAreBothDrawn() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let white = try solidPNG(.white, in: directory, named: "white.png")
        let extra = project.addTrack(role: .broll)!
        var overlay = Clip(
            sourceURL: white, mediaKind: .image, startInSeconds: 0, sourceStartInSeconds: 0,
            sourceEndInSeconds: 3)
        overlay.opacity = 0.5
        project.addClip(overlay, toTrack: extra)
        project.addClip(
            Clip(
                sourceURL: white, mediaKind: .image, startInSeconds: 0, sourceStartInSeconds: 0,
                sourceEndInSeconds: 3),
            toTrack: project.track(withRole: .main)!.id
        )
        let builder = CompositionBuilder(
            stillImages: StillImageVideoWriter(directory: directory.appendingPathComponent("s")))

        let built = try await builder.build(from: project)

        XCTAssertTrue(built.skippedClipIDs.isEmpty)
        XCTAssertEqual(built.composition.tracks(withMediaType: .video).count, 2)
        let instruction = try XCTUnwrap(
            built.videoComposition?.instructions.first as? AVVideoCompositionInstruction)
        XCTAssertEqual(instruction.layerInstructions.count, 2)
    }

    func testTwoAudioTracksMakeTwoMixTracks() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("tone.wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100 * 3))
        buffer.frameLength = 44_100 * 3
        try AVAudioFile(forWriting: url, settings: format.settings).write(from: buffer)
        func sound() -> Clip {
            Clip(
                sourceURL: url, mediaKind: .audio, startInSeconds: 0, sourceStartInSeconds: 0,
                sourceEndInSeconds: 3, sourceDurationInSeconds: 3
            )
            .settingVolume(0.5)
        }
        let extra = project.addTrack(role: .audio)!
        project.addClip(sound(), toTrack: project.track(withRole: .audio)!.id)
        project.addClip(sound(), toTrack: extra)

        let built = try await CompositionBuilder().build(from: project)

        XCTAssertEqual(built.composition.tracks(withMediaType: .audio).count, 2)
        XCTAssertEqual(built.audioMix?.inputParameters.count, 2)
        XCTAssertEqual(built.durationInSeconds, 3, accuracy: 0.05)
    }
}
