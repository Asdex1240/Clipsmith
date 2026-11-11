import Foundation
import Observation

@MainActor
@Observable
final class HighlightExportController {
    enum State: Equatable {
        case idle
        case exporting(HighlightBatchProgress)
        case finished(folder: URL, outcomes: [HighlightExportOutcome])
    }

    private(set) var state: State = .idle
    private(set) var selectedIDs: Set<Highlight.ID> = []
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

    var selectedHighlights: [Highlight] {
        store.project.highlights.filter { selectedIDs.contains($0.id) }
    }

    var canExport: Bool {
        !isExporting && !selectedHighlights.isEmpty
    }

    func isSelected(_ id: Highlight.ID) -> Bool {
        selectedIDs.contains(id)
    }

    func setSelected(_ id: Highlight.ID, to isSelected: Bool) {
        if isSelected {
            selectedIDs.insert(id)
        } else {
            selectedIDs.remove(id)
        }
    }

    func selectAll() {
        selectedIDs = Set(store.project.highlights.map(\.id))
    }

    func start(to folder: URL) {
        guard canExport else { return }
        let project = store.project
        let highlights = selectedHighlights
        state = .exporting(
            HighlightBatchProgress(
                completed: 0, total: highlights.count, currentName: highlights[0].name, fraction: 0)
        )
        task = Task { await run(project, highlights, folder) }
    }

    func cancel() {
        task?.cancel()
    }

    func dismissResult() {
        guard !isExporting else { return }
        state = .idle
    }

    private func run(_ project: Project, _ highlights: [Highlight], _ folder: URL) async {
        let batch = HighlightBatchExporter(exporter: exporter)
        do {
            let outcomes = try await batch.export(project, highlights: highlights, to: folder) {
                [weak self] value in
                Task { @MainActor in self?.updateProgress(value) }
            }
            state = .finished(folder: folder, outcomes: outcomes)
        } catch {
            state = .idle
        }
    }

    private func updateProgress(_ value: HighlightBatchProgress) {
        guard isExporting else { return }
        state = .exporting(value)
    }
}
