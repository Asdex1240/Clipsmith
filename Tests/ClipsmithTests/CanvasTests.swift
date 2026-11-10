import AppKit
import XCTest
@testable import Clipsmith

final class CanvasFormatTests: XCTestCase {
    func testPresetsHaveTheirAspectLabel() {
        XCTAssertEqual(CanvasFormat.landscape.aspectLabel, "16:9")
        XCTAssertEqual(CanvasFormat.portrait.aspectLabel, "9:16")
        XCTAssertEqual(CanvasFormat.square.aspectLabel, "1:1")
        XCTAssertEqual(CanvasFormat.portrait4x5.aspectLabel, "4:5")
        XCTAssertEqual(CanvasFormat.portrait3x4.aspectLabel, "3:4")
        XCTAssertEqual(CanvasFormat.landscape4x3.aspectLabel, "4:3")
        XCTAssertEqual(CanvasFormat.ultrawide.aspectLabel, "21:9")
    }

    func testUncommonProportionHasNoLabelAndIsSummarisedAsCustom() {
        let canvas = CanvasFormat(width: 1000, height: 1000 * 2)

        XCTAssertEqual(canvas.aspectLabel, nil)
        XCTAssertTrue(canvas.summary.hasSuffix("1000×2000"))
    }

    func testSizesAreClampedAndMadeEven() {
        XCTAssertEqual(CanvasFormat(width: 1921, height: 1081), CanvasFormat(width: 1920, height: 1080))
        XCTAssertEqual(CanvasFormat(width: 10, height: 99_999).width, CanvasFormat.minimumSide)
        XCTAssertEqual(CanvasFormat(width: 10, height: 99_999).height, CanvasFormat.maximumSide)
    }

    func testScalingKeepsTheProportion() {
        XCTAssertEqual(CanvasFormat.landscape.scaled(toShortSide: 2160), CanvasFormat(width: 3840, height: 2160))
        XCTAssertEqual(CanvasFormat.portrait.scaled(toShortSide: 720), CanvasFormat(width: 720, height: 1280))
        XCTAssertEqual(CanvasFormat.square.scaled(toShortSide: 1440), CanvasFormat(width: 1440, height: 1440))
        XCTAssertEqual(CanvasFormat.portrait4x5.scaled(toShortSide: 2160), CanvasFormat(width: 2160, height: 2700))
    }

    func testFittingMapsCommonVideoSizesToPresets() {
        XCTAssertEqual(CanvasFormat.fitting(CGSize(width: 3840, height: 2160)), .landscape)
        XCTAssertEqual(CanvasFormat.fitting(CGSize(width: 1080, height: 1920)), .portrait)
        XCTAssertEqual(CanvasFormat.fitting(CGSize(width: 1080, height: 1080)), .square)
        XCTAssertEqual(CanvasFormat.fitting(CGSize(width: 2160, height: 3840)), .portrait)
    }

    func testFittingAnUnusualSizeCapsTheShortSideAt1080() {
        let canvas = CanvasFormat.fitting(CGSize(width: 2000, height: 1000))

        XCTAssertEqual(canvas, CanvasFormat(width: 2160, height: 1080))
    }

    func testFittingRejectsInvalidSizes() {
        XCTAssertNil(CanvasFormat.fitting(.zero))
    }

    func testRoundTripsThroughJSON() throws {
        let canvas = CanvasFormat(width: 1280, height: 720)

        let data = try JSONEncoder().encode(canvas)

        XCTAssertEqual(try JSONDecoder().decode(CanvasFormat.self, from: data), canvas)
    }

    func testDecodesTheFormatsSavedByEarlierVersions() throws {
        let landscape = try JSONDecoder().decode(CanvasFormat.self, from: Data(#""landscape""#.utf8))
        let portrait = try JSONDecoder().decode(CanvasFormat.self, from: Data(#""portrait""#.utf8))

        XCTAssertEqual(landscape, .landscape)
        XCTAssertEqual(portrait, .portrait)
    }
}

final class ExportResolutionTests: XCTestCase {
    func testShortSideDefinesTheOutputForAnyProportion() {
        XCTAssertEqual(ExportResolution.hd720.renderSize(for: .landscape), CGSize(width: 1280, height: 720))
        XCTAssertEqual(ExportResolution.qhd1440.renderSize(for: .landscape), CGSize(width: 2560, height: 1440))
        XCTAssertEqual(ExportResolution.hd1080.renderSize(for: .square), CGSize(width: 1080, height: 1080))
        XCTAssertEqual(ExportResolution.uhd4K.renderSize(for: .portrait4x5), CGSize(width: 2160, height: 2700))
    }

    func testCanvasSizeExportsExactlyTheCanvas() {
        let canvas = CanvasFormat(width: 1234, height: 876)

        XCTAssertEqual(ExportResolution.canvasSize.renderSize(for: canvas), canvas.renderSize)
    }

    func testPresetMatchesAnyCanvasWithTheSameProportion() {
        let settings = ExportPreset.youtube4K.settings

        XCTAssertEqual(ExportPreset.matching(settings: settings, canvas: .landscape.scaled(toShortSide: 2160)), .youtube4K)
        XCTAssertNil(ExportPreset.matching(settings: settings, canvas: .square))
    }
}

final class FillFitTransformTests: XCTestCase {
    func testFillCoversThePortraitCanvasWithLandscapeFootage() {
        let landscape = CGSize(width: 1920, height: 1080)
        let portrait = CGSize(width: 1080, height: 1920)

        let transform = FitTransform.make(naturalSize: landscape, preferredTransform: .identity, renderSize: portrait, mode: .fill)

        let rect = CGRect(origin: .zero, size: landscape).applying(transform)
        XCTAssertEqual(rect.height, 1920, accuracy: 0.001)
        XCTAssertEqual(rect.midX, 540, accuracy: 0.001)
        XCTAssertEqual(rect.midY, 960, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(rect.width, 1080)
    }

    func testFitIsStillTheDefault() {
        let size = CGSize(width: 1920, height: 1080)
        let render = CGSize(width: 1080, height: 1920)

        XCTAssertEqual(
            FitTransform.make(naturalSize: size, preferredTransform: .identity, renderSize: render),
            FitTransform.make(naturalSize: size, preferredTransform: .identity, renderSize: render, mode: .fit)
        )
    }
}

@MainActor
final class CanvasStoreTests: XCTestCase {
    private func item(_ width: Double, _ height: Double, kind: MediaKind = .video) -> MediaItem {
        var item = TestClips.mediaItem(kind: kind)
        item.pixelSize = CGSize(width: width, height: height)
        return item
    }

    func testCanvasTakesTheProportionOfTheFirstVideo() {
        let store = ProjectStore(project: Project(name: "Test"))

        store.appendToTimeline(item(1080, 1920))

        XCTAssertEqual(store.project.canvas, .portrait)
    }

    func testOnlyTheFirstClipChangesTheCanvas() {
        let store = ProjectStore(project: Project(name: "Test"))

        store.appendToTimeline(item(1080, 1920))
        store.appendToTimeline(item(1920, 1080))

        XCTAssertEqual(store.project.canvas, .portrait)
    }

    func testAudioAndTextDoNotCountAsTheFirstClip() {
        let store = ProjectStore(project: Project(name: "Test"))

        store.appendToTimeline(TestClips.mediaItem(kind: .audio))
        store.addTextAtPlayhead()
        store.appendToTimeline(item(1080, 1080))

        XCTAssertEqual(store.project.canvas, .square)
    }

    func testAutoFitCanBeSwitchedOff() {
        let store = ProjectStore(project: Project(name: "Test"))

        store.setAutoFitCanvas(false)
        store.appendToTimeline(item(1080, 1920))

        XCTAssertEqual(store.project.canvas, .landscape)
    }

    func testMediaWithoutKnownSizeLeavesTheCanvasAlone() {
        let store = ProjectStore(project: Project(name: "Test"))

        store.appendToTimeline(TestClips.mediaItem())

        XCTAssertEqual(store.project.canvas, .landscape)
    }

    func testUndoRestoresTheCanvasTogetherWithTheClip() {
        let store = ProjectStore(project: Project(name: "Test"))
        store.appendToTimeline(item(1080, 1920))

        store.undo()

        XCTAssertEqual(store.project.canvas, .landscape)
        XCTAssertFalse(store.project.hasVisualClips)
    }

    func testCustomCanvasSizeIsStoredAndUndoable() {
        let store = ProjectStore(project: Project(name: "Test"))

        store.setCanvas(CanvasFormat(width: 1280, height: 720))
        XCTAssertEqual(store.project.canvas.renderSize, CGSize(width: 1280, height: 720))

        store.undo()
        XCTAssertEqual(store.project.canvas, .landscape)
    }

    func testFitModeIsPerClipAndUndoable() {
        let store = ProjectStore(project: Project(name: "Test"))
        store.appendToTimeline(TestClips.mediaItem())
        let id = store.project.track(withRole: .main)!.clips[0].id

        store.setFitMode(of: id, to: .fill)
        XCTAssertEqual(store.project.clip(withID: id)?.fitMode, .fill)

        store.undo()
        XCTAssertEqual(store.project.clip(withID: id)?.fitMode, .fit)
    }
}

final class CanvasCodingTests: XCTestCase {
    func testProjectSavedBeforeCanvasSizesStillLoads() throws {
        let legacy = """
        {"id":"\(UUID().uuidString)","name":"Old","canvas":"portrait","tracks":[]}
        """

        let project = try JSONDecoder().decode(Project.self, from: Data(legacy.utf8))

        XCTAssertEqual(project.canvas, .portrait)
        XCTAssertTrue(project.autoFitCanvas)
    }

    func testClipSavedBeforeFitModeDefaultsToFit() throws {
        let legacy = """
        {"id":"\(UUID().uuidString)","mediaKind":"video","startInSeconds":0,
         "sourceStartInSeconds":0,"sourceEndInSeconds":4,"volume":1,
         "fadeInDurationInSeconds":0,"fadeOutDurationInSeconds":0}
        """

        let clip = try JSONDecoder().decode(Clip.self, from: Data(legacy.utf8))

        XCTAssertEqual(clip.fitMode, .fit)
    }

    func testProjectRoundTripKeepsCanvasAutoFitAndFitMode() throws {
        var project = Project(name: "Round trip")
        project.canvas = CanvasFormat(width: 1280, height: 720)
        project.autoFitCanvas = false
        var clip = TestClips.video(start: 0)
        clip.fitMode = .fill
        project.tracks[2].clips = [clip]

        let decoded = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(project))

        XCTAssertEqual(decoded, project)
    }
}

final class MediaPixelSizeTests: XCTestCase {
    func testImagesReportTheirPixelSize() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("photo.png")
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 120, pixelsHigh: 80, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)

        let item = try await AVMediaLoader().loadItem(from: url)

        XCTAssertEqual(item.pixelSize, CGSize(width: 120, height: 80))
    }

    func testPixelSizeSurvivesSavingTheLibrary() throws {
        var item = TestClips.mediaItem()
        item.pixelSize = CGSize(width: 1080, height: 1920)

        let decoded = try JSONDecoder().decode(MediaItem.self, from: JSONEncoder().encode(item))

        XCTAssertEqual(decoded.pixelSize, item.pixelSize)
    }

    func testAudioHasNoPixelSize() {
        XCTAssertNil(TestClips.mediaItem(kind: .audio).pixelSize)
    }
}
