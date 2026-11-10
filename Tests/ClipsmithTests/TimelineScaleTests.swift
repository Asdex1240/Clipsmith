import XCTest
@testable import Clipsmith

final class TimelineScaleTests: XCTestCase {
    func testTicksGetDenserWhenZoomingIn() {
        let zoomedIn = TimelineScale.tickInterval(pointsPerSecond: 400)
        let zoomedOut = TimelineScale.tickInterval(pointsPerSecond: 4)

        XCTAssertLessThan(zoomedIn, zoomedOut)
    }

    func testTicksAreAtLeastASeparationApart() {
        for pointsPerSecond in [4.0, 10, 40, 100, 400] {
            let interval = TimelineScale.tickInterval(pointsPerSecond: pointsPerSecond)

            XCTAssertGreaterThanOrEqual(interval * pointsPerSecond, 70)
        }
    }
}
