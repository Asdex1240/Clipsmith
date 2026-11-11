import XCTest
@testable import Clipsmith

final class SnappingTests: XCTestCase {
    func testSnapsToNearestCandidateWithinThreshold() {
        XCTAssertEqual(Snapping.snap(4.9, to: [0, 5, 10], within: 0.2), 5)
    }

    func testKeepsValueWhenNoCandidateIsCloseEnough() {
        XCTAssertEqual(Snapping.snap(4.5, to: [0, 5, 10], within: 0.2), 4.5)
    }

    func testWithoutCandidatesKeepsValue() {
        XCTAssertEqual(Snapping.snap(3, to: [], within: 1), 3)
    }

    func testSnapStartAlignsClipStartToCandidate() {
        XCTAssertEqual(Snapping.snapStart(9.9, duration: 3, to: [10], within: 0.2), 10)
    }

    func testSnapStartAlignsClipEndToCandidate() {
        XCTAssertEqual(
            Snapping.snapStart(6.9, duration: 3, to: [10], within: 0.2), 7, accuracy: 1e-9)
    }

    func testSnapStartPicksTheCloserEdge() {
        let snapped = Snapping.snapStart(9.95, duration: 5, to: [10, 15.3], within: 0.5)

        XCTAssertEqual(snapped, 10, accuracy: 1e-9)
    }

    func testSnapStartKeepsAnAlreadyAlignedStart() {
        XCTAssertEqual(Snapping.snapStart(10, duration: 3, to: [10, 13.1], within: 0.5), 10)
    }
}
