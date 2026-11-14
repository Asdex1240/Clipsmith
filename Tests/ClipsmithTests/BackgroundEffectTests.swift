import CoreImage
import XCTest

@testable import Clipsmith

final class BackgroundEffectTests: XCTestCase {
    private let context = CIContext(options: [
        .workingColorSpace: NSNull(), .outputColorSpace: NSNull(),
    ])
    private let size = 100

    private func pixel(_ image: CIImage, x: Int, y: Int) -> (r: Int, g: Int, b: Int, a: Int) {
        var bytes = [UInt8](repeating: 0, count: 4)
        context.render(
            image, toBitmap: &bytes, rowBytes: 4, bounds: CGRect(x: x, y: y, width: 1, height: 1),
            format: .RGBA8, colorSpace: nil)
        return (Int(bytes[0]), Int(bytes[1]), Int(bytes[2]), Int(bytes[3]))
    }

    private func solid(_ color: CIColor) -> CIImage {
        CIImage(color: color).cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
    }

    private func twoToneImage() -> CIImage {
        let left = CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(
            to: CGRect(x: 0, y: 0, width: size / 2, height: size))
        let right = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(
            to: CGRect(x: size / 2, y: 0, width: size / 2, height: size))
        return right.composited(over: left)
    }

    private func leftHalfMask() -> CIImage {
        let white = CIImage(color: .white).cropped(
            to: CGRect(x: 0, y: 0, width: size / 2, height: size))
        let black = CIImage(color: .black).cropped(
            to: CGRect(x: size / 2, y: 0, width: size / 2, height: size))
        return white.composited(over: black)
    }

    func testRemovingKeepsThePersonAndClearsTheBackground() {
        let result = BackgroundCompositing.apply(
            .remove, to: twoToneImage(), mask: leftHalfMask())

        XCTAssertEqual(pixel(result, x: 10, y: 50).a, 255)
        XCTAssertEqual(pixel(result, x: 10, y: 50).b, 255)
        XCTAssertEqual(pixel(result, x: 90, y: 50).a, 0)
    }

    func testBlurringKeepsThePersonSharpAndSoftensTheBackground() {
        let sharp = twoToneImage()

        let result = BackgroundCompositing.apply(.blur, to: sharp, mask: leftHalfMask())

        XCTAssertEqual(pixel(result, x: 10, y: 50).b, 255)
        XCTAssertEqual(pixel(result, x: 10, y: 50).r, 0)
        let seam = pixel(result, x: 52, y: 50)
        XCTAssertLessThan(seam.r, 255, "the background next to the seam should be blurred")
        XCTAssertGreaterThan(seam.b, 0)
        XCTAssertEqual(seam.a, 255)
    }

    func testTheResultKeepsTheFrameSize() {
        for effect in BackgroundEffect.allCases {
            let result = BackgroundCompositing.apply(
                effect, to: twoToneImage(), mask: leftHalfMask())

            XCTAssertEqual(result.extent, CGRect(x: 0, y: 0, width: size, height: size))
        }
    }

    func testAFullMaskLeavesTheImageUntouched() {
        let result = BackgroundCompositing.apply(
            .remove, to: twoToneImage(), mask: solid(.white))

        XCTAssertEqual(pixel(result, x: 90, y: 50).r, 255)
        XCTAssertEqual(pixel(result, x: 90, y: 50).a, 255)
    }

    // MARK: Clip

    func testABackgroundEffectNeedsTheFrameCompositor() {
        var clip = TestClips.video(start: 0)
        XCTAssertFalse(clip.hasLookEffects)

        clip.backgroundEffect = .remove

        XCTAssertTrue(clip.hasLookEffects)
    }

    func testTheEffectRoundTripsAndIsOmittedWhenAbsent() throws {
        var clip = TestClips.video(start: 0)
        XCTAssertFalse(
            try XCTUnwrap(String(data: JSONEncoder().encode(clip), encoding: .utf8))
                .contains("backgroundEffect"))

        clip.backgroundEffect = .blur
        let decoded = try JSONDecoder().decode(Clip.self, from: JSONEncoder().encode(clip))

        XCTAssertEqual(decoded.backgroundEffect, .blur)
    }

    func testEveryEffectHasATranslatedTitle() {
        for effect in BackgroundEffect.allCases {
            XCTAssertNotEqual(localized(String.LocalizationValue(effect.titleKey)), effect.titleKey)
        }
        XCTAssertNotEqual(
            localized(String.LocalizationValue(InspectorSectionID.background.titleKey)),
            InspectorSectionID.background.titleKey)
    }

    // MARK: Render layer

    private func makeFrame(color: (UInt8, UInt8, UInt8)) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, size, size, kCVPixelFormatType_32BGRA, nil, &buffer)
        let pixels = try XCTUnwrap(buffer)
        CVPixelBufferLockBaseAddress(pixels, [])
        defer { CVPixelBufferUnlockBaseAddress(pixels, []) }
        let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(pixels)).assumingMemoryBound(
            to: UInt8.self)
        let stride = CVPixelBufferGetBytesPerRow(pixels)
        for row in 0..<size {
            for column in 0..<size {
                let offset = row * stride + column * 4
                base[offset] = color.2
                base[offset + 1] = color.1
                base[offset + 2] = color.0
                base[offset + 3] = 255
            }
        }
        return pixels
    }

    func testTheLayerCutsOutTheBackgroundWhenAMaskIsAvailable() throws {
        var clip = TestClips.video(start: 0, sourceEnd: 10)
        clip.backgroundEffect = .remove
        let layer = RenderLayer(
            trackID: 1, clip: clip, naturalSize: CGSize(width: size, height: size),
            preferredTransform: .identity, renderSize: CGSize(width: size, height: size))

        let image = try XCTUnwrap(
            LayerImage.make(
                for: layer, frame: makeFrame(color: (255, 0, 0)), at: 1, renderHeight: Double(size),
                masker: HalfMasker()))

        XCTAssertEqual(pixel(image, x: 10, y: 50).a, 255)
        XCTAssertEqual(pixel(image, x: 90, y: 50).a, 0)
    }

    func testWithoutAMaskerTheFrameIsLeftWhole() throws {
        var clip = TestClips.video(start: 0, sourceEnd: 10)
        clip.backgroundEffect = .remove
        let layer = RenderLayer(
            trackID: 1, clip: clip, naturalSize: CGSize(width: size, height: size),
            preferredTransform: .identity, renderSize: CGSize(width: size, height: size))

        let image = try XCTUnwrap(
            LayerImage.make(
                for: layer, frame: makeFrame(color: (255, 0, 0)), at: 1, renderHeight: Double(size))
        )

        XCTAssertEqual(pixel(image, x: 90, y: 50).a, 255)
    }

    func testAClipWithoutAnEffectNeverAsksForAMask() throws {
        let clip = TestClips.video(start: 0, sourceEnd: 10)
        let layer = RenderLayer(
            trackID: 1, clip: clip, naturalSize: CGSize(width: size, height: size),
            preferredTransform: .identity, renderSize: CGSize(width: size, height: size))
        let masker = HalfMasker()

        _ = LayerImage.make(
            for: layer, frame: try makeFrame(color: (0, 255, 0)), at: 1, renderHeight: Double(size),
            masker: masker)

        XCTAssertEqual(masker.requests, 0)
    }

    // MARK: Vision

    func testVisionReturnsAMaskTheSizeOfTheFrameEvenWithoutPeople() throws {
        let frame = try makeFrame(color: (40, 90, 160))

        let mask = VisionPersonMasker(quality: .fast).mask(for: frame)

        let found = try XCTUnwrap(mask)
        XCTAssertEqual(found.extent.width, Double(size), accuracy: 1)
        XCTAssertEqual(found.extent.height, Double(size), accuracy: 1)
    }

    @MainActor
    func testTheStoreSetsAndClearsTheEffectWithUndo() throws {
        let store = ProjectStore(project: Project(name: "Vlog"))
        let main = store.project.track(withRole: .main)!.id
        store.addMedia(TestClips.mediaItem(duration: 10), toTrack: main, at: 0)
        let id = try XCTUnwrap(store.selectedClipID)

        store.setBackgroundEffect(of: id, to: .remove)
        XCTAssertEqual(store.project.clip(withID: id)?.backgroundEffect, .remove)

        store.setBackgroundEffect(of: id, to: nil)
        XCTAssertNil(store.project.clip(withID: id)?.backgroundEffect)

        store.undo()
        XCTAssertEqual(store.project.clip(withID: id)?.backgroundEffect, .remove)
    }
}

private final class HalfMasker: PersonMasking {
    private(set) var requests = 0

    func mask(for frame: CVPixelBuffer) -> CIImage? {
        requests += 1
        let width = CGFloat(CVPixelBufferGetWidth(frame))
        let height = CGFloat(CVPixelBufferGetHeight(frame))
        let white = CIImage(color: .white).cropped(
            to: CGRect(x: 0, y: 0, width: width / 2, height: height))
        let black = CIImage(color: .black).cropped(
            to: CGRect(x: width / 2, y: 0, width: width / 2, height: height))
        return white.composited(over: black)
    }
}
