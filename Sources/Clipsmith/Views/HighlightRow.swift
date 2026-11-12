import SwiftUI

struct HighlightRow: View {
    let store: ProjectStore
    let exporter: HighlightExportController
    let preview: HighlightPreviewController
    let highlight: Highlight

    private static let defaultFraming = 0.0
    private let faceLocator: FaceLocating = VisionFaceLocator()
    @State private var isFraming = false

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.cozy) {
            HStack(spacing: Design.Spacing.regular) {
                Toggle(localized("highlight.select"), isOn: selectionBinding)
                    .labelsHidden()
                TextField(localized("highlight.name"), text: nameBinding)
                    .textFieldStyle(.plain)
                    .font(.subheadline.bold())
                previewButton
                goToButton
                deleteButton
            }
            Text(rangeSummary)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Picker(localized("highlight.background"), selection: fitModeBinding) {
                Text(localized("highlight.background.fill")).tag(FitMode.fill)
                Text(localized("highlight.background.blur")).tag(FitMode.blur)
            }
            .pickerStyle(.segmented)
            if highlight.fitMode == .fill {
                ParameterSlider(
                    title: localized("highlight.framing"), value: framingBinding,
                    range: Highlight.framingRange, unit: .percent,
                    defaultValue: Self.defaultFraming)
                Button(action: autoFrame) {
                    Label(localized("highlight.autoFrame"), systemImage: "face.dashed")
                }
                .disabled(isFraming)
            }
        }
        .padding(Design.Spacing.comfortable)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func autoFrame() {
        isFraming = true
        Task {
            await store.autoFrameHighlight(highlight.id, using: faceLocator)
            isFraming = false
        }
    }

    private var previewButton: some View {
        Button {
            togglePreview()
        } label: {
            Image(systemName: "play.rectangle")
                .foregroundStyle(previewTint)
        }
        .buttonStyle(.borderless)
        .help(previewLabel)
        .accessibilityLabel(previewLabel)
    }

    private var previewTint: Color {
        if preview.isShowing(highlight.id) { return Palette.highlight }
        return .secondary
    }

    private var previewLabel: String {
        if preview.isShowing(highlight.id) { return localized("highlight.preview.close") }
        return localized("highlight.preview")
    }

    private func togglePreview() {
        if preview.isShowing(highlight.id) {
            preview.close()
        } else {
            preview.show(highlight.id)
        }
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

    private var selectionBinding: Binding<Bool> {
        Binding(
            get: { exporter.isSelected(highlight.id) },
            set: { exporter.setSelected(highlight.id, to: $0) }
        )
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { highlight.name },
            set: { store.renameHighlight(highlight.id, to: $0) }
        )
    }

    private var fitModeBinding: Binding<FitMode> {
        Binding(
            get: { highlight.fitMode },
            set: { store.setHighlightFitMode(highlight.id, to: $0) }
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
        HighlightRow(
            store: store, exporter: HighlightExportController(store: store),
            preview: HighlightPreviewController(store: store, player: PlayerController()),
            highlight: highlight
        )
        .padding()
        .frame(width: 280)
    }
}
