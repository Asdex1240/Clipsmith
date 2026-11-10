import SwiftUI

struct VisualInspector: View {
    let store: ProjectStore
    let clip: Clip

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized("inspector.visual.section")).font(.subheadline.bold())
            Picker(localized("inspector.visual.framing"), selection: framingBinding) {
                Text(localized("inspector.visual.fit")).tag(FitMode.fit)
                Text(localized("inspector.visual.fill")).tag(FitMode.fill)
            }
            .pickerStyle(.segmented)
            Text(localized(clip.fitMode == .fit ? "inspector.visual.fit.hint" : "inspector.visual.fill.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var framingBinding: Binding<FitMode> {
        Binding(get: { clip.fitMode }, set: { store.setFitMode(of: clip.id, to: $0) })
    }
}
