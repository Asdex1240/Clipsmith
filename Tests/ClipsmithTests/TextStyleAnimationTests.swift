import AVFoundation
import AppKit
import XCTest
@testable import Clipsmith

final class TextStyleAnimationTests: XCTestCase {
    // MARK: Animation math

    func testAnimationNoneLeavesTheTextAlone() {
        XCTAssertEqual(TextAnimation().state(atClipTime: 0, clipDuration: 3), .identity)
        XCTAssertTrue(TextAnimation().isNone)
    }

    func testFadeInStartsInvisibleAndEndsOpaque() {
        let animation = TextAnimation(inKind: .fade, durationInSeconds: 0.5)

        XCTAssertEqual(animation.state(atClipTime: 0, clipDuration: 4).opacity, 0, accuracy: 1e-9)
        XCTAssertEqual(animation.state(atClipTime: 0.5, clipDuration: 4).opacity, 1, accuracy: 1e-9)
        XCTAssertEqual(animation.state(atClipTime: 3.9, clipDuration: 4).opacity, 1, accuracy: 1e-9)
    }

    func testFadeOutEndsInvisible() {
        let animation = TextAnimation(outKind: .fade, durationInSeconds: 0.5)

        XCTAssertEqual(animation.state(atClipTime: 1, clipDuration: 4).opacity, 1, accuracy: 1e-9)
        XCTAssertLessThan(animation.state(atClipTime: 3.99, clipDuration: 4).opacity, 0.2)
        XCTAssertEqual(animation.state(atClipTime: 4, clipDuration: 4).opacity, 0, accuracy: 1e-9)
    }

    func testSlidesMoveTowardsTheirRestingPlace() {
        let up = TextAnimation(inKind: .slideUp, durationInSeconds: 1)
        let down = TextAnimation(inKind: .slideDown, durationInSeconds: 1)

        XCTAssertGreaterThan(up.state(atClipTime: 0.1, clipDuration: 5).offsetY, 0)
        XCTAssertLessThan(down.state(atClipTime: 0.1, clipDuration: 5).offsetY, 0)
        XCTAssertEqual(up.state(atClipTime: 1, clipDuration: 5).offsetY, 0, accuracy: 1e-9)
    }

    func testPopGrowsFromASmallerSize() {
        let pop = TextAnimation(inKind: .pop, durationInSeconds: 1)

        XCTAssertLessThan(pop.state(atClipTime: 0, clipDuration: 5).scale, 0.8)
        XCTAssertEqual(pop.state(atClipTime: 1, clipDuration: 5).scale, 1, accuracy: 1e-9)
    }

    func testShortTextsSplitTheirTimeBetweenInAndOut() {
        let animation = TextAnimation(inKind: .fade, outKind: .fade, durationInSeconds: 2)

        // A clip of 1 s can spend at most half a second on each side, so the middle is fully visible.
        XCTAssertEqual(animation.state(atClipTime: 0.5, clipDuration: 1).opacity, 1, accuracy: 1e-9)
        XCTAssertEqual(animation.state(atClipTime: 0, clipDuration: 1).opacity, 0, accuracy: 1e-9)
    }

    func testSamplePointsCoverTheStartTheEndAndTheFades() {
        let animation = TextAnimation(inKind: .fade, outKind: .fade, durationInSeconds: 0.3)

        let points = animation.samplePoints(clipDuration: 3)

        XCTAssertEqual(points.first, 0)
        XCTAssertEqual(points.last, 3)
        XCTAssertTrue(points.contains(0.3))
        XCTAssertTrue(points.contains(2.7))
        XCTAssertEqual(points, points.sorted())
    }

    // MARK: Style

    func testPresetsSetOnlyTheStyle() {
        var layer = TextLayer(content: "Hi", fontSize: 90, positionY: 0.3)

        TextStylePreset.boxed.apply(to: &layer)

        XCTAssertNotNil(layer.backgroundColor)
        XCTAssertFalse(layer.hasShadow)
        XCTAssertEqual(layer.content, "Hi")
        XCTAssertEqual(layer.fontSize, 90)
        XCTAssertEqual(layer.positionY, 0.3)

        TextStylePreset.highlight.apply(to: &layer)
        XCTAssertNil(layer.backgroundColor)
        XCTAssertGreaterThan(layer.strokeWidth, 0)
        XCTAssertNotEqual(layer.color, .white)

        TextStylePreset.classic.apply(to: &layer)
        XCTAssertEqual(layer.strokeWidth, 0)
        XCTAssertTrue(layer.hasShadow)
        XCTAssertEqual(layer.color, .white)
    }

    func testStyleAndAnimationSurviveSavingAndOldFilesLookTheSame() throws {
        var layer = TextLayer(content: "Hi")
        TextStylePreset.boxed.apply(to: &layer)
        layer.animation = TextAnimation(inKind: .pop, outKind: .fade, durationInSeconds: 0.6)
        XCTAssertEqual(try JSONDecoder().decode(TextLayer.self, from: JSONEncoder().encode(layer)), layer)

        let plain = TextLayer(content: "Hi")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(plain)) as? [String: Any])
        XCTAssertNil(json["animation"])
        XCTAssertNil(json["hasShadow"])
        json["rotationInDegrees"] = nil
        let legacy = try JSONDecoder().decode(TextLayer.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy, plain)
        XCTAssertTrue(legacy.hasShadow)
    }

    func testSubtitlesUseTheChosenStyleAndAnimation() {
        var project = Project(name: "T")

        project.addSubtitles(
            [SubtitleLine(text: "Hola", startInSeconds: 0, endInSeconds: 2)],
            style: .outlined, animation: .both(.fade)
        )

        let layer = project.track(withRole: .text)!.clips.first!.textLayer!
        XCTAssertGreaterThan(layer.strokeWidth, 0)
        XCTAssertEqual(layer.animation, .both(.fade))
    }

    // MARK: Rendering

    private func sprite(for layer: TextLayer) throws -> TextSprite {
        let clip = Clip(text: layer, startInSeconds: 0, durationInSeconds: 3)
        let overlay = TextOverlay(clips: [clip], renderSize: CGSize(width: 1280, height: 720))
        return try XCTUnwrap(TextOverlayLayers.makeSprites(for: overlay).first)
    }

    private func pixels(of image: CGImage) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = CGContext(
            data: &data, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return data
    }

    private func opaquePixelCount(in image: CGImage, where match: (UInt8, UInt8, UInt8) -> Bool = { _, _, _ in true }) -> Int {
        let data = pixels(of: image)
        return stride(from: 0, to: data.count, by: 4).filter { data[$0 + 3] > 200 && match(data[$0], data[$0 + 1], data[$0 + 2]) }.count
    }

    func testBackgroundBoxAddsOpaquePixelsBehindTheText() throws {
        var plain = TextLayer(content: "Hello")
        plain.hasShadow = false
        var boxed = plain
        boxed.backgroundColor = RGBAColor(red: 0, green: 0, blue: 1, alpha: 1)

        let withoutBox = opaquePixelCount(in: try sprite(for: plain).image)
        let withBox = opaquePixelCount(in: try sprite(for: boxed).image)
        let blue = opaquePixelCount(in: try sprite(for: boxed).image) { red, _, blue in blue > 200 && red < 60 }

        XCTAssertGreaterThan(withBox, withoutBox * 3)
        XCTAssertGreaterThan(blue, 1000)
    }

    func testOutlineDrawsPixelsOfTheOutlineColor() throws {
        var layer = TextLayer(content: "Hello")
        layer.hasShadow = false
        layer.color = .white
        layer.strokeWidth = TextLayer.outlinedStrokeWidth
        layer.strokeColor = RGBAColor(red: 1, green: 0, blue: 0)

        let red = opaquePixelCount(in: try sprite(for: layer).image) { red, green, _ in red > 200 && green < 60 }

        XCTAssertGreaterThan(red, 200)
    }

    func testTurningOffTheShadowRemovesTheSoftEdge() throws {
        var shadowed = TextLayer(content: "Hello")
        shadowed.hasShadow = true
        var flat = shadowed
        flat.hasShadow = false

        func translucent(_ layer: TextLayer) throws -> Int {
            let data = pixels(of: try sprite(for: layer).image)
            return stride(from: 3, to: data.count, by: 4).filter { data[$0] > 5 && data[$0] < 200 }.count
        }

        let withShadow = try translucent(shadowed)
        let withoutShadow = try translucent(flat)
        XCTAssertGreaterThan(withShadow, withoutShadow * 2)
    }

    func testExportedTextFadesIn() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 36, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let image = directory.appendingPathComponent("black.png")
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: image)
        var project = Project(name: "T")
        project.addClip(
            Clip(sourceURL: image, mediaKind: .image, startInSeconds: 0, sourceStartInSeconds: 0, sourceEndInSeconds: 4),
            toTrack: project.track(withRole: .main)!.id
        )
        var text = TextLayer(content: "MMMMMM")
        text.fontSize = 220
        text.positionY = 0.2
        text.animation = TextAnimation(inKind: .fade, durationInSeconds: 1)
        project.addTextClip(text, at: 0, duration: 4)
        let url = directory.appendingPathComponent("out.mp4")
        let builder = CompositionBuilder(stillImages: StillImageVideoWriter(directory: directory.appendingPathComponent("stills")))

        try await ProjectExporter(builder: builder).export(project, with: ExportPreset.landscape720.settings, to: url) { _ in }

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        func brightest(at time: TimeInterval) async throws -> Int {
            let frame = try await generator.image(at: time.cmTime).image
            let data = pixels(of: frame)
            return stride(from: 0, to: data.count, by: 4).map { Int(data[$0]) }.max() ?? 0
        }
        let early = try await brightest(at: 0.05)
        let late = try await brightest(at: 2)

        XCTAssertLessThan(early, 100)
        XCTAssertGreaterThan(late, 220)
    }
}
