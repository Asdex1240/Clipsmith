import SwiftUI

struct HighlightsView: View {
    let store: ProjectStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Design.Spacing.comfortable) {
                marksCard
                if store.project.highlights.isEmpty {
                    Text(localized("highlight.empty"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.project.highlights) { highlight in
                        HighlightRow(store: store, highlight: highlight)
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
    HighlightsView(store: PreviewFixtures.store())
        .frame(width: 280, height: 420)
}
