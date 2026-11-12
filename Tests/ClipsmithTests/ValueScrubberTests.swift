import XCTest

@testable import Clipsmith

final class ValueScrubberTests: XCTestCase {
    func testDraggingTheFullDistanceCoversTheWholeRange() {
        let value = ValueScrubber.value(
            startingAt: 0, dragging: ValueScrubber.pointsForFullRange, in: 0...2)

        XCTAssertEqual(value, 2, accuracy: 1e-9)
    }

    func testDraggingLeftLowersTheValue() {
        let value = ValueScrubber.value(startingAt: 1, dragging: -150, in: 0...2)

        XCTAssertEqual(value, 0, accuracy: 1e-9)
    }

    func testTheValueNeverLeavesTheRange() {
        XCTAssertEqual(ValueScrubber.value(startingAt: 1.9, dragging: 900, in: 0...2), 2)
        XCTAssertEqual(ValueScrubber.value(startingAt: 0.1, dragging: -900, in: 0...2), 0)
    }

    func testFineSpeedMovesTenTimesLess() {
        let normal = ValueScrubber.value(startingAt: 0, dragging: 30, in: 0...1)
        let fine = ValueScrubber.value(startingAt: 0, dragging: 30, in: 0...1, speed: .fine)

        XCTAssertEqual(fine * 10, normal, accuracy: 1e-9)
    }

    func testNoDragLeavesTheValueAlone() {
        XCTAssertEqual(ValueScrubber.value(startingAt: 0.7, dragging: 0, in: 0...1), 0.7)
    }

    func testNegativeRangesWork() {
        let value = ValueScrubber.value(startingAt: 0, dragging: 150, in: -180...180)

        XCTAssertEqual(value, 180, accuracy: 1e-9)
    }
}
