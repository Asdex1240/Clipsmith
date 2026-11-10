import AVFoundation
import AppKit
import XCTest
@testable import Clipsmith

final class ClipEffectsTests: XCTestCase {
    private var directory: URL!
    private var project = Project(name: "T")

    private var mainTrackID: Track.ID { project.track(withRole: .main)!.id }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        project = Project(name: "T")
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    // MARK: Model

    func testDefaultsChangeNothingAndPresetsDoNot() {
        XCTAssertTrue(ColorAdjustments().isIdentity)
        XCTAssertTrue(CropInsets().isNone)
        XCTAssertTrue(ColorPreset.none.adjustments.isIdentity)
        XCTAssertFalse(ColorPreset.blackAndWhite.adjustments.isIdentity)
        XCTAssertEqual(ColorPreset.blackAndWhite.adjustments.saturation, 0)
    }

    func testAdjustmentsAreClampedToTheirRanges() {
        let clamped = ColorAdjustments(brightness: 9, contrast: -3, saturation: 9, temperature: -9).clamped()

        XCTAssertEqual(clamped.brightness, ColorAdjustments.brightnessRange.upperBound)
        XCTAssertEqual(clamped.contrast, ColorAdjustments.contrastRange.lowerBound)
        XCTAssertEqual(clamped.saturation, ColorAdjustments.saturationRange.upperBound)
        XCTAssertEqual(clamped.temperature, ColorAdjustments.temperatureRange.lowerBound)
    }

    func testCropNeverRemovesMoreThanNinetyPercentOfAnAxis() {
        let clamped = CropInsets(left: 0.8, right: 0.8, top: -1, bottom: 0.2).clamped()

        XCTAssertEqual(clamped.left + clamped.right, CropInsets.maximumPerAxis, accuracy: 1e-9)
        XCTAssertEqual(clamped.top, 0)
        XCTAssertEqual(clamped.bottom, 0.2)
    }

    func testVisibleAreaIsTheRectWithoutTheCutSides() {
        let visible = CropInsets(left: 0.25, right: 0.25, top: 0.1, bottom: 0).visible(in: CGRect(x: 0, y: 0, width: 100, height: 100))

        XCTAssertEqual(visible, CGRect(x: 25, y: 10, width: 50, height: 90))
    }

    func testEffectsSurviveSavingAndOldFilesHaveNone() throws {
        var clip = TestClips.video(start: 0)
        clip.color = ColorPreset.warm.adjustments
        clip.crop = CropInsets(left: 0.1)

        let decoded = try JSONDecoder().decode(Clip.self, from: JSONEncoder().encode(clip))
        let plain = try JSONDecoder().decode(Clip.self, from: JSONEncoder().encode(TestClips.video(start: 0)))

        XCTAssertEqual(decoded.color, clip.color)
        XCTAssertEqual(decoded.crop, clip.crop)
        XCTAssertFalse(plain.hasLookEffects)
    }

    func testProjectSetsClampedEffects() {
        let clip = TestClips.video(start: 0)
        project.addClip(clip, toTrack: mainTrackID)

        project.setColor(of: clip.id, to: ColorAdjustments(brightness: 5))
        project.setCrop(of: clip.id, to: CropInsets(left: 2))

        let updated = project.clip(withID: clip.id)!
        XCTAssertEqual(updated.color.brightness, ColorAdjustments.brightnessRange.upperBound)
        XCTAssertEqual(updated.crop.left, CropInsets.maximumPerAxis)
        XCTAssertTrue(updated.hasLookEffects)
    }

    // MARK: Rendering

    private func solidPNG(_ color: NSColor, named name: String) throws -> URL {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 36, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        color.setFill()
        NSRect(x: 0, y: 0, width: 64, height: 36).fill()
        NSGraphicsContext.restoreGraphicsState()
        let url = directory.appendingPathComponent(name)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    private func builder() -> CompositionBuilder {
        CompositionBuilder(stillImages: StillImageVideoWriter(directory: directory.appendingPathComponent("stills")))
    }

    private func render(at time: TimeInterval = 0.5) async throws -> CGImage {
        let built = try await builder().build(from: project)
        XCTAssertTrue(built.skippedClipIDs.isEmpty)
        let generator = AVAssetImageGenerator(asset: built.composition)
        generator.videoComposition = built.videoComposition
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        return try await generator.image(at: time.cmTime).image
    }

    /// Red, green and blue (0 to 255) of the pixel at a fraction of the frame, with (0, 0) being the top left.
    private func pixel(_ image: CGImage, x fractionX: Double, y fractionY: Double) throws -> (r: Int, g: Int, b: Int) {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try XCTUnwrap(CGContext(
            data: &data, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let column = min(Int(fractionX * Double(image.width)), image.width - 1)
        let row = min(Int(fractionY * Double(image.height)), image.height - 1)
        let offset = (row * image.width + column) * 4
        return (Int(data[offset]), Int(data[offset + 1]), Int(data[offset + 2]))
    }

    private func addStill(_ url: URL, start: TimeInterval = 0, duration: TimeInterval = 3, edit: (inout Clip) -> Void = { _ in }) {
        var clip = Clip(sourceURL: url, mediaKind: .image, startInSeconds: start, sourceStartInSeconds: 0, sourceEndInSeconds: duration)
        edit(&clip)
        project.addClip(clip, toTrack: mainTrackID)
    }

    func testBrightnessLightensTheFrame() async throws {
        let gray = try solidPNG(NSColor(white: 0.4, alpha: 1), named: "gray.png")
        addStill(gray) { $0.color = ColorAdjustments(brightness: 0.3) }

        let center = try pixel(try await render(), x: 0.5, y: 0.5)

        XCTAssertGreaterThan(center.g, Int(0.4 * 255) + 40)
    }

    func testZeroSaturationTurnsColorIntoGray() async throws {
        let red = try solidPNG(NSColor(red: 1, green: 0, blue: 0, alpha: 1), named: "red.png")
        addStill(red)
        let colored = try pixel(try await render(), x: 0.5, y: 0.5)
        project = Project(name: "T")
        addStill(red) { $0.color = ColorPreset.blackAndWhite.adjustments }

        let gray = try pixel(try await render(), x: 0.5, y: 0.5)

        XCTAssertGreaterThan(colored.r - colored.b, 100)
        XCTAssertLessThan(abs(gray.r - gray.g), 12)
        XCTAssertLessThan(abs(gray.g - gray.b), 12)
    }

    func testWarmTemperatureAddsRedAndCoolAddsBlue() async throws {
        let gray = try solidPNG(NSColor(white: 0.5, alpha: 1), named: "mid.png")
        addStill(gray) { $0.color = ColorAdjustments(temperature: 0.8) }
        let warm = try pixel(try await render(), x: 0.5, y: 0.5)
        project = Project(name: "T")
        addStill(gray) { $0.color = ColorAdjustments(temperature: -0.8) }

        let cool = try pixel(try await render(), x: 0.5, y: 0.5)

        XCTAssertGreaterThan(warm.r, warm.b)
        XCTAssertGreaterThan(cool.b, cool.r)
    }

    func testCropRevealsWhatIsBehindTheCutSide() async throws {
        let white = try solidPNG(.white, named: "white.png")
        addStill(white) { $0.crop = CropInsets(left: 0.5) }

        let frame = try await render()

        XCTAssertLessThan(try pixel(frame, x: 0.25, y: 0.5).g, 20)
        XCTAssertGreaterThan(try pixel(frame, x: 0.75, y: 0.5).g, 235)
    }

    func testCropFromTheTopKeepsTheBottom() async throws {
        let white = try solidPNG(.white, named: "white.png")
        addStill(white) { $0.crop = CropInsets(top: 0.5) }

        let frame = try await render()

        XCTAssertLessThan(try pixel(frame, x: 0.5, y: 0.25).g, 20)
        XCTAssertGreaterThan(try pixel(frame, x: 0.5, y: 0.75).g, 235)
    }

    func testEffectsKeepTransitionsAndOpacityWorking() async throws {
        let white = try solidPNG(.white, named: "white.png")
        let black = try solidPNG(.black, named: "black.png")
        addStill(white)
        addStill(black, start: 3) {
            $0.transition = ClipTransition(kind: .dissolve, durationInSeconds: 1)
            $0.color = ColorAdjustments(saturation: 0.9)
        }

        let middle = try pixel(try await render(at: 3.5), x: 0.5, y: 0.5)
        let before = try pixel(try await render(at: 2), x: 0.5, y: 0.5)

        XCTAssertEqual(Double(middle.g) / 255, 0.5, accuracy: 0.2)
        XCTAssertGreaterThan(before.g, 235)
    }

    private func brightPixels(in image: CGImage, rows: Range<Double>) -> Int {
        let width = image.width
        let height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return -1 }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var count = 0
        for row in Int(rows.lowerBound * Double(height))..<Int(rows.upperBound * Double(height)) {
            for column in 0..<width {
                let offset = (row * width + column) * 4
                if data[offset] > 200, data[offset + 1] > 200, data[offset + 2] > 200 { count += 1 }
            }
        }
        return count
    }

    private func exportedFrame(withEffect: Bool) async throws -> CGImage {
        project = Project(name: "T")
        let black = try solidPNG(.black, named: "black.png")
        addStill(black, duration: 2) { if withEffect { $0.color = ColorAdjustments(saturation: 0.9) } }
        var text = TextLayer(content: "MMMMMM")
        text.fontSize = 220
        text.positionY = 0.2
        project.addTextClip(text, at: 0, duration: 2)
        let url = directory.appendingPathComponent("out-\(withEffect).mp4")

        try await ProjectExporter(builder: builder()).export(project, with: ExportPreset.landscape720.settings, to: url) { _ in }

        return try await AVAssetImageGenerator(asset: AVURLAsset(url: url)).image(at: 1.0.cmTime).image
    }

    func testExportedTextAppearsWithoutEffects() async throws {
        let frame = try await exportedFrame(withEffect: false)

        XCTAssertGreaterThan(brightPixels(in: frame, rows: 0.0..<0.45), 300)
    }

    func testExportedVideoStillShowsTextOverEffects() async throws {
        let frame = try await exportedFrame(withEffect: true)

        XCTAssertGreaterThan(brightPixels(in: frame, rows: 0.0..<0.45), 300)
        XCTAssertEqual(brightPixels(in: frame, rows: 0.55..<1.0), 0)
    }
}
