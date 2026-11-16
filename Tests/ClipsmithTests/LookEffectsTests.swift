import CoreImage
import XCTest

@testable import Clipsmith

final class LookEffectsTests: XCTestCase {
    private let context = CIContext(options: [
        .workingColorSpace: NSNull(), .outputColorSpace: NSNull(),
    ])
    private let size = 100
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    // MARK: Cube files

    func testACubeFileIsReadInOrderWithAnOpaqueAlpha() throws {
        let table = try CubeLookTable(parsing: Self.invertingCube)

        XCTAssertEqual(table.size, 2)
        XCTAssertEqual(table.rgbaValues.count, 2 * 2 * 2 * 4)
        XCTAssertEqual(Array(table.rgbaValues.prefix(8)), [1, 1, 1, 1, 0, 1, 1, 1])
    }

    func testTitlesCommentsAndDomainLinesAreIgnored() throws {
        let text =
            "TITLE \"Invert\"\n# made by hand\nDOMAIN_MIN 0 0 0\nDOMAIN_MAX 1 1 1\n"
            + Self.invertingCube

        XCTAssertEqual(try CubeLookTable(parsing: text).size, 2)
    }

    func testACubeWithoutItsSizeIsRejected() {
        let text = "0 0 0\n1 1 1\n"

        XCTAssertThrowsError(try CubeLookTable(parsing: text)) { error in
            XCTAssertEqual(error as? LookTableError, .missingSize)
        }
    }

    func testACubeWithMissingColorsIsRejected() {
        let text = "LUT_3D_SIZE 2\n0 0 0\n1 1 1\n"

        XCTAssertThrowsError(try CubeLookTable(parsing: text)) { error in
            XCTAssertEqual(error as? LookTableError, .wrongEntryCount)
        }
    }

    func testEveryTableErrorHasAMessage() {
        for error in [LookTableError.missingSize, .wrongEntryCount, .unreadable] {
            XCTAssertFalse((error.errorDescription ?? "").isEmpty)
        }
    }

    // MARK: Model

    func testANewClipHasNoLookAndNeedsNoEffects() {
        let clip = TestClips.video(start: 0)

        XCTAssertTrue(clip.look.isNone)
        XCTAssertFalse(clip.hasLookEffects)
    }

    func testAnyLookTurnsTheEffectsOn() {
        var clip = TestClips.video(start: 0)
        clip.look.grain = 0.3

        XCTAssertTrue(clip.hasLookEffects)
    }

    func testAmountsAreClampedBetweenZeroAndOne() {
        let lookTable = LookTableReference(url: URL(fileURLWithPath: "/tmp/a.cube"), intensity: 3)
        let look = LookEffects(grain: 4, vignette: -1, sharpness: 0.5, lookTable: lookTable)

        let clamped = look.clamped()

        XCTAssertEqual(clamped.grain, 1)
        XCTAssertEqual(clamped.vignette, 0)
        XCTAssertEqual(clamped.sharpness, 0.5)
        XCTAssertEqual(clamped.lookTable?.intensity, 1)
    }

    func testTheLookSurvivesSavingAndOldFilesHaveNone() throws {
        var clip = TestClips.video(start: 0)
        clip.look = LookEffects(
            grain: 0.2, vignette: 0.4, lookTable: LookTableReference(url: cubeURL()))

        let decoded = try JSONDecoder().decode(Clip.self, from: JSONEncoder().encode(clip))
        let plainJSON = try JSONEncoder().encode(TestClips.video(start: 0))

        XCTAssertEqual(decoded.look, clip.look)
        XCTAssertFalse(String(decoding: plainJSON, as: UTF8.self).contains("look"))
    }

    func testTheLookTableNameIsTheFileName() {
        let reference = LookTableReference(url: URL(fileURLWithPath: "/LUTs/Teal Orange.cube"))

        XCTAssertEqual(reference.name, "Teal Orange")
    }

    // MARK: Store

    @MainActor
    func testChoosingAValidCubeSetsItAndRemovingItClearsIt() throws {
        let url = try writeCube(Self.invertingCube)
        let store = storeWithOneClip()
        let id = try XCTUnwrap(store.selectedClipID)

        try store.applyLookTable(at: url, to: id)
        XCTAssertEqual(store.project.clip(withID: id)?.look.lookTable?.url, url)

        store.removeLookTable(from: id)
        XCTAssertNil(store.project.clip(withID: id)?.look.lookTable)
    }

    @MainActor
    func testAnInvalidCubeIsRejectedAndChangesNothing() throws {
        let url = try writeCube("not a lut")
        let store = storeWithOneClip()
        let id = try XCTUnwrap(store.selectedClipID)

        XCTAssertThrowsError(try store.applyLookTable(at: url, to: id))
        XCTAssertTrue(store.project.clip(withID: id)?.look.isNone ?? false)
    }

    @MainActor
    func testLookChangesCanBeUndone() throws {
        let store = storeWithOneClip()
        let id = try XCTUnwrap(store.selectedClipID)

        store.setLook(of: id, to: LookEffects(vignette: 0.5))
        store.undo()

        XCTAssertTrue(store.project.clip(withID: id)?.look.isNone ?? false)
    }

    // MARK: Rendering

    func testNoLookLeavesThePictureUntouched() {
        let image = solid(CIColor(red: 0.2, green: 0.4, blue: 0.6))

        let result = LookRendering.apply(LookEffects(), to: image, at: 0)

        XCTAssertEqual(pixel(result, x: 50, y: 50), pixel(image, x: 50, y: 50))
    }

    func testALookTableRemapsTheColors() throws {
        let url = try writeCube(Self.invertingCube)
        let look = LookEffects(lookTable: LookTableReference(url: url))

        let result = LookRendering.apply(
            look, to: solid(CIColor(red: 1, green: 0, blue: 0)), at: 0, tables: LookTableStore())

        let color = pixel(result, x: 50, y: 50)
        XCTAssertLessThan(color.r, 10)
        XCTAssertGreaterThan(color.g, 245)
        XCTAssertGreaterThan(color.b, 245)
    }

    func testHalfIntensityMixesTheOriginalAndTheLook() throws {
        let url = try writeCube(Self.invertingCube)
        let look = LookEffects(lookTable: LookTableReference(url: url, intensity: 0.5))

        let result = LookRendering.apply(
            look, to: solid(CIColor(red: 1, green: 0, blue: 0)), at: 0, tables: LookTableStore())

        let color = pixel(result, x: 50, y: 50)
        XCTAssertEqual(color.r, 128, accuracy: 4)
        XCTAssertEqual(color.g, 128, accuracy: 4)
    }

    func testAMissingLookTableIsSkipped() {
        let missing = directory.appendingPathComponent("gone.cube")
        let image = solid(CIColor(red: 1, green: 0, blue: 0))
        let look = LookEffects(lookTable: LookTableReference(url: missing))

        let result = LookRendering.apply(look, to: image, at: 0, tables: LookTableStore())

        XCTAssertEqual(pixel(result, x: 50, y: 50), pixel(image, x: 50, y: 50))
    }

    func testTheVignetteDarkensTheCornersMoreThanTheCenter() {
        let image = solid(CIColor(red: 0.8, green: 0.8, blue: 0.8))

        let result = LookRendering.apply(LookEffects(vignette: 1), to: image, at: 0)

        let center = pixel(result, x: 50, y: 50)
        let corner = pixel(result, x: 1, y: 1)
        XCTAssertLessThan(corner.r, center.r - 20)
        XCTAssertEqual(result.extent, image.extent)
    }

    func testGrainChangesThePixelsAndMovesBetweenFrames() {
        let image = solid(CIColor(red: 0.5, green: 0.5, blue: 0.5))
        let look = LookEffects(grain: 1)

        let first = LookRendering.apply(look, to: image, at: 0)
        let next = LookRendering.apply(look, to: image, at: 0.5)

        let samples = (0..<20).map { (x: $0 * 5, y: 40) }
        let firstValues = samples.map { pixel(first, x: $0.x, y: $0.y).r }
        let nextValues = samples.map { pixel(next, x: $0.x, y: $0.y).r }
        XCTAssertGreaterThan(Set(firstValues).count, 5)
        XCTAssertNotEqual(firstValues, nextValues)
        XCTAssertEqual(first.extent, image.extent)
    }

    func testSharpnessKeepsAFlatColorFlat() {
        let image = solid(CIColor(red: 0.3, green: 0.6, blue: 0.9))

        let result = LookRendering.apply(LookEffects(sharpness: 1), to: image, at: 0)

        let original = pixel(image, x: 50, y: 50)
        let sharpened = pixel(result, x: 50, y: 50)
        XCTAssertEqual(sharpened.r, original.r, accuracy: 2)
        XCTAssertEqual(sharpened.b, original.b, accuracy: 2)
    }

    // MARK: Helpers

    private static let invertingCube = """
        LUT_3D_SIZE 2
        1 1 1
        0 1 1
        1 0 1
        0 0 1
        1 1 0
        0 1 0
        1 0 0
        0 0 0
        """

    private func cubeURL() -> URL {
        directory.appendingPathComponent("look.cube")
    }

    private func writeCube(_ text: String) throws -> URL {
        let url = directory.appendingPathComponent("\(UUID().uuidString).cube")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @MainActor
    private func storeWithOneClip() -> ProjectStore {
        let store = ProjectStore(project: Project(name: "Look"))
        let main = store.project.track(withRole: .main)!.id
        store.addMedia(TestClips.mediaItem(duration: 10), toTrack: main, at: 0)
        return store
    }

    private func solid(_ color: CIColor) -> CIImage {
        CIImage(color: color).cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
    }

    private struct Pixel: Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    private func pixel(_ image: CIImage, x: Int, y: Int) -> Pixel {
        var bytes = [UInt8](repeating: 0, count: 4)
        context.render(
            image, toBitmap: &bytes, rowBytes: 4, bounds: CGRect(x: x, y: y, width: 1, height: 1),
            format: .RGBA8, colorSpace: nil)
        return Pixel(r: Int(bytes[0]), g: Int(bytes[1]), b: Int(bytes[2]))
    }
}
