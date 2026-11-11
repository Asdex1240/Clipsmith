import XCTest

@testable import Clipsmith

final class HighlightBatchExporterTests: XCTestCase {
    private let folder = URL(fileURLWithPath: "/tmp/highlights")
    private var project = Project(name: "Vlog")

    override func setUp() {
        project = Project(name: "Vlog")
        let main = project.track(withRole: .main)!.id
        project.addClip(TestClips.video(start: 0, sourceEnd: 60), toTrack: main)
    }

    private func highlights() -> [Highlight] {
        [
            Highlight(name: "Intro", startInSeconds: 0, endInSeconds: 5),
            Highlight(name: "Gag", startInSeconds: 10, endInSeconds: 18, framingOffsetX: 0.4),
            Highlight(name: "Gag", startInSeconds: 30, endInSeconds: 40),
        ]
    }

    func testExportsOneVerticalProjectPerHighlightInOrder() async throws {
        let recorder = RecordingExporter()
        let batch = HighlightBatchExporter(exporter: recorder)

        let outcomes = try await batch.export(project, highlights: highlights(), to: folder) { _ in
        }

        XCTAssertEqual(recorder.calls.count, 3)
        XCTAssertTrue(recorder.calls.allSatisfy { $0.project.canvas == .portrait })
        XCTAssertEqual(recorder.calls.map(\.project.durationInSeconds), [5, 8, 10])
        XCTAssertEqual(outcomes.map(\.name), ["Intro", "Gag", "Gag"])
    }

    func testFilesAreNamedAfterTheHighlightsAndNeverCollide() async throws {
        let recorder = RecordingExporter()
        let batch = HighlightBatchExporter(exporter: recorder)

        _ = try await batch.export(project, highlights: highlights(), to: folder) { _ in }

        XCTAssertEqual(
            recorder.calls.map(\.destination.lastPathComponent),
            ["Intro.mp4", "Gag.mp4", "Gag 2.mp4"])
        XCTAssertTrue(
            recorder.calls.allSatisfy {
                $0.destination.deletingLastPathComponent().path == folder.path
            })
    }

    func testUsesTheVerticalPresetSettings() async throws {
        let recorder = RecordingExporter()
        let batch = HighlightBatchExporter(exporter: recorder)

        _ = try await batch.export(project, highlights: highlights(), to: folder) { _ in }

        XCTAssertTrue(
            recorder.calls.allSatisfy { $0.settings == ExportPreset.vertical1080.settings })
    }

    func testFramingReachesTheExportedProject() async throws {
        let recorder = RecordingExporter()
        let batch = HighlightBatchExporter(exporter: recorder)

        _ = try await batch.export(project, highlights: highlights(), to: folder) { _ in }

        let framed = recorder.calls[1].project.track(withRole: .main)?.clips.first
        XCTAssertEqual(framed?.offsetX, 0.4)
        XCTAssertEqual(framed?.fitMode, .fill)
    }

    func testAFailureDoesNotStopTheOtherHighlights() async throws {
        let recorder = RecordingExporter(failingOn: [1])
        let batch = HighlightBatchExporter(exporter: recorder)

        let outcomes = try await batch.export(project, highlights: highlights(), to: folder) { _ in
        }

        XCTAssertEqual(recorder.calls.count, 3)
        guard case .exported = outcomes[0].result, case .failed(let reason) = outcomes[1].result,
            case .exported = outcomes[2].result
        else { return XCTFail("Unexpected outcomes: \(outcomes)") }
        XCTAssertTrue(reason.contains("disk full"))
    }

    func testCancellationStopsTheWholeBatch() async {
        let recorder = RecordingExporter(cancelOn: [1])
        let batch = HighlightBatchExporter(exporter: recorder)

        do {
            _ = try await batch.export(project, highlights: highlights(), to: folder) { _ in }
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertEqual(recorder.calls.count, 2)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testProgressCoversTheWholeBatchAndNeverGoesBack() async throws {
        let recorder = RecordingExporter(progressSteps: [0.5, 1])
        let progress = ProgressLog()
        let batch = HighlightBatchExporter(exporter: recorder)

        _ = try await batch.export(project, highlights: highlights(), to: folder) {
            progress.record($0)
        }

        let fractions = progress.values.map(\.fraction)
        XCTAssertEqual(fractions, fractions.sorted())
        XCTAssertEqual(try XCTUnwrap(fractions.last), 1, accuracy: 1e-9)
        XCTAssertEqual(progress.values.last?.total, 3)
        XCTAssertEqual(Set(progress.values.map(\.currentName)), ["Intro", "Gag"])
    }

    func testAnEmptyHighlightIsReportedAsFailedByTheExporter() async throws {
        let batch = HighlightBatchExporter(exporter: ProjectExporter())
        let empty = Highlight(name: "Empty", startInSeconds: 500, endInSeconds: 510)

        let outcomes = try await batch.export(project, highlights: [empty], to: folder) { _ in }

        guard case .failed = outcomes[0].result else {
            return XCTFail("Expected a failure")
        }
    }
}

private final class RecordingExporter: Exporting, @unchecked Sendable {
    struct Call {
        let project: Project
        let settings: ExportSettings
        let destination: URL
    }

    private let lock = NSLock()
    private var recorded: [Call] = []
    private let failingOn: Set<Int>
    private let cancelOn: Set<Int>
    private let progressSteps: [Double]

    var calls: [Call] { lock.withLock { recorded } }

    init(failingOn: Set<Int> = [], cancelOn: Set<Int> = [], progressSteps: [Double] = []) {
        self.failingOn = failingOn
        self.cancelOn = cancelOn
        self.progressSteps = progressSteps
    }

    func export(
        _ project: Project,
        with settings: ExportSettings,
        to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let index = lock.withLock {
            recorded.append(Call(project: project, settings: settings, destination: destination))
            return recorded.count - 1
        }
        progressSteps.forEach(progress)
        if cancelOn.contains(index) { throw ExportError.cancelled }
        if failingOn.contains(index) { throw ExportError.failed("disk full") }
    }
}

private final class ProgressLog: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [HighlightBatchProgress] = []

    var values: [HighlightBatchProgress] { lock.withLock { recorded } }

    func record(_ value: HighlightBatchProgress) {
        lock.withLock { recorded.append(value) }
    }
}
