import XCTest
@testable import Clipsmith

final class EditorShortcutsTests: XCTestCase {
    func testPlainKeysMapToTheirActions() {
        XCTAssertEqual(EditorShortcuts.action(for: .space, modifiers: []), .togglePlayback)
        XCTAssertEqual(EditorShortcuts.action(for: .character("s"), modifiers: []), .split)
        XCTAssertEqual(EditorShortcuts.action(for: .character("S"), modifiers: []), .split)
        XCTAssertEqual(EditorShortcuts.action(for: .character("t"), modifiers: []), .addText)
        XCTAssertEqual(EditorShortcuts.action(for: .delete, modifiers: []), .delete)
        XCTAssertEqual(EditorShortcuts.action(for: .home, modifiers: []), .goToStart)
        XCTAssertEqual(EditorShortcuts.action(for: .end, modifiers: []), .goToEnd)
        XCTAssertEqual(EditorShortcuts.action(for: .escape, modifiers: []), .deselect)
    }

    func testShiftDeleteIsRippleDelete() {
        XCTAssertEqual(EditorShortcuts.action(for: .delete, modifiers: .shift), .rippleDelete)
        XCTAssertNil(EditorShortcuts.action(for: .delete, modifiers: .option))
    }

    func testArrowsStepJumpAndFindEdits() {
        XCTAssertEqual(EditorShortcuts.action(for: .leftArrow, modifiers: []), .stepBackward)
        XCTAssertEqual(EditorShortcuts.action(for: .rightArrow, modifiers: []), .stepForward)
        XCTAssertEqual(EditorShortcuts.action(for: .leftArrow, modifiers: .shift), .jumpBackward)
        XCTAssertEqual(EditorShortcuts.action(for: .rightArrow, modifiers: .shift), .jumpForward)
        XCTAssertEqual(EditorShortcuts.action(for: .leftArrow, modifiers: .option), .previousEdit)
        XCTAssertEqual(EditorShortcuts.action(for: .rightArrow, modifiers: .option), .nextEdit)
        XCTAssertNil(EditorShortcuts.action(for: .leftArrow, modifiers: [.shift, .option]))
    }

    func testZoomAcceptsBothPlusAndEqualsAndBothMinuses() {
        XCTAssertEqual(EditorShortcuts.action(for: .character("="), modifiers: []), .zoomIn)
        XCTAssertEqual(EditorShortcuts.action(for: .character("+"), modifiers: .shift), .zoomIn)
        XCTAssertEqual(EditorShortcuts.action(for: .character("-"), modifiers: []), .zoomOut)
        XCTAssertEqual(EditorShortcuts.action(for: .character("_"), modifiers: .shift), .zoomOut)
    }

    func testUnknownKeysAndExtraModifiersDoNothing() {
        XCTAssertNil(EditorShortcuts.action(for: .character("x"), modifiers: []))
        XCTAssertNil(EditorShortcuts.action(for: .character("s"), modifiers: .shift))
        XCTAssertNil(EditorShortcuts.action(for: .space, modifiers: .shift))
        XCTAssertNil(EditorShortcuts.action(for: .character("s"), modifiers: .option))
    }

    func testEveryActionHasADistinctKeyLabel() {
        let labels = EditorAction.allCases.map(EditorShortcuts.displayKeys(for:))

        XCTAssertEqual(Set(labels).count, labels.count)
    }

    func testEveryActionIsReachableFromSomeKey() {
        let keys: [ShortcutKey] = [
            .space, .delete, .leftArrow, .rightArrow, .home, .end, .escape,
            .character("s"), .character("t"), .character("m"), .character("n"), .character("="), .character("-"),
            .character("q"), .character("w"), .character("c"), .character("x"), .character("v"), .character("d"),
        ]
        let modifiers: [ShortcutModifiers] = [[], .shift, .option, .command]
        let reachable = Set(keys.flatMap { key in modifiers.compactMap { EditorShortcuts.action(for: key, modifiers: $0) } })

        XCTAssertEqual(reachable, Set(EditorAction.allCases))
    }

    func testCommandShortcutsMapToClipboardActions() {
        XCTAssertEqual(EditorShortcuts.action(for: .character("c"), modifiers: .command), .copy)
        XCTAssertEqual(EditorShortcuts.action(for: .character("x"), modifiers: .command), .cut)
        XCTAssertEqual(EditorShortcuts.action(for: .character("v"), modifiers: .command), .paste)
        XCTAssertEqual(EditorShortcuts.action(for: .character("d"), modifiers: .command), .duplicate)
        XCTAssertNil(EditorShortcuts.action(for: .character("s"), modifiers: .command))
        XCTAssertNil(EditorShortcuts.action(for: .character("c"), modifiers: []))
    }

    func testOnlyNavigationAndZoomRepeatWhenHeld() {
        XCTAssertTrue(EditorAction.stepForward.allowsKeyRepeat)
        XCTAssertTrue(EditorAction.zoomIn.allowsKeyRepeat)
        XCTAssertFalse(EditorAction.split.allowsKeyRepeat)
        XCTAssertFalse(EditorAction.delete.allowsKeyRepeat)
        XCTAssertFalse(EditorAction.togglePlayback.allowsKeyRepeat)
    }
}
