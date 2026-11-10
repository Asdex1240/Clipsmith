import AVFoundation
import AppKit
import XCTest
@testable import Clipsmith

final class TextOverlayTests: XCTestCase {
    private let renderSize = CGSize(width: 1920, height: 1080)

    func testEveryTextClipBecomesAHiddenLayerWithAVisibilityWindow() throws {
        let clips = [
            Clip(text: TextLayer(content: "One"), startInSeconds: 2, durationInSeconds: 3),
            Clip(text: TextLayer(content: "Two"), startInSeconds: 6, durationInSeconds: 1),
        ]

        let container = TextOverlayLayers.makeContainer(for: TextOverlay(clips: clips, renderSize: renderSize))

        let layers = try XCTUnwrap(container.sublayers)
        XCTAssertEqual(layers.count, 2)
        XCTAssertEqual(layers.map(\.opacity), [0, 0])
        let animation = try XCTUnwrap(layers[0].animation(forKey: "visibility") as? CABasicAnimation)
        XCTAssertEqual(animation.beginTime, AVCoreAnimationBeginTimeAtZero + 2, accuracy: 1e-9)
        XCTAssertEqual(animation.duration, 3, accuracy: 1e-9)
    }

    func testLayerIsPositionedFromTheTopLeftFraction() throws {
        var text = TextLayer(content: "Hello")
        text.positionX = 0.25
        text.positionY = 0.1
        let clip = Clip(text: text, startInSeconds: 0, durationInSeconds: 1)

        let container = TextOverlayLayers.makeContainer(for: TextOverlay(clips: [clip], renderSize: renderSize))

        let layer = try XCTUnwrap(container.sublayers?.first)
        XCTAssertEqual(layer.position.x, 480, accuracy: 0.01)
        XCTAssertEqual(layer.position.y, 972, accuracy: 0.01)
        XCTAssertNotNil(layer.contents)
    }

    func testFontSizeScalesWithTheShortSideOfTheCanvas() throws {
        let clip = Clip(text: TextLayer(content: "Hello"), startInSeconds: 0, durationInSeconds: 1)

        let small = TextOverlayLayers.makeContainer(for: TextOverlay(clips: [clip], renderSize: CGSize(width: 1920, height: 1080)))
        let large = TextOverlayLayers.makeContainer(for: TextOverlay(clips: [clip], renderSize: CGSize(width: 3840, height: 2160)))

        let smallHeight = try XCTUnwrap(small.sublayers?.first).bounds.height
        let largeHeight = try XCTUnwrap(large.sublayers?.first).bounds.height
        XCTAssertEqual(largeHeight / smallHeight, 2, accuracy: 0.1)
    }

    func testOverlayWithoutTextClipsIsEmpty() {
        XCTAssertTrue(TextOverlay(clips: [], renderSize: renderSize).isEmpty)
    }
}
