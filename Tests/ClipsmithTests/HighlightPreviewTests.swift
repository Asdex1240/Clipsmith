import AVFoundation
import XCTest

@testable import Clipsmith

@MainActor
final class HighlightPreviewTests: XCTestCase {
    private var store = ProjectStore(project: Project(name: "Vlog"))
    private var player = PlayerController()
    private var builder = RecordingBuilder()
    private var preview: HighlightPreviewController!
    private var highlightID: Highlight.ID!

    override func setUp() async throws {
        store = ProjectStore(project: Project(name: "Vlog"))
        let main = store.project.track(withRole: .main)!.id
        store.addMedia(TestClips.mediaItem(duration: 60), toTrack: main, at: 0)
        highlightID = try XCTUnwrap(store.addHighlight(from: 10, to: 20))
        player = PlayerController()
        builder = RecordingBuilder()
        preview = HighlightPreviewController(store: store, player: player, builder: builder)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<300 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func testShowingBuildsTheVerticalProjectOfTheHighlight() async throws {
        preview.show(highlightID)
        await waitUntil { self.player.hasHighlight }

        let built = try XCTUnwrap(builder.projects.last)
        XCTAssertEqual(built.canvas, .portrait)
        XCTAssertEqual(built.durationInSeconds, 10, accuracy: 1e-9)
        XCTAssertEqual(player.mode, .highlight)
        XCTAssertEqual(player.highlightDurationInSeconds, 10, accuracy: 1e-9)
    }

    func testTheRealTimelineIsLeftUntouched() async {
        let before = store.project

        preview.show(highlightID)
        await waitUntil { self.player.hasHighlight }

        XCTAssertEqual(store.project, before)
    }

    func testARangeWithNothingInItShowsNothing() async throws {
        let empty = try XCTUnwrap(store.addHighlight(from: 100, to: 110))

        preview.show(empty)
        await waitUntil { self.player.mode == .highlight }

        XCTAssertEqual(player.mode, .highlight)
        XCTAssertFalse(player.hasHighlight)
    }

    func testUnknownHighlightsAreIgnored() {
        preview.show(UUID())

        XCTAssertNil(preview.requestedID)
        XCTAssertEqual(player.mode, .timeline)
    }

    func testClosingGoesBackToTheTimeline() async {
        preview.show(highlightID)
        await waitUntil { self.player.hasHighlight }

        preview.close()

        XCTAssertEqual(player.mode, .timeline)
        XCTAssertNil(preview.requestedID)
        XCTAssertFalse(preview.isShowing(highlightID))
    }

    func testIsShowingReflectsTheActiveHighlight() async throws {
        let other = try XCTUnwrap(store.addHighlight(from: 30, to: 40))
        preview.show(highlightID)
        await waitUntil { self.player.hasHighlight }

        XCTAssertTrue(preview.isShowing(highlightID))
        XCTAssertFalse(preview.isShowing(other))
    }

    func testChangingTheFramingRebuildsThePreview() async throws {
        preview.show(highlightID)
        await waitUntil { self.player.hasHighlight }
        let builds = builder.projects.count

        store.setHighlightFraming(highlightID, offsetX: 0.5)
        preview.projectDidChange()
        await waitUntil { self.builder.projects.count > builds }

        let rebuilt = try XCTUnwrap(builder.projects.last)
        XCTAssertEqual(rebuilt.track(withRole: .main)?.clips.first?.offsetX, 0.5)
    }

    func testDeletingTheHighlightClosesThePreview() async {
        preview.show(highlightID)
        await waitUntil { self.player.hasHighlight }

        store.removeHighlight(highlightID)
        preview.projectDidChange()

        XCTAssertEqual(player.mode, .timeline)
        XCTAssertNil(preview.requestedID)
    }

    func testLeavingThePreviewElsewhereForgetsTheHighlight() async {
        preview.show(highlightID)
        await waitUntil { self.player.hasHighlight }

        player.showTimeline(at: 0)
        preview.projectDidChange()

        XCTAssertNil(preview.requestedID)
    }

    func testChangesWithoutAPreviewDoNotBuildAnything() {
        store.setHighlightFraming(highlightID, offsetX: 0.3)

        preview.projectDidChange()

        XCTAssertTrue(builder.projects.isEmpty)
    }

    func testRebuildingKeepsTheCurrentPositionInsideTheNewLength() async throws {
        let first = await RecordingBuilder.composition(seconds: 10)
        let shorter = await RecordingBuilder.composition(seconds: 4)
        player.showHighlight(first)
        player.showHighlight(shorter)

        XCTAssertEqual(player.highlightDurationInSeconds, 4, accuracy: 1e-9)
        XCTAssertLessThanOrEqual(player.highlightTimeInSeconds, 4)
    }
}

private final class RecordingBuilder: CompositionBuilding, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [Project] = []

    var projects: [Project] { lock.withLock { recorded } }

    static func composition(seconds: TimeInterval) async -> BuiltComposition? {
        guard seconds > 0, let url = silentWav(seconds: seconds) else { return nil }
        let asset = AVURLAsset(url: url)
        guard let source = try? await asset.loadTracks(withMediaType: .audio).first else {
            return nil
        }
        let composition = AVMutableComposition()
        let track = composition.addMutableTrack(
            withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        try? track?.insertTimeRange(
            CMTimeRange(start: .zero, duration: seconds.cmTime), of: source, at: .zero)
        return BuiltComposition(
            composition: composition, videoComposition: nil, audioMix: nil, textOverlay: nil,
            skippedClipIDs: [])
    }

    private static func silentWav(seconds: TimeInterval) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).wav")
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1),
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format, frameCapacity: AVAudioFrameCount(44_100 * seconds)),
            let file = try? AVAudioFile(forWriting: url, settings: format.settings)
        else { return nil }
        buffer.frameLength = buffer.frameCapacity
        try? file.write(from: buffer)
        return url
    }

    private static func emptyComposition() -> BuiltComposition {
        BuiltComposition(
            composition: AVMutableComposition(), videoComposition: nil, audioMix: nil,
            textOverlay: nil, skippedClipIDs: [])
    }

    func build(
        from project: Project, renderSize: CGSize, framesPerSecond: Int32
    ) async throws -> BuiltComposition {
        lock.withLock { recorded.append(project) }
        let built = await Self.composition(seconds: project.durationInSeconds)
        return built ?? Self.emptyComposition()
    }
}
