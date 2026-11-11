import SwiftUI

struct HighlightBands: View {
    let store: ProjectStore
    let pointsPerSecond: Double

    private static let markWidth: CGFloat = 2

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(store.project.highlights) { highlight in
                band(for: highlight)
            }
            if let start = store.highlightMarks.start { mark(at: start) }
            if let end = store.highlightMarks.end { mark(at: end) }
        }
        .frame(height: TimelineMetrics.rulerHeight, alignment: .topLeading)
    }

    private func band(for highlight: Highlight) -> some View {
        RoundedRectangle(cornerRadius: Design.Radius.small)
            .fill(Palette.highlight.opacity(Design.Opacity.highlightBand))
            .frame(
                width: max(highlight.durationInSeconds * pointsPerSecond, Design.Spacing.tight),
                height: Design.Size.highlightBand
            )
            .offset(
                x: highlight.startInSeconds * pointsPerSecond,
                y: TimelineMetrics.rulerHeight - Design.Size.highlightBand
            )
            .help(highlight.name)
            .accessibilityLabel(highlight.name)
            .onTapGesture { store.movePlayhead(to: highlight.startInSeconds) }
    }

    private func mark(at time: TimeInterval) -> some View {
        Rectangle()
            .fill(Palette.highlight)
            .frame(width: Self.markWidth, height: TimelineMetrics.rulerHeight)
            .offset(x: time * pointsPerSecond - Self.markWidth / 2)
            .allowsHitTesting(false)
    }
}

#Preview {
    let store = PreviewFixtures.store()
    let _ = store.addHighlight(from: 1, to: 5)
    HighlightBands(store: store, pointsPerSecond: 40)
        .frame(width: 400)
}
