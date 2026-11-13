import SwiftUI

struct FramingKeyframesView: View {
    let store: ProjectStore
    let highlight: Highlight

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.cozy) {
            Text(localized("highlight.framing.keyframes"))
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            ForEach(highlight.framingKeyframes) { frame in
                row(for: frame)
            }
            HStack {
                AddFramingKeyframeButton(store: store, highlight: highlight)
                Button(localized("highlight.framing.clear")) {
                    store.clearFramingKeyframes(of: highlight.id)
                }
            }
        }
    }

    private func row(for frame: FramingKeyframe) -> some View {
        HStack(spacing: Design.Spacing.regular) {
            Image(systemName: "diamond.fill")
                .font(.system(size: Design.IconSize.badge))
                .foregroundStyle(Palette.keyframe)
                .accessibilityHidden(true)
            Text(frame.timeInSeconds.clockString)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Slider(value: offsetBinding(for: frame), in: Highlight.framingRange)
                .controlSize(.small)
                .accessibilityLabel(localized("highlight.framing"))
            EasingMenu(easing: frame.easing) {
                store.setFramingKeyframeEasing(frame.id, in: highlight.id, to: $0)
            }
            Button {
                store.removeFramingKeyframe(frame.id, from: highlight.id)
            } label: {
                Image(systemName: "trash").minimumHitTarget()
            }
            .buttonStyle(.borderless)
            .help(localized("inspector.keyframes.remove"))
            .accessibilityLabel(localized("inspector.keyframes.remove"))
        }
    }

    private func offsetBinding(for frame: FramingKeyframe) -> Binding<Double> {
        Binding(
            get: { frame.offsetX },
            set: { store.setFramingKeyframeOffset(frame.id, in: highlight.id, to: $0) }
        )
    }
}

#Preview {
    let store = PreviewFixtures.store()
    let id = store.addHighlight(from: 0, to: 6)
    if let id {
        let _ = store.addFramingKeyframeAtPlayhead(to: id)
        if let highlight = store.project.highlight(withID: id) {
            FramingKeyframesView(store: store, highlight: highlight)
                .padding()
                .frame(width: 280)
        }
    }
}
