import Observation
import XCTest

@testable import Clipsmith

@MainActor
final class InspectorObservationTests: XCTestCase {
    private var store = ProjectStore(project: Project(name: "Vlog"))

    override func setUp() async throws {
        store = ProjectStore(project: Project(name: "Vlog"))
    }

    private func addClip(animated: Bool) throws -> Clip {
        let main = store.project.track(withRole: .main)!.id
        store.addMedia(TestClips.mediaItem(duration: 10), toTrack: main, at: 0)
        let id = try XCTUnwrap(store.selectedClipID)
        if animated {
            store.followPlayback(at: 2)
            store.addKeyframeAtPlayhead(to: id)
            store.followPlayback(at: 6)
            store.addKeyframeAtPlayhead(to: id)
        }
        return try XCTUnwrap(store.project.clip(withID: id))
    }

    private func playheadChangeIsObserved(reading read: () -> Void) -> Bool {
        var observed = false
        withObservationTracking(read) { observed = true }
        store.followPlayback(at: store.playheadInSeconds + 1)
        return observed
    }

    func testAStillClipDoesNotDependOnThePlayhead() throws {
        let clip = try addClip(animated: false)

        let observed = playheadChangeIsObserved { _ = store.clipForDisplay(clip) }

        XCTAssertFalse(observed)
    }

    func testAnAnimatedClipFollowsThePlayhead() throws {
        let clip = try addClip(animated: true)

        let observed = playheadChangeIsObserved { _ = store.clipForDisplay(clip) }

        XCTAssertTrue(observed)
    }

    func testAStillClipIsShownAsItIs() throws {
        let clip = try addClip(animated: false)

        XCTAssertEqual(store.clipForDisplay(clip), clip)
    }

    func testAnAnimatedClipIsShownWithTheValuesAtThePlayhead() throws {
        var clip = try addClip(animated: false)
        clip.keyframes = [
            Keyframe(timeInSeconds: 0, state: VisualState(scale: 1)),
            Keyframe(timeInSeconds: 10, state: VisualState(scale: 2)),
        ]
        store.followPlayback(at: 5)

        XCTAssertEqual(store.clipForDisplay(clip).scale, 1.5, accuracy: 1e-9)
    }
}
