import XCTest
@testable import Clipsmith

final class LocalizationTests: XCTestCase {
    func testEnglishAndSpanishDefineTheSameKeys() throws {
        let english = try localizedKeys(for: "en")
        let spanish = try localizedKeys(for: "es")

        XCTAssertFalse(english.isEmpty)
        XCTAssertEqual(english, spanish)
    }

    func testSpanishBundleReturnsSpanishText() throws {
        let spanishPath = try XCTUnwrap(Bundle.module.path(forResource: "es", ofType: "lproj"))
        let spanishBundle = try XCTUnwrap(Bundle(path: spanishPath))

        let title = String(localized: "project.untitled", bundle: spanishBundle)

        XCTAssertEqual(title, "Proyecto sin título")
    }

    private func localizedKeys(for language: String) throws -> Set<String> {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "Localizable", withExtension: "strings",
                              subdirectory: nil, localization: language)
        )
        let table = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
        return Set(table.keys)
    }
}
