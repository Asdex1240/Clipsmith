import XCTest

@testable import Clipsmith

final class TitleTemplateTests: XCTestCase {
    func testEveryTemplateKeepsItsContent() {
        for template in TitleTemplate.allCases {
            XCTAssertEqual(template.layer(content: "Hola").content, "Hola")
        }
    }

    func testTemplatesLookDifferentFromEachOther() {
        let layers = TitleTemplate.allCases.map { $0.layer(content: "x") }

        for (index, layer) in layers.enumerated() {
            XCTAssertEqual(layers.filter { $0 == layer }.count, 1, "\(index) repeats another")
        }
    }

    func testEveryTemplateAnimatesIn() {
        for template in TitleTemplate.allCases {
            XCTAssertNotEqual(template.layer(content: "x").animation.inKind, .none)
        }
    }

    func testTemplatesStayInsideTheFrame() {
        for template in TitleTemplate.allCases {
            let layer = template.layer(content: "x")

            XCTAssertTrue((0...1).contains(layer.positionX))
            XCTAssertTrue((0.05...0.95).contains(layer.positionY))
            XCTAssertGreaterThan(layer.fontSize, 0)
        }
    }

    func testDurationsAreLongEnoughForTheirAnimation() {
        for template in TitleTemplate.allCases {
            let layer = template.layer(content: "x")

            XCTAssertGreaterThan(
                template.durationInSeconds, layer.animation.durationInSeconds * 2,
                "\(template) is shorter than its in and out animation")
        }
    }

    func testTheLowerThirdIsBoxedAndTheChapterIsOutlined() {
        XCTAssertNotNil(TitleTemplate.lowerThird.layer(content: "x").backgroundColor)
        XCTAssertGreaterThan(TitleTemplate.chapter.layer(content: "x").strokeWidth, 0)
    }

    func testEveryTemplateHasTranslatedTitleAndSample() {
        for template in TitleTemplate.allCases {
            XCTAssertNotEqual(
                localized(String.LocalizationValue(template.titleKey)), template.titleKey)
            XCTAssertNotEqual(
                localized(String.LocalizationValue(template.sampleKey)), template.sampleKey)
        }
    }
}

@MainActor
final class TitleStoreTests: XCTestCase {
    private var store = ProjectStore(project: Project(name: "Vlog"))

    override func setUp() async throws {
        store = ProjectStore(project: Project(name: "Vlog"))
    }

    func testAddingATitlePlacesItAtThePlayheadWithTheTemplateLength() throws {
        store.followPlayback(at: 7)

        let id = try XCTUnwrap(store.addTitle(.lowerThird))

        let clip = try XCTUnwrap(store.project.clip(withID: id))
        XCTAssertEqual(clip.startInSeconds, 7, accuracy: 1e-9)
        XCTAssertEqual(clip.durationInSeconds, TitleTemplate.lowerThird.durationInSeconds)
        XCTAssertEqual(
            clip.textLayer?.animation, TitleTemplate.lowerThird.layer(content: "").animation)
    }

    func testTheNewTitleIsSelectedAndGoesToTheTextTrack() throws {
        let id = try XCTUnwrap(store.addTitle(.chapter))

        XCTAssertEqual(store.selectedClipID, id)
        XCTAssertEqual(store.project.trackRole(ofClip: id), .text)
    }

    func testAddingATitleIsOneUndoStep() throws {
        try XCTUnwrap(store.addTitle(.caption))

        store.undo()

        XCTAssertTrue(store.project.allClipIDs.isEmpty)
    }

    func testTwoTitlesAtTheSameTimeDoNotOverlap() throws {
        let first = try XCTUnwrap(store.addTitle(.centerTitle))
        let second = try XCTUnwrap(store.addTitle(.centerTitle))

        let one = try XCTUnwrap(store.project.clip(withID: first))
        let two = try XCTUnwrap(store.project.clip(withID: second))
        let overlaps =
            one.startInSeconds < two.endInSeconds && two.startInSeconds < one.endInSeconds
        XCTAssertFalse(overlaps)
    }

    func testTitlesRespectLockedTextTracks() {
        let text = store.project.track(withRole: .text)!.id
        store.toggleLock(ofTrack: text)

        XCTAssertNil(store.addTitle(.caption))
    }

    func testTheTitlesTabIsInTheSidebar() {
        XCTAssertTrue(SidebarTab.allCases.contains(.titles))
        XCTAssertNotEqual(
            localized(String.LocalizationValue(SidebarTab.titles.titleKey)),
            SidebarTab.titles.titleKey)
    }
}
