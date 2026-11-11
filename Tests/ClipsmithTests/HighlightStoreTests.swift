import XCTest

@testable import Clipsmith

@MainActor
final class HighlightStoreTests: XCTestCase {
    private var store: ProjectStore!

    override func setUp() {
        store = ProjectStore(project: Project(name: "Vlog"))
    }

    private func defaultName(_ position: Int) -> String {
        String(format: localized("highlight.defaultName"), position)
    }

    func testAddingAHighlightNamesItByPosition() throws {
        let first = try XCTUnwrap(store.addHighlight(from: 0, to: 5))
        let second = try XCTUnwrap(store.addHighlight(from: 10, to: 20))

        XCTAssertEqual(store.project.highlight(withID: first)?.name, defaultName(1))
        XCTAssertEqual(store.project.highlight(withID: second)?.name, defaultName(2))
    }

    func testTooShortRangesAreRejected() {
        XCTAssertNil(store.addHighlight(from: 4, to: 4.1))
        XCTAssertTrue(store.project.highlights.isEmpty)
        XCTAssertFalse(store.canUndo)
    }

    func testAddingAHighlightCanBeUndone() {
        store.addHighlight(from: 0, to: 5)

        store.undo()

        XCTAssertTrue(store.project.highlights.isEmpty)
    }

    func testRenamingAndRemoving() throws {
        let id = try XCTUnwrap(store.addHighlight(from: 0, to: 5))

        store.renameHighlight(id, to: "Intro")
        XCTAssertEqual(store.project.highlight(withID: id)?.name, "Intro")

        store.removeHighlight(id)
        XCTAssertTrue(store.project.highlights.isEmpty)
    }

    func testDraggingTheFramingIsOneUndoStep() throws {
        let id = try XCTUnwrap(store.addHighlight(from: 0, to: 5))

        for step in 1...5 { store.setHighlightFraming(id, offsetX: Double(step) / 10) }
        store.undo()

        XCTAssertEqual(store.project.highlight(withID: id)?.framingOffsetX, 0)
    }

    func testChangingTheRangeKeepsHighlightsSorted() throws {
        let early = try XCTUnwrap(store.addHighlight(from: 0, to: 5))
        store.addHighlight(from: 10, to: 15)

        store.setHighlightRange(early, start: 30, end: 40)

        XCTAssertEqual(store.project.highlights.map(\.startInSeconds), [10, 30])
    }
}
