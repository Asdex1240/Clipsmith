import AppKit
import XCTest

@testable import Clipsmith

final class FilmstripTests: XCTestCase {
    private func image(_ width: Int) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }

    func testShortVideosGetAtLeastOneFrame() {
        XCTAssertEqual(Filmstrip.frameTimes(forDuration: 0.5), [0.25])
    }

    func testFramesAreSpacedEvenlyAndCenteredInTheirSlice() {
        let times = Filmstrip.frameTimes(forDuration: 8)

        XCTAssertEqual(times, [1, 3, 5, 7])
    }

    func testLongVideosAreCappedAtTheMaximumFrameCount() {
        let times = Filmstrip.frameTimes(forDuration: 3600)

        XCTAssertEqual(times.count, Filmstrip.maximumFrameCount)
        XCTAssertEqual(times, times.sorted())
        XCTAssertLessThan(try XCTUnwrap(times.last), 3600)
    }

    func testNoDurationMeansNoFrames() {
        XCTAssertTrue(Filmstrip.frameTimes(forDuration: 0).isEmpty)
    }

    func testFrameLookupPicksTheSliceThatContainsTheTime() {
        let frames = (1...4).map { image($0) }
        let strip = Filmstrip(frames: frames, durationInSeconds: 8)

        XCTAssertEqual(strip.frame(atSourceTime: 0.5)?.width, 1)
        XCTAssertEqual(strip.frame(atSourceTime: 2.5)?.width, 2)
        XCTAssertEqual(strip.frame(atSourceTime: 7.9)?.width, 4)
    }

    func testFrameLookupClampsOutOfRangeTimes() {
        let strip = Filmstrip(frames: [image(1), image(2)], durationInSeconds: 4)

        XCTAssertEqual(strip.frame(atSourceTime: -3)?.width, 1)
        XCTAssertEqual(strip.frame(atSourceTime: 99)?.width, 2)
    }

    func testEmptyStripHasNoFrames() {
        XCTAssertNil(Filmstrip(frames: [], durationInSeconds: 4).frame(atSourceTime: 1))
    }
}

@MainActor
final class FilmstripStoreTests: XCTestCase {
    private let url = URL(fileURLWithPath: "/tmp/a.mov")

    func testLoadingStoresTheStrip() async {
        let store = FilmstripStore(generator: StubFilmstripGenerator())

        await store.load(url)

        XCTAssertEqual(store.stripsByURL[url]?.frames.count, 1)
    }

    func testTheSameFileIsOnlyGeneratedOnce() async {
        let generator = StubFilmstripGenerator()
        let store = FilmstripStore(generator: generator)

        await store.load(url)
        await store.load(url)

        XCTAssertEqual(generator.calls, 1)
    }

    func testConcurrentLoadsShareOneGeneration() async {
        let generator = StubFilmstripGenerator(delay: .milliseconds(50))
        let store = FilmstripStore(generator: generator)

        async let first: Void = store.load(url)
        async let second: Void = store.load(url)
        _ = await (first, second)

        XCTAssertEqual(generator.calls, 1)
    }

    func testAFailedFileLeavesNoStrip() async {
        let store = FilmstripStore(generator: StubFilmstripGenerator(succeeds: false))

        await store.load(url)

        XCTAssertNil(store.stripsByURL[url])
    }
}

final class AVFilmstripGeneratorTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "filmstrip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testGeneratesSmallFramesForARealVideo() async throws {
        let bitmap = try XCTUnwrap(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 36, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let png = directory.appendingPathComponent("frame.png")
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: png)
        let video = try await StillImageVideoWriter(directory: directory).makeVideo(
            from: png, size: CGSize(width: 1920, height: 1080), mode: .fit)

        let generated = await AVFilmstripGenerator().filmstrip(for: video)
        let strip = try XCTUnwrap(generated)

        XCTAssertFalse(strip.frames.isEmpty)
        XCTAssertGreaterThan(strip.durationInSeconds, 0)
        XCTAssertLessThanOrEqual(
            CGFloat(try XCTUnwrap(strip.frames.first).height),
            AVFilmstripGenerator.frameHeightInPixels)
    }

    func testAMissingFileGivesNoFilmstrip() async {
        let missing = directory.appendingPathComponent("none.mov")

        let strip = await AVFilmstripGenerator().filmstrip(for: missing)

        XCTAssertNil(strip)
    }
}

private final class StubFilmstripGenerator: FilmstripGenerating, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private let delay: Duration
    private let succeeds: Bool

    var calls: Int { lock.withLock { count } }

    init(delay: Duration = .zero, succeeds: Bool = true) {
        self.delay = delay
        self.succeeds = succeeds
    }

    func filmstrip(for url: URL) async -> Filmstrip? {
        lock.withLock { count += 1 }
        try? await Task.sleep(for: delay)
        guard succeeds else { return nil }
        let context = CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let image = context?.makeImage() else { return nil }
        return Filmstrip(frames: [image], durationInSeconds: 1)
    }
}

final class ImageFilmstripGeneratorTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "image-strip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makePNG(width: Int, height: Int) throws -> URL {
        let bitmap = try XCTUnwrap(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let url = directory.appendingPathComponent("photo-\(width)x\(height).png")
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    func testAPhotoBecomesASingleDownscaledFrame() async throws {
        let url = try makePNG(width: 4000, height: 3000)

        let generated = await ImageFilmstripGenerator().filmstrip(for: url)
        let strip = try XCTUnwrap(generated)

        XCTAssertEqual(strip.frames.count, 1)
        XCTAssertLessThanOrEqual(
            CGFloat(try XCTUnwrap(strip.frames.first).width),
            AVFilmstripGenerator.frameHeightInPixels * 4)
        XCTAssertEqual(strip.durationInSeconds, ImageFilmstripGenerator.durationInSeconds)
    }

    func testAnyTimeOnAnImageMapsToItsOnlyFrame() async throws {
        let url = try makePNG(width: 64, height: 36)
        let generated = await ImageFilmstripGenerator().filmstrip(for: url)
        let strip = try XCTUnwrap(generated)

        XCTAssertNotNil(strip.frame(atSourceTime: 0))
        XCTAssertNotNil(strip.frame(atSourceTime: 99))
    }

    func testAMissingImageGivesNoFilmstrip() async {
        let strip = await ImageFilmstripGenerator().filmstrip(
            for: directory.appendingPathComponent("none.png"))

        XCTAssertNil(strip)
    }

    func testTheMediaGeneratorSendsImagesAndVideosToTheRightOne() async throws {
        let image = SpyGenerator()
        let video = SpyGenerator()
        let generator = MediaFilmstripGenerator(video: video, image: image)

        _ = await generator.filmstrip(for: URL(fileURLWithPath: "/tmp/a.png"))
        _ = await generator.filmstrip(for: URL(fileURLWithPath: "/tmp/b.mov"))

        XCTAssertEqual(image.requested.map(\.lastPathComponent), ["a.png"])
        XCTAssertEqual(video.requested.map(\.lastPathComponent), ["b.mov"])
    }
}

private final class SpyGenerator: FilmstripGenerating, @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []

    var requested: [URL] { lock.withLock { urls } }

    func filmstrip(for url: URL) async -> Filmstrip? {
        lock.withLock { urls.append(url) }
        return nil
    }
}
