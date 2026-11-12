import XCTest

@testable import Clipsmith

final class WindowShortcutsTests: XCTestCase {
    func testEveryShortcutHasATranslatedTitle() {
        for shortcut in WindowShortcuts.all {
            XCTAssertNotEqual(
                localized(String.LocalizationValue(shortcut.titleKey)), shortcut.titleKey,
                "\(shortcut.titleKey) is not translated")
        }
    }

    func testKeysAreNeverRepeated() {
        let keys = WindowShortcuts.all.map(\.keys)

        XCTAssertEqual(Set(keys).count, keys.count)
    }

    func testWindowShortcutsDoNotClashWithTheEditingOnes() {
        let editing = Set(EditorAction.allCases.map(EditorShortcuts.displayKeys(for:)))
        let window = Set(WindowShortcuts.all.map(\.keys))

        XCTAssertTrue(editing.isDisjoint(with: window))
    }

    func testThePanelTogglesAreListed() {
        let keys = WindowShortcuts.all.map(\.keys)

        XCTAssertTrue(keys.contains("⌥⌘1"))
        XCTAssertTrue(keys.contains("⌥⌘2"))
    }
}
