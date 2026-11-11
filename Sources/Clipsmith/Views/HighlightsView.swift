import SwiftUI

struct HighlightsView: View {
    let store: ProjectStore
    let exporter: HighlightExportController
    let waveforms: WaveformStore
    @State private var suggestionState = SuggestionState.idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Design.Spacing.comfortable) {
                marksCard
                suggestCard
                exportCard
                if store.project.highlights.isEmpty {
                    Text(localized("highlight.empty"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.project.highlights) { highlight in
                        HighlightRow(store: store, exporter: exporter, highlight: highlight)
                    }
                }
            }
            .padding(Design.Spacing.comfortable)
        }
    }

    private var marksCard: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.cozy) {
            Text(localized("highlight.marks")).font(.subheadline.bold())
            HStack {
                markButton("highlight.markStart", time: store.highlightMarks.start) {
                    store.markHighlightStart()
                }
                markButton("highlight.markEnd", time: store.highlightMarks.end) {
                    store.markHighlightEnd()
                }
            }
            HStack {
                Button(localized("highlight.save")) { store.saveHighlightFromMarks() }
                    .disabled(store.highlightMarks.range == nil)
                    .keyboardShortcut(.defaultAction)
                Button(localized("highlight.clearMarks"), action: store.clearHighlightMarks)
                    .disabled(store.highlightMarks.isEmpty)
            }
        }
        .padding(Design.Spacing.comfortable)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var suggestCard: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.cozy) {
            Button(localized("highlight.suggest"), action: suggest)
                .disabled(suggestionState == .working || sourceClip == nil)
            switch suggestionState {
            case .idle:
                Text(localized("highlight.suggest.hint")).font(.caption).foregroundStyle(
                    .secondary)
            case .working:
                ProgressView().controlSize(.small)
            case .done(let count):
                Text(suggestionSummary(count: count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Design.Spacing.comfortable)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var sourceClip: Clip? {
        if let clip = store.selectedClip, clip.mediaKind == .video || clip.mediaKind == .audio,
            clip.sourceURL != nil
        {
            return clip
        }
        return store.project.tracks.flatMap(\.clips)
            .filter { ($0.mediaKind == .video || $0.mediaKind == .audio) && $0.sourceURL != nil }
            .max { $0.durationInSeconds < $1.durationInSeconds }
    }

    private func suggest() {
        guard let clip = sourceClip, let url = clip.sourceURL else { return }
        suggestionState = .working
        Task {
            await waveforms.load(url)
            let peaks = waveforms.peaksByURL[url] ?? []
            suggestionState = .done(store.suggestHighlights(for: clip, peaks: peaks))
        }
    }

    private enum SuggestionState: Equatable {
        case idle
        case working
        case done(Int)
    }

    @ViewBuilder
    private var exportCard: some View {
        if !store.project.highlights.isEmpty {
            VStack(alignment: .leading, spacing: Design.Spacing.cozy) {
                exportContent
            }
            .padding(Design.Spacing.comfortable)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
        }
    }

    @ViewBuilder
    private var exportContent: some View {
        switch exporter.state {
        case .idle:
            idleExport
        case .exporting(let progress):
            exportingContent(progress)
        case .finished(let folder, let outcomes):
            finishedContent(folder: folder, outcomes: outcomes)
        }
    }

    private var idleExport: some View {
        HStack {
            Button(
                String(
                    format: localized("highlight.export"), exporter.selectedHighlights.count),
                action: startExport
            )
            .disabled(!exporter.canExport)
            Button(localized("highlight.selectAll"), action: exporter.selectAll)
        }
    }

    private func exportingContent(_ progress: HighlightBatchProgress) -> some View {
        VStack(alignment: .leading, spacing: Design.Spacing.compact) {
            Text(
                String(
                    format: localized("highlight.export.progress"), progress.currentName,
                    progress.completed + 1, progress.total)
            )
            .font(.caption)
            ProgressView(value: progress.fraction)
            Button(localized("export.cancel"), action: exporter.cancel)
        }
    }

    private func finishedContent(
        folder: URL, outcomes: [HighlightExportOutcome]
    ) -> some View {
        VStack(alignment: .leading, spacing: Design.Spacing.compact) {
            Label(
                String(format: localized("highlight.export.done"), exportedCount(outcomes)),
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(Palette.success)
            ForEach(Array(failures(outcomes).enumerated()), id: \.offset) { _, line in
                Label(line, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Palette.warning)
            }
            HStack {
                Button(localized("export.showInFinder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([folder])
                }
                Button(localized("export.close"), action: exporter.dismissResult)
            }
        }
    }

    private func startExport() {
        guard let folder = HighlightFolderPanel.choose() else { return }
        exporter.start(to: folder)
    }

    private func exportedCount(_ outcomes: [HighlightExportOutcome]) -> Int {
        outcomes.filter {
            if case .exported = $0.result { return true }
            return false
        }.count
    }

    private func failures(_ outcomes: [HighlightExportOutcome]) -> [String] {
        outcomes.compactMap { outcome in
            guard case .failed(let reason) = outcome.result else { return nil }
            return String(format: localized("highlight.export.failed"), outcome.name, reason)
        }
    }

    private func suggestionSummary(count: Int) -> String {
        guard count > 0 else { return localized("highlight.suggest.none") }
        return String(format: localized("highlight.suggest.done"), count)
    }

    private func markButton(
        _ key: String.LocalizationValue, time: TimeInterval?, action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Design.Spacing.hairline) {
            Button(localized(key), action: action)
            Text(timeText(time))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func timeText(_ time: TimeInterval?) -> String {
        guard let time else { return localized("highlight.notSet") }
        return time.clockString
    }
}

#Preview {
    let store = PreviewFixtures.store()
    HighlightsView(
        store: store, exporter: HighlightExportController(store: store), waveforms: WaveformStore()
    )
    .frame(width: 280, height: 420)
}
