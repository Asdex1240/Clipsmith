import XCTest

@testable import Clipsmith

final class HighlightFileNamingTests: XCTestCase {
    func testNamesBecomeMP4Files() {
        XCTAssertEqual(HighlightFileNaming.fileNames(for: ["Intro"]), ["Intro.mp4"])
    }

    func testForbiddenCharactersAreReplaced() {
        XCTAssertEqual(HighlightFileNaming.sanitized("a/b:c*d"), "a-b-c-d")
    }

    func testEmptyNamesFallBackToAGenericOne() {
        XCTAssertEqual(HighlightFileNaming.sanitized("  \n "), HighlightFileNaming.fallbackName)
        XCTAssertEqual(HighlightFileNaming.sanitized("..."), HighlightFileNaming.fallbackName)
    }

    func testRepeatedNamesGetANumber() {
        let names = HighlightFileNaming.fileNames(for: ["Clip", "Clip", "clip", "Other"])

        XCTAssertEqual(names, ["Clip.mp4", "Clip 2.mp4", "clip 3.mp4", "Other.mp4"])
    }

    func testTwoNamesThatSanitizeToTheSameFileStayDistinct() {
        let names = HighlightFileNaming.fileNames(for: ["a/b", "a:b"])

        XCTAssertEqual(Set(names).count, 2)
    }
}
