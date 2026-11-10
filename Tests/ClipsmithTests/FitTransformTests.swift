import XCTest
@testable import Clipsmith

final class FitTransformTests: XCTestCase {
    private let landscape = CGSize(width: 1920, height: 1080)
    private let portrait = CGSize(width: 1080, height: 1920)

    func testScaleGrowsTheClipAroundTheCanvasCenter() {
        let transform = FitTransform.make(
            naturalSize: landscape, preferredTransform: .identity, renderSize: landscape, scale: 0.5
        )

        let rect = CGRect(origin: .zero, size: landscape).applying(transform)

        assertEqual(rect, CGRect(x: 480, y: 270, width: 960, height: 540))
    }

    func testOffsetMovesTheClipAfterScaling() {
        let transform = FitTransform.make(
            naturalSize: landscape, preferredTransform: .identity, renderSize: landscape,
            offset: CGPoint(x: 100, y: -50), scale: 0.5
        )

        let rect = CGRect(origin: .zero, size: landscape).applying(transform)

        assertEqual(rect, CGRect(x: 580, y: 220, width: 960, height: 540))
    }

    func testNinetyDegreeRotationTurnsTheClipClockwiseAroundTheCenter() {
        let transform = FitTransform.make(
            naturalSize: landscape, preferredTransform: .identity, renderSize: landscape, rotationInDegrees: 90
        )

        let topLeft = CGPoint.zero.applying(transform)

        XCTAssertEqual(topLeft.x, 1500, accuracy: 0.001)
        XCTAssertEqual(topLeft.y, -420, accuracy: 0.001)
    }

    func testMatchingAspectRatioFillsTheCanvas() {
        let transform = FitTransform.make(naturalSize: landscape, preferredTransform: .identity, renderSize: landscape)

        let rect = CGRect(origin: .zero, size: landscape).applying(transform)

        assertEqual(rect, CGRect(origin: .zero, size: landscape))
    }

    func testLandscapeVideoIsLetterboxedInAPortraitCanvas() {
        let transform = FitTransform.make(naturalSize: landscape, preferredTransform: .identity, renderSize: portrait)

        let rect = CGRect(origin: .zero, size: landscape).applying(transform)

        assertEqual(rect, CGRect(x: 0, y: (1920 - 607.5) / 2, width: 1080, height: 607.5))
    }

    func testPortraitVideoIsPillarboxedInALandscapeCanvas() {
        let transform = FitTransform.make(naturalSize: portrait, preferredTransform: .identity, renderSize: landscape)

        let rect = CGRect(origin: .zero, size: portrait).applying(transform)

        assertEqual(rect, CGRect(x: (1920 - 607.5) / 2, y: 0, width: 607.5, height: 1080))
    }

    func testRotatedIPhoneFootageEndsUpUprightAndCentred() {
        let rotate90 = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)

        let transform = FitTransform.make(naturalSize: landscape, preferredTransform: rotate90, renderSize: portrait)

        let rect = CGRect(origin: .zero, size: landscape).applying(transform)
        assertEqual(rect, CGRect(origin: .zero, size: portrait))
    }

    private func assertEqual(_ actual: CGRect, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.minX, expected.minX, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(actual.minY, expected.minY, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(actual.width, expected.width, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(actual.height, expected.height, accuracy: 0.01, file: file, line: line)
    }
}
