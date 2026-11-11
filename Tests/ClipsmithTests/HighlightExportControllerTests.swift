import XCTest

@testable import Clipsmith

@MainActor
final class HighlightExportControllerTests: XCTestCase {
    private var store = ProjectStore(project: Project(name: "Vlog"))
    private let folder = URL(fileURLWithPath: "/tmp/highlights")

    override func setUp() async throws {
        store = ProjectStore(project: Project(name: "Vlog"))
        let main = store.project.track(withRole: .main)!.id
        store.addMedia(TestClips.mediaItem(duration: 60), toTrack: main, at: 0)
        store.addHighlight(from: 0, to: 5)
        store.addHighlight(from: 10, to: 20)
    }

    private func controller(_ exporter: Exporting = InstantExporter()) -> HighlightExportController
    {
        HighlightExportController(store: store, exporter: exporter)
    }

    func testNothingIsSelectedAtFirstSoExportingIsDisabled() {
        let controller = controller()

        XCTAssertFalse(controller.canExport)
        XCTAssertTrue(controller.selectedHighlights.isEmpty)
    }

    func testSelectingAndDeselectingHighlights() {
        let controller = controller()
        let id = store.project.highlights[0].id

        controller.setSelected(id, to: true)
        XCTAssertTrue(controller.isSelected(id))
        XCTAssertTrue(controller.canExport)

        controller.setSelected(id, to: false)
        XCTAssertFalse(controller.isSelected(id))
    }

    func testSelectAllPicksEveryHighlight() {
        let controller = controller()

        controller.selectAll()

        XCTAssertEqual(controller.selectedHighlights.count, 2)
    }

    func testRemovedHighlightsDropOutOfTheSelection() {
        let controller = controller()
        controller.selectAll()

        store.removeHighlight(store.project.highlights[0].id)

        XCTAssertEqual(controller.selectedHighlights.count, 1)
    }

    func testExportFinishesWithOneOutcomePerSelectedHighlight() async {
        let controller = controller()
        controller.selectAll()

        controller.start(to: folder)
        await waitUntilFinished(controller)

        guard case .finished(let finishedFolder, let outcomes) = controller.state else {
            return XCTFail("Expected a finished export")
        }
        XCTAssertEqual(finishedFolder, folder)
        XCTAssertEqual(outcomes.count, 2)
    }

    func testStartingWithoutASelectionDoesNothing() {
        let controller = controller()

        controller.start(to: folder)

        XCTAssertEqual(controller.state, .idle)
    }

    func testCancelReturnsToIdle() async {
        let controller = controller(WaitingExporter())
        controller.selectAll()

        controller.start(to: folder)
        XCTAssertTrue(controller.isExporting)
        controller.cancel()
        await waitUntilFinished(controller)

        XCTAssertEqual(controller.state, .idle)
    }

    func testDismissingAFinishedResultReturnsToIdle() async {
        let controller = controller()
        controller.selectAll()
        controller.start(to: folder)
        await waitUntilFinished(controller)

        controller.dismissResult()

        XCTAssertEqual(controller.state, .idle)
    }

    func testTheCurrentExportCannotBeDismissed() {
        let controller = controller(WaitingExporter())
        controller.selectAll()
        controller.start(to: folder)

        controller.dismissResult()

        XCTAssertTrue(controller.isExporting)
        controller.cancel()
    }

    private func waitUntilFinished(_ controller: HighlightExportController) async {
        for _ in 0..<300 where controller.isExporting {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

private struct InstantExporter: Exporting {
    func export(
        _ project: Project, with settings: ExportSettings, to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {}
}

private struct WaitingExporter: Exporting {
    func export(
        _ project: Project, with settings: ExportSettings, to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        while !Task.isCancelled {
            try await Task.sleep(for: .milliseconds(5))
        }
        throw CancellationError()
    }
}
