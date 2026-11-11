import XCTest

@testable import Clipsmith

final class ParameterUnitTests: XCTestCase {
    func testPercentShowsFractionAsWholePercent() {
        XCTAssertEqual(ParameterUnit.percent.text(for: 0.5), "50%")
    }

    func testSecondsShowsOneDecimal() {
        XCTAssertEqual(ParameterUnit.seconds.text(for: 1.25), "1.2 s")
    }

    func testDegreesAndPointsKeepTheirSuffix() {
        XCTAssertEqual(ParameterUnit.degrees.text(for: 45), "45°")
        XCTAssertEqual(ParameterUnit.points.text(for: 72), "72 pt")
    }

    func testMultiplierShowsTwoDecimals() {
        XCTAssertEqual(ParameterUnit.multiplier.text(for: 1.5), "1.50×")
    }

    func testSignedNumberAlwaysShowsTheSign() {
        XCTAssertEqual(ParameterUnit.signedNumber.text(for: 0.25), "+25")
        XCTAssertEqual(ParameterUnit.signedNumber.text(for: -0.25), "-25")
    }

    func testTypedPercentConvertsBackToFraction() {
        let value = ParameterUnit.percent.value(fromDisplay: 150, in: 0...2)

        XCTAssertEqual(value, 1.5, accuracy: 1e-9)
    }

    func testTypedValueIsClampedToTheRange() {
        XCTAssertEqual(ParameterUnit.percent.value(fromDisplay: 500, in: 0...2), 2)
        XCTAssertEqual(ParameterUnit.percent.value(fromDisplay: -20, in: 0...2), 0)
    }

    func testDisplayAndTypedValuesRoundTrip() {
        let display = ParameterUnit.percent.displayValue(0.8)

        XCTAssertEqual(
            ParameterUnit.percent.value(fromDisplay: display, in: 0...2), 0.8, accuracy: 1e-9)
    }
}
