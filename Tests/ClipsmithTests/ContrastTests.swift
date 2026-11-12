import AppKit
import XCTest

@testable import Clipsmith

final class ContrastTests: XCTestCase {
    func testBlackOnWhiteIsTheMaximumContrast() {
        XCTAssertEqual(ContrastRatio.ratio(.black, .white), 21, accuracy: 0.01)
    }

    func testAColorAgainstItselfHasNoContrast() {
        XCTAssertEqual(ContrastRatio.ratio(.white, .white), 1, accuracy: 1e-9)
    }

    func testRatioDoesNotDependOnTheOrder() {
        let tone = RGBAColor(hex: 0x157033)

        XCTAssertEqual(
            ContrastRatio.ratio(tone, .white), ContrastRatio.ratio(.white, tone), accuracy: 1e-9)
    }

    func testHexColorsAreDecoded() {
        let color = RGBAColor(hex: 0xFF8000)

        XCTAssertEqual(color.red, 1)
        XCTAssertEqual(color.green, 128.0 / 255, accuracy: 1e-9)
        XCTAssertEqual(color.blue, 0)
    }

    func testTheSystemOrangeAndGreenWouldFailOnALightBackground() {
        let orange = RGBAColor(hex: 0xFF9500)
        let green = RGBAColor(hex: 0x34C759)

        XCTAssertLessThan(ContrastRatio.ratio(orange, .white), ContrastRatio.minimumForText)
        XCTAssertLessThan(ContrastRatio.ratio(green, .white), ContrastRatio.minimumForText)
    }

    // MARK: Status tones

    private let lightBackgrounds = [RGBAColor(hex: 0xECECEC), .white, RGBAColor(hex: 0xE3E3E3)]
    private let darkBackgrounds = [
        RGBAColor(hex: 0x1E1E1E), RGBAColor(hex: 0x323232), RGBAColor(hex: 0x2B2B2B),
        RGBAColor(hex: 0x3A3A3A),
    ]

    private var tones: [(name: String, tone: AdaptiveTone)] {
        [
            ("success", Palette.successTone), ("warning", Palette.warningTone),
            ("invalid", Palette.invalidTone),
        ]
    }

    func testStatusTextIsReadableOnLightBackgrounds() {
        for (name, tone) in tones {
            for background in lightBackgrounds {
                XCTAssertGreaterThanOrEqual(
                    ContrastRatio.ratio(tone.light, background), ContrastRatio.minimumForText,
                    "\(name) in light mode")
            }
        }
    }

    func testStatusTextIsReadableOnDarkBackgrounds() {
        for (name, tone) in tones {
            for background in darkBackgrounds {
                XCTAssertGreaterThanOrEqual(
                    ContrastRatio.ratio(tone.dark, background), ContrastRatio.minimumForText,
                    "\(name) in dark mode")
            }
        }
    }

    func testStatusTextIsReadableOnTheRealSystemBackgrounds() throws {
        let appearances: [(NSAppearance.Name, KeyPath<AdaptiveTone, RGBAColor>)] = [
            (.aqua, \.light), (.darkAqua, \.dark),
        ]
        for (name, side) in appearances {
            let appearance = try XCTUnwrap(NSAppearance(named: name))
            for background in [NSColor.windowBackgroundColor, NSColor.controlBackgroundColor] {
                var resolved: NSColor?
                appearance.performAsCurrentDrawingAppearance {
                    resolved = background.usingColorSpace(.sRGB)
                }
                let color = try XCTUnwrap(resolved)
                let backdrop = RGBAColor(
                    red: color.redComponent, green: color.greenComponent,
                    blue: color.blueComponent)
                for (label, tone) in tones {
                    XCTAssertGreaterThanOrEqual(
                        ContrastRatio.ratio(tone[keyPath: side], backdrop),
                        ContrastRatio.minimumForText, "\(label) on \(name.rawValue)")
                }
            }
        }
    }
}
