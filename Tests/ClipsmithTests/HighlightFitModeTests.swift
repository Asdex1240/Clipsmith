import XCTest
@testable import Clipsmith

final class HighlightFitModeTests: XCTestCase {
    private func projectWithClip() -> (Project, Highlight.ID) {
        var project = Project(name: "T")
        var clip = TestClips.video(start: 0, sourceEnd: 20)
        clip.offsetY = 0.3
        project.addClip(clip, toTrack: project.track(withRole: .main)!.id)
        let id = project.addHighlight(Highlight(name: "h", startInSeconds: 2, endInSeconds: 8))
        return (project, id)
    }

    func testHighlightsFillByDefault() {
        let highlight = Highlight(name: "h", startInSeconds: 0, endInSeconds: 5)

        XCTAssertEqual(highlight.fitMode, .fill)
    }

    func testBlurExportsTheWholeClipOverABlurredBackground() throws {
        var (project, id) = projectWithClip()
        project.setHighlightFraming(id, offsetX: 0.5)
        project.setHighlightFitMode(id, to: .blur)

        let result = project.extracting(project.highlight(withID: id)!)

        let clip = try XCTUnwrap(result.track(withRole: .main)?.clips.first)
        XCTAssertEqual(clip.fitMode, .blur)
        XCTAssertEqual(clip.offsetX, 0)
        XCTAssertEqual(clip.offsetY, 0)
    }

    func testFillStillAppliesTheFraming() throws {
        var (project, id) = projectWithClip()
        project.setHighlightFraming(id, offsetX: -0.4)

        let result = project.extracting(project.highlight(withID: id)!)

        let clip = try XCTUnwrap(result.track(withRole: .main)?.clips.first)
        XCTAssertEqual(clip.fitMode, .fill)
        XCTAssertEqual(clip.offsetX, -0.4)
    }

    func testFitModeSurvivesEditingTheRangeAndEncoding() throws {
        var (project, id) = projectWithClip()
        project.setHighlightFitMode(id, to: .blur)

        project.setHighlightRange(id, start: 3, end: 9)
        let decoded = try JSONDecoder().decode(
            Highlight.self, from: JSONEncoder().encode(project.highlight(withID: id)!))

        XCTAssertEqual(project.highlight(withID: id)?.fitMode, .blur)
        XCTAssertEqual(decoded.fitMode, .blur)
    }

    func testFitModeSurvivesARippleCut() {
        var (project, id) = projectWithClip()
        project.setHighlightFitMode(id, to: .blur)
        let clipID = project.track(withRole: .main)!.clips[0].id

        project.removeRanges([10..<12], from: clipID, syncingAllTracks: true)

        XCTAssertEqual(project.highlight(withID: id)?.fitMode, .blur)
    }

    @MainActor
    func testStoreChangesTheFitModeAsOneUndoStep() {
        let (project, id) = projectWithClip()
        let store = ProjectStore(project: project)

        store.setHighlightFitMode(id, to: .blur)
        store.undo()

        XCTAssertEqual(store.project.highlight(withID: id)?.fitMode, .fill)
    }
}
