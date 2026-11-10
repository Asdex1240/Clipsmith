import XCTest
@testable import Clipsmith

@MainActor
final class PlayheadNavigationTests: XCTestCase {
    private var store = ProjectStore(project: Project(name: "Test"))

    override func setUp() async throws {
        store = ProjectStore(project: Project(name: "Test"))
        store.appendToTimeline(TestClips.mediaItem(duration: 5))
        store.appendToTimeline(TestClips.mediaItem(duration: 5))
    }

    func testSteppingMovesByOneFrame() {
        store.stepPlayhead(byFrames: 3)

        XCTAssertEqual(store.playheadInSeconds, 3 * ProjectStore.frameDurationInSeconds, accuracy: 1e-9)
        store.stepPlayhead(byFrames: -3)
        XCTAssertEqual(store.playheadInSeconds, 0, accuracy: 1e-9)
    }

    func testPlayheadStaysInsideTheProject() {
        store.stepPlayhead(byFrames: -10)
        XCTAssertEqual(store.playheadInSeconds, 0)

        store.jumpPlayhead(bySeconds: 100)
        XCTAssertEqual(store.playheadInSeconds, 10)
    }

    func testJumpMovesBySeconds() {
        store.jumpPlayhead(bySeconds: 2)
        store.jumpPlayhead(bySeconds: -0.5)

        XCTAssertEqual(store.playheadInSeconds, 1.5, accuracy: 1e-9)
    }

    func testGoToStartAndEnd() {
        store.goToEnd()
        XCTAssertEqual(store.playheadInSeconds, 10)

        store.goToStart()
        XCTAssertEqual(store.playheadInSeconds, 0)
    }

    func testNextAndPreviousEditWalkThroughTheCuts() {
        store.goToNextEdit()
        XCTAssertEqual(store.playheadInSeconds, 5)

        store.goToNextEdit()
        XCTAssertEqual(store.playheadInSeconds, 10)

        store.goToNextEdit()
        XCTAssertEqual(store.playheadInSeconds, 10)

        store.goToPreviousEdit()
        XCTAssertEqual(store.playheadInSeconds, 5)

        store.goToPreviousEdit()
        XCTAssertEqual(store.playheadInSeconds, 0)

        store.goToPreviousEdit()
        XCTAssertEqual(store.playheadInSeconds, 0)
    }

    func testEditPointsFromTheMiddleOfAClip() {
        store.movePlayhead(to: 7)

        store.goToPreviousEdit()
        XCTAssertEqual(store.playheadInSeconds, 5)
    }

    func testNavigationDoesNotCreateUndoSteps() {
        store.undo()
        store.undo()
        XCTAssertFalse(store.canUndo)

        store.goToEnd()
        store.stepPlayhead(byFrames: -1)

        XCTAssertFalse(store.canUndo)
    }
}
