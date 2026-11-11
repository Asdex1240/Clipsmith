import CoreImage
import XCTest
@testable import Clipsmith

final class BlurredBackgroundTests: XCTestCase {
    private let landscape = CGSize(width: 1920, height: 1080)
    private let portrait = CGSize(width: 1080, height: 1920)

    func testBlurFramesTheForegroundLikeFit() {
        XCTAssertEqual(
            FitTransform.make(
                naturalSize: landscape, preferredTransform: .identity, renderSize: portrait,
                mode: .blur),
            FitTransform.make(
                naturalSize: landscape, preferredTransform: .identity, renderSize: portrait,
                mode: .fit))
    }

    func testBackgroundCoversTheWholeCanvas() {
        let canvas = CGRect(origin: .zero, size: portrait)
        let source = CIImage(color: .red).cropped(to: CGRect(origin: .zero, size: landscape))
        let fill = FitTransform.make(
            naturalSize: landscape, preferredTransform: .identity, renderSize: portrait,
            mode: .fill)

        let background = BlurredBackground.make(
            from: source, fillTransform: fill, canvas: canvas)

        XCTAssertEqual(background.extent.width, canvas.width, accuracy: 1)
        XCTAssertEqual(background.extent.height, canvas.height, accuracy: 1)
    }

    func testBlurModeSurvivesEncoding() throws {
        var clip = TestClips.video(start: 0)
        clip.fitMode = .blur

        let decoded = try JSONDecoder().decode(Clip.self, from: JSONEncoder().encode(clip))

        XCTAssertEqual(decoded.fitMode, .blur)
    }
}
