import XCTest

@testable import Clipsmith

final class InspectorSectionIDTests: XCTestCase {
    func testStorageKeysAreUnique() {
        let keys = InspectorSectionID.allCases.map(\.storageKey)

        XCTAssertEqual(Set(keys).count, keys.count)
    }

    func testEverySectionHasAnIcon() {
        XCTAssertTrue(InspectorSectionID.allCases.allSatisfy { !$0.systemImage.isEmpty })
    }

    func testEverySectionTitleIsTranslated() {
        for section in InspectorSectionID.allCases {
            let title = localized(String.LocalizationValue(section.titleKey))

            XCTAssertNotEqual(title, section.titleKey, "\(section) has no translation")
        }
    }
}
