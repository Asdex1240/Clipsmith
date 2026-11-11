import Foundation
import Observation

@MainActor
@Observable
final class ExportController {
    enum State: Equatable {
        case idle
        case exporting(progress: Double)
        case finished(URL)
        case failed(String)
    }

    private(set) var state: State = .idle
    var settings = ExportPreset.youtube1080.settings
    @ObservationIgnored private let store: ProjectStore
    @ObservationIgnored private let exporter: Exporting
    @ObservationIgnored private var task: Task<Void, Never>?

    init(store: ProjectStore, exporter: Exporting = ProjectExporter()) {
        self.store = store
        self.exporter = exporter
    }

    var isExporting: Bool {
        if case .exporting = state { return true }
        return false
    }

    var matchingPreset: ExportPreset? {
        ExportPreset.matching(settings: settings, canvas: store.project.canvas)
    }

    var outputSize: CGSize {
        settings.resolution.renderSize(for: store.project.canvas)
    }

    var defaultFileName: String {
        store.project.name + ".mp4"
    }

    func apply(_ preset: ExportPreset) {
        settings = preset.settings
        store.setCanvas(preset.canvas)
    }

    func start(to destination: URL) {
        guard !isExporting else { return }
        state = .exporting(progress: 0)
        let project = store.project
        let settings = settings
        task = Task {
            await run(project, settings, destination)
        }
    }

    func cancel() {
        task?.cancel()
    }

    func reset() {
        guard !isExporting else { return }
        state = .idle
    }

    private func run(_ project: Project, _ settings: ExportSettings, _ destination: URL) async {
        do {
            try await exporter.export(project, with: settings, to: destination) {
                [weak self] value in
                Task { @MainActor in self?.updateProgress(value) }
            }
            state = .finished(destination)
        } catch is CancellationError {
            state = .idle
        } catch ExportError.cancelled {
            state = .idle
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func updateProgress(_ value: Double) {
        guard isExporting else { return }
        state = .exporting(progress: min(max(value, 0), 1))
    }
}
