import XCTest
@testable import Clipsmith

@MainActor
final class ExportControllerTests: XCTestCase {
    private var store = ProjectStore(project: Project(name: "Vlog"))
    private let destination = URL(fileURLWithPath: "/tmp/out.mp4")

    override func setUp() async throws {
        store = ProjectStore(project: Project(name: "Vlog"))
    }

    func testSuccessfulExportFinishesWithTheDestination() async {
        let controller = ExportController(store: store, exporter: StubExporter(outcome: .success))

        controller.start(to: destination)
        await waitUntilFinished(controller)

        XCTAssertEqual(controller.state, .finished(destination))
    }

    func testFailureIsReportedWithTheErrorMessage() async {
        let controller = ExportController(
            store: store, exporter: StubExporter(outcome: .failure(.failed("disk full"))))

        controller.start(to: destination)
        await waitUntilFinished(controller)

        guard case .failed(let message) = controller.state else {
            return XCTFail("Expected failure")
        }
        XCTAssertTrue(message.contains("disk full"))
    }

    func testExporterCancellationReturnsToIdle() async {
        let controller = ExportController(
            store: store, exporter: StubExporter(outcome: .failure(.cancelled)))

        controller.start(to: destination)
        await waitUntilFinished(controller)

        XCTAssertEqual(controller.state, .idle)
    }

    func testCancelStopsAnExportInProgress() async {
        let controller = ExportController(
            store: store, exporter: StubExporter(outcome: .waitsForCancellation))

        controller.start(to: destination)
        XCTAssertTrue(controller.isExporting)
        controller.cancel()
        await waitUntilFinished(controller)

        XCTAssertEqual(controller.state, .idle)
    }

    func testStartingTwiceIsIgnoredWhileExporting() async {
        let exporter = StubExporter(outcome: .waitsForCancellation)
        let controller = ExportController(store: store, exporter: exporter)

        controller.start(to: destination)
        controller.start(to: destination)
        controller.cancel()
        await waitUntilFinished(controller)

        XCTAssertEqual(exporter.startedCount, 1)
    }

    func testProgressIsClampedBetweenZeroAndOne() async {
        let controller = ExportController(
            store: store, exporter: StubExporter(outcome: .reportsProgress([0.4, 1.7])))

        controller.start(to: destination)
        await waitUntilFinished(controller)

        XCTAssertEqual(controller.state, .finished(destination))
    }

    func testApplyingAPresetUpdatesSettingsAndCanvas() {
        let controller = ExportController(store: store, exporter: StubExporter(outcome: .success))

        controller.apply(.vertical1080)

        XCTAssertEqual(controller.settings, ExportPreset.vertical1080.settings)
        XCTAssertEqual(store.project.canvas, .portrait)
        XCTAssertEqual(controller.matchingPreset, .vertical1080)
    }

    func testDefaultFileNameUsesTheProjectName() {
        let controller = ExportController(store: store, exporter: StubExporter(outcome: .success))

        XCTAssertEqual(controller.defaultFileName, "Vlog.mp4")
    }

    func testResetDoesNothingWhileExporting() async {
        let controller = ExportController(
            store: store, exporter: StubExporter(outcome: .waitsForCancellation))
        controller.start(to: destination)

        controller.reset()

        XCTAssertTrue(controller.isExporting)
        controller.cancel()
        await waitUntilFinished(controller)
    }

    private func waitUntilFinished(_ controller: ExportController) async {
        for _ in 0..<200 where controller.isExporting {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

private final class StubExporter: Exporting, @unchecked Sendable {
    enum Outcome {
        case success
        case failure(ExportError)
        case waitsForCancellation
        case reportsProgress([Double])
    }

    let outcome: Outcome
    private(set) var startedCount = 0

    init(outcome: Outcome) {
        self.outcome = outcome
    }

    func export(
        _ project: Project,
        with settings: ExportSettings,
        to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        startedCount += 1
        switch outcome {
        case .success:
            return
        case .failure(let error):
            throw error
        case .waitsForCancellation:
            while !Task.isCancelled {
                try await Task.sleep(for: .milliseconds(5))
            }
            throw CancellationError()
        case .reportsProgress(let values):
            values.forEach(progress)
        }
    }
}
