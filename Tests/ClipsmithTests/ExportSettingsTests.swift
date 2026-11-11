import XCTest
@testable import Clipsmith

final class ExportSettingsTests: XCTestCase {
    func testRenderSizeFollowsResolutionAndCanvas() {
        XCTAssertEqual(
            ExportResolution.hd1080.renderSize(for: .landscape), CGSize(width: 1920, height: 1080))
        XCTAssertEqual(
            ExportResolution.hd1080.renderSize(for: .portrait), CGSize(width: 1080, height: 1920))
        XCTAssertEqual(
            ExportResolution.uhd4K.renderSize(for: .landscape), CGSize(width: 3840, height: 2160))
        XCTAssertEqual(
            ExportResolution.uhd4K.renderSize(for: .portrait), CGSize(width: 2160, height: 3840))
    }

    func testPresetsDefineCanvasAndSettings() {
        XCTAssertEqual(ExportPreset.youtube1080.canvas, .landscape)
        XCTAssertEqual(ExportPreset.youtube4K.settings.codec, .hevc)
        XCTAssertEqual(ExportPreset.vertical1080.canvas, .portrait)
        XCTAssertEqual(ExportPreset.vertical1080.settings.resolution, .hd1080)
    }

    func testMatchingPresetFindsTheExactCombination() {
        let preset = ExportPreset.matching(
            settings: ExportPreset.youtube4K.settings, canvas: .landscape)

        XCTAssertEqual(preset, .youtube4K)
    }

    func testMatchingPresetIsNilForCustomSettings() {
        var settings = ExportPreset.youtube1080.settings
        settings.framesPerSecond = 24

        XCTAssertNil(ExportPreset.matching(settings: settings, canvas: .landscape))
        XCTAssertNil(
            ExportPreset.matching(settings: ExportPreset.youtube4K.settings, canvas: .portrait))
    }

    func testEveryPresetIsDistinguishable() {
        for preset in ExportPreset.allCases {
            XCTAssertEqual(
                ExportPreset.matching(settings: preset.settings, canvas: preset.canvas), preset)
        }
    }
}
