import XCTest

@testable import Clipsmith

final class PreviewControlsTests: XCTestCase {
    // MARK: PlaybackPosition

    func testFractionIsTheProgressThroughTheDuration() {
        let position = PlaybackPosition(currentInSeconds: 15, durationInSeconds: 60)

        XCTAssertEqual(position.fraction, 0.25, accuracy: 1e-9)
    }

    func testFractionNeverLeavesZeroToOne() {
        XCTAssertEqual(PlaybackPosition(currentInSeconds: 90, durationInSeconds: 60).fraction, 1)
        XCTAssertEqual(PlaybackPosition(currentInSeconds: -5, durationInSeconds: 60).fraction, 0)
    }

    func testAnEmptyDurationHasNoProgressAndCannotPlay() {
        let position = PlaybackPosition(currentInSeconds: 3, durationInSeconds: 0)

        XCTAssertEqual(position.fraction, 0)
        XCTAssertFalse(position.isPlayable)
    }

    func testTextShowsCurrentAndTotalTime() {
        let position = PlaybackPosition(currentInSeconds: 65, durationInSeconds: 125)

        XCTAssertEqual(position.text, "1:05 / 2:05")
    }

    func testDraggingTheScrubberMapsFractionsToTimes() {
        let position = PlaybackPosition(currentInSeconds: 0, durationInSeconds: 40)

        XCTAssertEqual(position.time(atFraction: 0.5), 20, accuracy: 1e-9)
        XCTAssertEqual(position.time(atFraction: 2), 40)
        XCTAssertEqual(position.time(atFraction: -1), 0)
    }

    func testSteppingStaysInsideTheClip() {
        let position = PlaybackPosition(currentInSeconds: 1, durationInSeconds: 10)

        XCTAssertEqual(position.time(offsetBy: 2), 3, accuracy: 1e-9)
        XCTAssertEqual(position.time(offsetBy: -5), 0)
        XCTAssertEqual(position.time(offsetBy: 99), 10)
    }

    // MARK: ControlsVisibility

    func testControlsStayVisibleWhilePaused() {
        XCTAssertTrue(ControlsVisibility(isPlaying: false, pointerIsIdle: true).isVisible)
        XCTAssertTrue(ControlsVisibility(isPlaying: false, pointerIsIdle: false).isVisible)
    }

    func testControlsHideOnlyWhenPlayingWithAnIdlePointer() {
        XCTAssertFalse(ControlsVisibility(isPlaying: true, pointerIsIdle: true).isVisible)
        XCTAssertTrue(ControlsVisibility(isPlaying: true, pointerIsIdle: false).isVisible)
    }

    // MARK: SafeAreaGuides

    func testGuidesAreCenteredInsideTheFrame() {
        let frame = CGRect(x: 10, y: 20, width: 1000, height: 500)

        let guides = SafeAreaGuides(in: frame)

        XCTAssertEqual(guides.actionSafe.midX, frame.midX, accuracy: 1e-9)
        XCTAssertEqual(guides.titleSafe.midY, frame.midY, accuracy: 1e-9)
        XCTAssertEqual(guides.verticalCenter, frame.midX)
        XCTAssertEqual(guides.horizontalCenter, frame.midY)
    }

    func testTitleSafeIsSmallerThanActionSafeWhichIsSmallerThanTheFrame() {
        let frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let guides = SafeAreaGuides(in: frame)

        XCTAssertLessThan(guides.titleSafe.width, guides.actionSafe.width)
        XCTAssertLessThan(guides.actionSafe.width, frame.width)
        XCTAssertEqual(guides.actionSafe.width / frame.width, SafeAreaGuides.actionSafeFraction)
        XCTAssertEqual(guides.titleSafe.height / frame.height, SafeAreaGuides.titleSafeFraction)
    }

    // MARK: PlayerController

    @MainActor
    func testSeekingOutsideTheTimelineUpdatesTheShownTime() {
        let player = PlayerController()
        player.showHighlight(nil)

        player.seek(to: 3)
        XCTAssertEqual(player.highlightTimeInSeconds, 3)

        player.seek(to: -4)
        XCTAssertEqual(player.highlightTimeInSeconds, 0)
    }

    @MainActor
    func testTheTimelineIsSeekedThroughThePlayheadNotThePlayer() {
        let player = PlayerController()

        player.seek(to: 7)

        XCTAssertEqual(player.highlightTimeInSeconds, 0)
        XCTAssertEqual(player.sourceTimeInSeconds, 0)
    }

    @MainActor
    func testShowingASourceStartsItAtZero() {
        let player = PlayerController()
        player.showSource(PreviewFixtures.mediaItem)

        XCTAssertEqual(player.sourceTimeInSeconds, 0)
        player.seek(to: 5)
        XCTAssertEqual(player.sourceTimeInSeconds, 5)
    }
}
