import XCTest
@testable import Clipsmith

final class ProjectFileTests: XCTestCase {
    func testFormatVersionOneStillDecodes() throws {
        let decoded = try ProjectFileCoding.decode(Data(GoldenProjectFixture.legacyJSON.utf8))

        var expected = GoldenProjectFixture.expectedFile
        expected.version = 1
        XCTAssertEqual(decoded, expected)
    }

    func testCurrentFormatDecodes() throws {
        let decoded = try ProjectFileCoding.decode(Data(GoldenProjectFixture.json.utf8))

        XCTAssertEqual(decoded, GoldenProjectFixture.expectedFile)
    }

    func testEncodingTheSameFileProducesTheFrozenFormat() throws {
        let encoded = try ProjectFileCoding.encode(GoldenProjectFixture.expectedFile)

        XCTAssertEqual(String(decoding: encoded, as: UTF8.self), GoldenProjectFixture.json)
    }

    func testRoundTripKeepsEverything() throws {
        var file = GoldenProjectFixture.expectedFile
        file.bookmarks = ["/Videos/a.mov": Data([1, 2, 3])]

        let decoded = try ProjectFileCoding.decode(ProjectFileCoding.encode(file))

        XCTAssertEqual(decoded, file)
    }

    func testGarbageIsReportedAsCorrupted() {
        XCTAssertThrowsError(try ProjectFileCoding.decode(Data("not json".utf8))) { error in
            guard case ProjectFileError.corrupted = error else {
                return XCTFail("Unexpected \(error)")
            }
        }
    }

    func testValidJsonWithoutTheExpectedShapeIsCorrupted() {
        XCTAssertThrowsError(try ProjectFileCoding.decode(Data(#"{"version": 1}"#.utf8))) { error in
            guard case ProjectFileError.corrupted = error else {
                return XCTFail("Unexpected \(error)")
            }
        }
    }

    func testNewerVersionsAreRejectedWithTheirVersionNumber() {
        let data = Data(#"{"version": 99, "anything": true}"#.utf8)

        XCTAssertThrowsError(try ProjectFileCoding.decode(data)) { error in
            guard case ProjectFileError.unsupportedVersion(let version) = error else {
                return XCTFail("Unexpected \(error)")
            }
            XCTAssertEqual(version, 99)
        }
    }

    func testErrorsHaveReadableDescriptions() {
        XCTAssertFalse((ProjectFileError.corrupted.errorDescription ?? "").isEmpty)
        XCTAssertTrue((ProjectFileError.unsupportedVersion(7).errorDescription ?? "").contains("7"))
    }

    func testRemapSourcesReplacesOnlyMatchingUrlsInProjectAndLibrary() {
        let file = GoldenProjectFixture.expectedFile
        var project = file.project
        let replacement = URL(fileURLWithPath: "/New/b.mov")

        project.remapSources([URL(fileURLWithPath: "/Videos/a.mov"): replacement])
        let item = file.library[0].remapped([URL(fileURLWithPath: "/Videos/a.mov"): replacement])

        XCTAssertEqual(project.referencedSourceURLs, [replacement])
        XCTAssertEqual(item.url, replacement)
        XCTAssertNil(project.tracks[0].clips[0].sourceURL)
    }
}
