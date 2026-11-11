import XCTest
@testable import Clipsmith

final class CanvasGeometryTests: XCTestCase {
    private let canvas = CGSize(width: 1920, height: 1080)

    func testSnappedAngleSticksToNearestStep() {
        XCTAssertEqual(CanvasGeometry.snappedAngle(43), 45)
    }

    func testSnappedAngleLeavesAnglesFarFromAStep() {
        XCTAssertEqual(CanvasGeometry.snappedAngle(20), 20)
    }

    func testSnappedAngleWrapsPastHalfTurn() {
        XCTAssertEqual(CanvasGeometry.snappedAngle(270), -90)
    }

    func testPullMovesNearestEdgeOntoBorder() {
        XCTAssertEqual(CanvasGeometry.pull(low: 5, high: 405, limit: 1920, reach: 10), -5)
    }

    func testPullIgnoresDistantFrames() {
        XCTAssertEqual(CanvasGeometry.pull(low: 100, high: 300, limit: 1920, reach: 10), 0)
    }

    func testEdgesCountOnlySidesBeingPushed() {
        let frame = CGRect(x: 0, y: 100, width: 200, height: 200)

        let edges = CanvasGeometry.edges(of: frame, moving: CGSize(width: -5, height: 0), in: canvas)

        XCTAssertEqual(edges, [.left])
    }

    func testCenteredAxesDetectCanvasCenter() {
        let frame = CGRect(x: 860, y: 100, width: 200, height: 200)

        XCTAssertEqual(CanvasGeometry.centeredAxes(of: frame, in: canvas), [.horizontal])
    }

    func testFittedRectCentersContentInContainer() {
        let fitted = CanvasGeometry.fittedRect(of: canvas, in: CGSize(width: 960, height: 960))

        XCTAssertEqual(fitted, CGRect(x: 0, y: 210, width: 960, height: 540))
    }
}
