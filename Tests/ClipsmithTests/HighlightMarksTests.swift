import XCTest

@testable import Clipsmith

@MainActor
final class HighlightMarksTests: XCTestCase {
    func testNewMarksAreEmptyAndHaveNoRange() {
        let marks = HighlightMarks()

        XCTAssertTrue(marks.isEmpty)
        XCTAssertNil(marks.range)
    }

    func testRangeNeedsBothMarks() {
        var marks = HighlightMarks()

        marks.markStart(at: 3)

        XCTAssertNil(marks.range)
        XCTAssertFalse(marks.isEmpty)
    }

    func testRangeOrdersTheMarksWhateverTheOrderTheyWereSet() {
        var marks = HighlightMarks()

        marks.markStart(at: 9)
        marks.markEnd(at: 4)

        XCTAssertEqual(marks.range, 4...9)
    }

    func testRangeIgnoresMarksCloserThanTheMinimumDuration() {
        var marks = HighlightMarks()

        marks.markStart(at: 4)
        marks.markEnd(at: 4.1)

        XCTAssertNil(marks.range)
    }

    func testMarksNeverGoBelowZero() {
        var marks = HighlightMarks()

        marks.markStart(at: -2)

        XCTAssertEqual(marks.start, 0)
    }

    func testClearRemovesBothMarks() {
        var marks = HighlightMarks()
        marks.markStart(at: 1)
        marks.markEnd(at: 6)

        marks.clear()

        XCTAssertTrue(marks.isEmpty)
    }

    // MARK: Store

    func testStoreMarksAtThePlayhead() {
        let store = ProjectStore(project: Project(name: "Vlog"))
        store.movePlayhead(to: 0)
        store.followPlayback(at: 3)

        store.markHighlightStart()
        store.followPlayback(at: 8)
        store.markHighlightEnd()

        XCTAssertEqual(store.highlightMarks.range, 3...8)
    }

    func testSavingCreatesTheHighlightAndClearsTheMarks() throws {
        let store = ProjectStore(project: Project(name: "Vlog"))
        store.followPlayback(at: 2)
        store.markHighlightStart()
        store.followPlayback(at: 7)
        store.markHighlightEnd()

        let id = try XCTUnwrap(store.saveHighlightFromMarks())

        XCTAssertEqual(store.project.highlight(withID: id)?.startInSeconds, 2)
        XCTAssertEqual(store.project.highlight(withID: id)?.endInSeconds, 7)
        XCTAssertTrue(store.highlightMarks.isEmpty)
    }

    func testSavingWithoutARangeDoesNothing() {
        let store = ProjectStore(project: Project(name: "Vlog"))
        store.markHighlightStart()

        XCTAssertNil(store.saveHighlightFromMarks())
        XCTAssertTrue(store.project.highlights.isEmpty)
        XCTAssertNotNil(store.highlightMarks.start)
    }

    func testLoadingAProjectClearsTheMarks() {
        let store = ProjectStore(project: Project(name: "Vlog"))
        store.markHighlightStart()

        store.load(Project(name: "Other"))

        XCTAssertTrue(store.highlightMarks.isEmpty)
    }

    func testHighlightShortcuts() {
        XCTAssertEqual(
            EditorShortcuts.action(for: .character("i"), modifiers: []), .markHighlightStart)
        XCTAssertEqual(
            EditorShortcuts.action(for: .character("o"), modifiers: []), .markHighlightEnd)
        XCTAssertEqual(EditorShortcuts.action(for: .character("h"), modifiers: []), .addHighlight)
        XCTAssertNil(EditorShortcuts.action(for: .character("h"), modifiers: .command))
    }

    func testSidebarTabsHaveTranslatedTitlesAndIcons() {
        for tab in SidebarTab.allCases {
            XCTAssertNotEqual(localized(String.LocalizationValue(tab.titleKey)), tab.titleKey)
            XCTAssertFalse(tab.systemImage.isEmpty)
        }
    }
}
