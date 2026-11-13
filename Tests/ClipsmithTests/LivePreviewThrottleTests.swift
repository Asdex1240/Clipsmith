import AVFoundation
import XCTest

@testable import Clipsmith

@MainActor
final class LivePreviewThrottleTests: XCTestCase {
    private var store = ProjectStore(project: Project(name: "Vlog"))
    private var builder = TimestampBuilder()
    private var previewer: TimelinePreviewer!
    private var clipID: Clip.ID!

    override func setUp() async throws {
        store = ProjectStore(project: Project(name: "Vlog"))
        builder = TimestampBuilder()
        previewer = TimelinePreviewer(store: store, player: PlayerController(), builder: builder)
        let main = store.project.track(withRole: .main)!.id
        store.addMedia(TestClips.mediaItem(duration: 30), toTrack: main, at: 0)
        clipID = try XCTUnwrap(store.selectedClipID)
        previewer.projectDidChange()
        for _ in 0..<300 where builder.times.isEmpty {
            try? await Task.sleep(for: .milliseconds(10))
        }
        try? await Task.sleep(for: .milliseconds(50))
    }

    private func dragASlider(for milliseconds: Int, every step: Int) async {
        var elapsed = 0
        var brightness = 0.0
        while elapsed < milliseconds {
            brightness += 0.001
            var color = ColorAdjustments()
            color.brightness = brightness
            store.setColor(of: clipID, to: color)
            previewer.projectDidChange()
            try? await Task.sleep(for: .milliseconds(step))
            elapsed += step
        }
        try? await Task.sleep(for: .milliseconds(300))
    }

    func testRapidLookEditsDoNotRebuildOnEveryChange() async {
        let before = builder.times.count

        await dragASlider(for: 500, every: 5)

        let builds = builder.times.count - before
        XCTAssertGreaterThan(builds, 0)
        XCTAssertLessThan(builds, 25, "\(builds) rebuilds for about 100 edits")
    }

    func testLiveRebuildsAreSpacedByTheLiveInterval() async {
        let before = builder.times.count

        await dragASlider(for: 500, every: 5)

        let stamps = Array(builder.times.dropFirst(before))
        let gaps = zip(stamps, stamps.dropFirst()).map { $1.timeIntervalSince($0) }
        let minimum = 0.05
        XCTAssertTrue(gaps.dropLast().allSatisfy { $0 >= minimum }, "gaps: \(gaps)")
    }

    func testTheFinalValueIsAlwaysBuilt() async throws {
        await dragASlider(for: 300, every: 5)

        let last = try XCTUnwrap(builder.projects.last)
        let built = last.tracks.flatMap(\.clips).first?.color.brightness ?? 0
        let current = store.project.tracks.flatMap(\.clips).first?.color.brightness ?? 1
        XCTAssertEqual(built, current, accuracy: 1e-9)
    }
}

private final class TimestampBuilder: CompositionBuilding, @unchecked Sendable {
    private let lock = NSLock()
    private var stamps: [Date] = []
    private var built: [Project] = []

    var times: [Date] { lock.withLock { stamps } }
    var projects: [Project] { lock.withLock { built } }

    func build(
        from project: Project, renderSize: CGSize, framesPerSecond: Int32
    ) async throws -> BuiltComposition {
        lock.withLock {
            stamps.append(Date())
            built.append(project)
        }
        return BuiltComposition(
            composition: AVMutableComposition(), videoComposition: nil, audioMix: nil,
            textOverlay: nil, skippedClipIDs: [])
    }
}
