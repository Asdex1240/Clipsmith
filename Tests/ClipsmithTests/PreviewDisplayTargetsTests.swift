import XCTest

@testable import Clipsmith

final class PreviewDisplayTargetsTests: XCTestCase {
    private let builtIn = ExternalDisplay(id: 1, name: "Built-in")
    private let studio = ExternalDisplay(id: 2, name: "Studio")
    private let projector = ExternalDisplay(id: 3, name: "Projector")

    func testASingleDisplayOffersNoTarget() {
        let candidates = PreviewDisplayTargets.candidates(among: [builtIn], editorDisplayID: 1)

        XCTAssertEqual(candidates, [])
    }

    func testTheDisplayWithTheEditorIsNeverATarget() {
        let candidates = PreviewDisplayTargets.candidates(
            among: [builtIn, studio], editorDisplayID: 2)

        XCTAssertEqual(candidates, [builtIn])
    }

    func testThePrimaryDisplayIsSkippedWhenTheEditorIsNotOnScreen() {
        let candidates = PreviewDisplayTargets.candidates(
            among: [builtIn, studio, projector], editorDisplayID: nil)

        XCTAssertEqual(candidates, [studio, projector])
    }

    func testEveryOtherDisplayIsOfferedWithThreeScreens() {
        let candidates = PreviewDisplayTargets.candidates(
            among: [builtIn, studio, projector], editorDisplayID: 1)

        XCTAssertEqual(candidates, [studio, projector])
    }

    func testADisconnectedDisplayIsDetected() {
        XCTAssertFalse(PreviewDisplayTargets.isConnected(studio, among: [builtIn]))
        XCTAssertTrue(PreviewDisplayTargets.isConnected(studio, among: [builtIn, studio]))
    }
}
