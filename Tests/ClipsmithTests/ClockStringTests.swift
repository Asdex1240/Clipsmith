import XCTest
@testable import Clipsmith

final class ClockStringTests: XCTestCase {
    func testFormatsSecondsAsMinutesAndSeconds() {
        XCTAssertEqual(TimeInterval(0).clockString, "0:00")
        XCTAssertEqual(TimeInterval(9).clockString, "0:09")
        XCTAssertEqual(TimeInterval(75).clockString, "1:15")
    }

    func testIncludesHoursWhenNeeded() {
        XCTAssertEqual(TimeInterval(3_725).clockString, "1:02:05")
    }

    func testRoundsToNearestSecond() {
        XCTAssertEqual(TimeInterval(59.6).clockString, "1:00")
    }

    func testInvalidValuesFormatAsZero() {
        XCTAssertEqual(TimeInterval(-5).clockString, "0:00")
        XCTAssertEqual(TimeInterval.nan.clockString, "0:00")
        XCTAssertEqual(TimeInterval.infinity.clockString, "0:00")
    }
}
