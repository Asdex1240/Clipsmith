import XCTest

@testable import Clipsmith

final class FileFingerprintTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    private func makeFile(_ name: String, contents: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }

    func testSameFileGivesTheSameDigest() throws {
        let url = try makeFile("a.mov", contents: "one")

        XCTAssertEqual(FileFingerprint.digest(of: url), FileFingerprint.digest(of: url))
    }

    func testDigestIsTwentyFourHexCharacters() throws {
        let url = try makeFile("a.mov", contents: "one")

        let digest = FileFingerprint.digest(of: url)

        XCTAssertEqual(digest.count, 24)
        XCTAssertTrue(digest.allSatisfy(\.isHexDigit))
    }

    func testDifferentPathsGiveDifferentDigests() throws {
        let first = try makeFile("a.mov", contents: "one")
        let second = try makeFile("b.mov", contents: "one")

        XCTAssertNotEqual(FileFingerprint.digest(of: first), FileFingerprint.digest(of: second))
    }

    func testChangingTheFileChangesTheDigest() throws {
        let url = try makeFile("a.mov", contents: "one")
        let before = FileFingerprint.digest(of: url)

        try Data("a much longer content".utf8).write(to: url)

        XCTAssertNotEqual(FileFingerprint.digest(of: url), before)
    }

    func testExtraTextChangesTheDigest() throws {
        let url = try makeFile("a.mov", contents: "one")

        XCTAssertNotEqual(
            FileFingerprint.digest(of: url, extra: "|v1"),
            FileFingerprint.digest(of: url, extra: "|v2"))
    }
}
