import Foundation

struct HighlightBatchExporter {
    static let settings = ExportPreset.vertical1080.settings

    var exporter: Exporting = ProjectExporter()

    func export(
        _ project: Project,
        highlights: [Highlight],
        to folder: URL,
        settings: ExportSettings = HighlightBatchExporter.settings,
        progress: @escaping @Sendable (HighlightBatchProgress) -> Void
    ) async throws -> [HighlightExportOutcome] {
        let fileNames = HighlightFileNaming.fileNames(for: highlights.map(\.name))
        var outcomes: [HighlightExportOutcome] = []
        for (index, highlight) in highlights.enumerated() {
            try Task.checkCancellation()
            let destination = folder.appendingPathComponent(fileNames[index])
            let report = progressReporter(
                index: index, total: highlights.count, name: highlight.name, progress: progress)
            report(0)
            outcomes.append(
                try await exportOne(
                    project.extracting(highlight), named: highlight.name, to: destination,
                    settings: settings, report: report))
        }
        return outcomes
    }

    private func exportOne(
        _ derived: Project,
        named name: String,
        to destination: URL,
        settings: ExportSettings,
        report: @escaping @Sendable (Double) -> Void
    ) async throws -> HighlightExportOutcome {
        do {
            try await exporter.export(derived, with: settings, to: destination, progress: report)
            return HighlightExportOutcome(name: name, result: .exported(destination))
        } catch is CancellationError {
            throw CancellationError()
        } catch ExportError.cancelled {
            throw CancellationError()
        } catch {
            return HighlightExportOutcome(
                name: name, result: .failed(error.localizedDescription))
        }
    }

    private func progressReporter(
        index: Int, total: Int, name: String,
        progress: @escaping @Sendable (HighlightBatchProgress) -> Void
    ) -> @Sendable (Double) -> Void {
        { fraction in
            let clamped = min(max(fraction, 0), 1)
            progress(
                HighlightBatchProgress(
                    completed: index, total: total, currentName: name,
                    fraction: (Double(index) + clamped) / Double(total)))
        }
    }
}
