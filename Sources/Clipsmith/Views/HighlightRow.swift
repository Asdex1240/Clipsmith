import SwiftUI

struct HighlightRow: View {
    let store: ProjectStore
    let highlight: Highlight

    private static let defaultFraming = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.cozy) {
            HStack(spacing: Design.Spacing.regular) {
                TextField(localized("highlight.name"), text: nameBinding)
                    .textFieldStyle(.plain)
                    .font(.subheadline.bold())
                goToButton
                deleteButton
            }
            Text(rangeSummary)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            ParameterSlider(
                title: localized("highlight.framing"), value: framingBinding,
                range: Highlight.framingRange, unit: .percent,
                defaultValue: Self.defaultFraming)
        }
        .padding(Design.Spacing.comfortable)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var goToButton: some View {
        Button {
            store.movePlayhead(to: highlight.startInSeconds)
        } label: {
            Image(systemName: "arrow.right.to.line")
        }
        .buttonStyle(.borderless)
        .help(localized("highlight.goTo"))
        .accessibilityLabel(localized("highlight.goTo"))
    }

    private var deleteButton: some View {
        Button {
            store.removeHighlight(highlight.id)
        } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .help(localized("highlight.delete"))
        .accessibilityLabel(localized("highlight.delete"))
    }

    private var rangeSummary: String {
        let start = highlight.startInSeconds.clockString
        let end = highlight.endInSeconds.clockString
        return "\(start) – \(end) · \(highlight.durationInSeconds.clockString)"
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { highlight.name },
            set: { store.renameHighlight(highlight.id, to: $0) }
        )
    }

    private var framingBinding: Binding<Double> {
        Binding(
            get: { highlight.framingOffsetX },
            set: { store.setHighlightFraming(highlight.id, offsetX: $0) }
        )
    }
}

#Preview {
    let store = PreviewFixtures.store()
    let id = store.addHighlight(from: 1, to: 6)
    if let id, let highlight = store.project.highlight(withID: id) {
        HighlightRow(store: store, highlight: highlight)
            .padding()
            .frame(width: 280)
    }
}
