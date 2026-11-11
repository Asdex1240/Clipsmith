import XCTest

@testable import Clipsmith

final class DesignTokensTests: XCTestCase {
    func testSpacingScaleIsStrictlyIncreasing() {
        let scale = Design.Spacing.scale

        XCTAssertEqual(scale, scale.sorted())
        XCTAssertEqual(Set(scale).count, scale.count)
    }

    func testRadiusScaleIsStrictlyIncreasing() {
        let scale = Design.Radius.scale

        XCTAssertEqual(scale, scale.sorted())
        XCTAssertEqual(Set(scale).count, scale.count)
    }

    func testOpacitiesStayWithinZeroAndOne() {
        let opacities = [
            Design.Opacity.hitArea, Design.Opacity.subtleBorder, Design.Opacity.handle,
            Design.Opacity.scrim, Design.Opacity.clipFill, Design.Opacity.outline,
            Design.Opacity.emphasizedFill, Design.Opacity.waveform,
            Design.Opacity.selectedOutline, Design.Opacity.missingFill,
        ]

        XCTAssertTrue(opacities.allSatisfy { (0...1).contains($0) })
    }

    func testEveryMediaKindHasItsOwnClipFill() {
        let kinds: [MediaKind] = [.video, .image, .audio, .text]

        let fills = kinds.map { Palette.clipFill(for: $0) }

        for (index, fill) in fills.enumerated() {
            XCTAssertEqual(fills.filter { $0 == fill }.count, 1, "\(kinds[index]) repeats a fill")
        }
    }

    func testMissingClipFillDiffersFromEveryKindFill() {
        let kinds: [MediaKind] = [.video, .image, .audio, .text]

        XCTAssertFalse(kinds.contains { Palette.clipFill(for: $0) == Palette.missingClipFill })
    }
}
