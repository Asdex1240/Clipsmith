import AVFoundation
import XCTest

@testable import Clipsmith

final class PreviewQualityTests: XCTestCase {
    func testFullQualityUsesTheCanvasSize() {
        XCTAssertEqual(
            PreviewQuality.full.renderSize(for: .landscape), CGSize(width: 1920, height: 1080))
    }

    func testHalfAndQuarterScaleTheCanvas() {
        XCTAssertEqual(
            PreviewQuality.half.renderSize(for: .landscape), CGSize(width: 960, height: 540))
        XCTAssertEqual(
            PreviewQuality.quarter.renderSize(for: .portrait), CGSize(width: 270, height: 480))
    }

    func testSizesAreAlwaysEvenSoVideoCanEncodeThem() {
        let canvas = CanvasFormat(width: 1081, height: 1921)

        for quality in PreviewQuality.allCases {
            let size = quality.renderSize(for: canvas)

            XCTAssertEqual(Int(size.width) % 2, 0, "\(quality) width")
            XCTAssertEqual(Int(size.height) % 2, 0, "\(quality) height")
        }
    }

    func testTinyCanvasesNeverCollapseToZero() {
        let size = PreviewQuality.quarter.renderSize(for: CanvasFormat(width: 240, height: 240))

        XCTAssertGreaterThanOrEqual(size.width, 2)
        XCTAssertGreaterThanOrEqual(size.height, 2)
    }

    func testEveryQualityHasATranslatedTitle() {
        for quality in PreviewQuality.allCases {
            XCTAssertNotEqual(
                localized(String.LocalizationValue(quality.titleKey)), quality.titleKey)
        }
    }
}

@MainActor
final class PreviewSettingsTests: XCTestCase {
    private func freshDefaults() throws -> UserDefaults {
        let name = "preview-settings-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testQualityStartsFull() throws {
        XCTAssertEqual(PreviewSettings(defaults: try freshDefaults()).quality, .full)
    }

    func testTheChosenQualityIsRemembered() throws {
        let defaults = try freshDefaults()

        PreviewSettings(defaults: defaults).quality = .half

        XCTAssertEqual(PreviewSettings(defaults: defaults).quality, .half)
    }

    func testAnUnknownStoredValueFallsBackToFull() throws {
        let defaults = try freshDefaults()
        defaults.set("ultra", forKey: PreviewSettings.qualityKey)

        XCTAssertEqual(PreviewSettings(defaults: defaults).quality, .full)
    }

    func testThePreviewIsBuiltAtTheChosenQuality() async throws {
        let builder = SizeRecordingBuilder()
        let settings = PreviewSettings(defaults: try freshDefaults())
        let store = ProjectStore(project: Project(name: "Vlog"))
        let previewer = TimelinePreviewer(
            store: store, player: PlayerController(), builder: builder, settings: settings)

        settings.quality = .half
        previewer.qualityDidChange()
        for _ in 0..<300 where builder.sizes.isEmpty {
            try? await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(builder.sizes.last, CGSize(width: 960, height: 540))
    }
}

private final class SizeRecordingBuilder: CompositionBuilding, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [CGSize] = []

    var sizes: [CGSize] { lock.withLock { recorded } }

    func build(
        from project: Project, renderSize: CGSize, framesPerSecond: Int32
    ) async throws -> BuiltComposition {
        lock.withLock { recorded.append(renderSize) }
        return BuiltComposition(
            composition: AVMutableComposition(), videoComposition: nil, audioMix: nil,
            textOverlay: nil, skippedClipIDs: [])
    }
}
